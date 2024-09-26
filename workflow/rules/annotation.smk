# this rule should run vep and then make the output more readable.
rule filter_clair3_vcf:
    input:
        clair3_phased_vcf="".join([SAMPLE_WORKPATH, ".clair3.phased.vcf.gz"]),
        clair3_phased_vcf_index="".join([SAMPLE_WORKPATH, ".clair3.phased.vcf.gz.tbi"])
    output:
        clair3_phased_filtered_vcf=temp("".join([SAMPLE_WORKPATH, ".clair3.phased.filtered.vcf.gz"]))
    threads: THREADS
    log:
        o = "".join(["logs/",LOG_REGEX,"filter_clair3","-stdout.log"]),
        e = "".join(["logs/",LOG_REGEX,"filter_clair3","-stderr.log"])
    conda:
        config["conda_bcftools"]
    shell:
        """
        bcftools view --include 'FILTER="PASS"' -o {output.clair3_phased_filtered_vcf} {input.clair3_phased_vcf}
        """


rule run_vep:
    input:
        clair3_phased_filtered_vcf="".join([SAMPLE_WORKPATH, ".clair3.phased.filtered.vcf.gz"])
    output:
        vep_vcf=temp("".join([SAMPLE_WORKPATH, ".clair3.phased.vep.vcf"]))
    threads: THREADS
    log:
        o = "".join(["logs/",LOG_REGEX,"run_vep","-stdout.log"]),
        e = "".join(["logs/",LOG_REGEX,"run_vep","-stderr.log"])
    params:
        CLINVAR="{}/clinvar_20240917.vcf.gz".format(config["vep_data_path"]),
        ALPHAMISSENSE="{}/AlphaMissense_hg38.tsv.gz".format(config["vep_data_path"]),
        cache_directory="{}/.vep".format(config["vep_caches_path"]),
        plugin_dir="{}/.vep/Plugins".format(config["vep_caches_path"]),
        email=config["email"]
    conda:
        config["conda_vep"]
    shell:
        """
        input={input.clair3_phased_filtered_vcf}
        output={output.vep_vcf}
        cache_directory={params.cache_directory}
        plugin_dir={params.plugin_dir}
        ALPHAMISSENSE={params.ALPHAMISSENSE}
        CLINVAR={params.CLINVAR}
        THREADS={threads}
        #vep -i $input --force_overwrite --vcf --buffer_size 50000 --species homo_sapiens --fork $THREADS -o $output --cache --merged --offline --dir_cache $cache_directory --canonical --symbol --numbers --assembly GRCh38 --use_given_ref --pick_allele --domains --pubmed --gene_phenotype --sift b --polyphen b --regulatory --total_length --af --max_af --af_1kg --custom file=$CLINVAR,short_name=ClinVar,format=vcf,type=exact,coords=0,fields=CLNSIG%CLNREVSTAT%CLNDN 2>> {log.e}
        vep -i $input --force_overwrite --vcf --buffer_size 50000 --species homo_sapiens --fork $THREADS -o $output --cache --offline --dir_cache $cache_directory --canonical --symbol --numbers --assembly GRCh38 --use_given_ref --pick_allele --domains --pubmed --gene_phenotype --sift b --polyphen b --regulatory --total_length --af --max_af --af_1kg --custom_multi_allelic --dir_plugins $plugin_dir --plugin AlphaMissense,file=$ALPHAMISSENSE --custom file=$CLINVAR,short_name=ClinVar,format=vcf,type=exact,coords=0,fields=CLNSIG%CLNREVSTAT%CLNDN 2>> {log.e}
        echo "VEP output for {wildcards.SAMPLEID} in project {wildcards.PROJECT_ID} has completed. It is likely being moved to /n/alignments. "
        """

# this rule  should filter the vep vcf
rule filter_vep:
    input:
        vep_vcf="".join([SAMPLE_WORKPATH, ".clair3.phased.vep.vcf"])
    output:
        vep_lt1_vcf=temp("".join([SAMPLE_WORKPATH, ".clair3.phased.vep.af_lt_1.csv"]))
    conda:
         config["conda_bcftools"]
    params:
        tmp_prefix="".join([SAMPLE_WORKPATH,".veptemp"])
    shell:
        """
        formatstring="%CHROM\t%POS\t%REF\t%ALT\t%QUAL\t[%GT\t%DP\t%AF\t%PS]\t%CSQ"
        bcftools +split-vep {input.vep_vcf} -f "$formatstring" -A "tab" > {params.tmp_prefix}.1.tsv

        collapsedoutput={params.tmp_prefix}.c.tsv
        notphasedoutput={params.tmp_prefix}.np.tsv

        awk -F "\t|," -v outputphased=$collapsedoutput -v outputnotphased=$notphasedoutput 'NF>80{{print $0 >> outputnotphased}}NF<80{{print $0 >> outputphased}}' {params.tmp_prefix}.1.tsv

        awk -F "\t|," '{{print $1,$2,$3,$4,$6,$7,$8,$9,$11,$12,$14,$16,$18,$20,$22,$24,$26,$28,$30,$32,$34,$36,\
        $38,$40,$42,$44,$46,$48,$50,$52,$54,$56,$58,$60,$62,$64,$66,$68,$70,$72,$74,$76,$78,$80,$82,$84,$86,$88,$90,$92,$94,$96,$98,$100,$102,$104,\
        $106,$108,$110,$112,$114,$116,$118,$120,$122,$124,$126,$128,$130,$132,$134,$136,$138,$140,$142,$144; print $1,$2,$3,$5,$6,$7,$8,$10,$11,$13,\
        $15,$17,$19,$21,$23,$25,$27,$29,$31,$33,$35,$37,$39,$41,$43,$45,$47,$49,$51,$53,$55,$57,$59,$61,$63,$65,$67,$69,$71,$73,$75,$77,$79,$81,$83,\
        $85,$87,$89,$91,$93,$95,$97,$99,$101,$103,$105,$107,$109,$111,$113,$115,$117,$119,$121,$123,$125,$127,$129,$131,$133,$135,$137,$139,$141,$143\
        ,$145}}' $notphasedoutput | tr ' ' '\t' >> $collapsedoutput

        colnames="IGV TYPE DP_ALT DP_REF CHROM POS REF ALT QUAL GT DP AF PS Allele Consequence IMPACT SYMBOL Gene Feature_type Feature BIOTYPE EXON \
        INTRON HGVSc HGVSp cDNA_position CDS_position Protein_position Amino_acids Codons Existing_variation DISTANCE STRAND FLAGS SYMBOL_SOURCE HGNC_ID \
        CANONICAL REFSEQ_MATCH SOURCE REFSEQ_OFFSET GENE_PHENO SIFT PolyPhen DOMAINS AF_POP AFR_AF AMR_AF EAS_AF EUR_AF SAS_AF MAX_AF \
        MAX_AF_POPS CLIN_SIG SOMATIC PHENO PUBMED MOTIF_NAME MOTIF_POS HIGH_INF_POS MOTIF_SCORE_CHANGE TRANSCRIPTION_FACTORS \
        am_class am_pathogenicity ClinVar ClinVar_CLINSIG \
        ClinVar_CLNREVSTAT ClinVar_CLNDN"

        echo $colnames | tr ' ' ',' > {output.vep_lt1_vcf}
        awk '{{if($47>0.01 || $72 > 0.01){{next}}else{{type="SNV";if(length($3)!=length($4)){{type="INDEL"}};\
        altdp=int($7*$8); refdp=$7-altdp; print $1":"$2,type,altdp,refdp,$0}}}}' $collapsedoutput | tr ' ' '\t' | tr '\t' ',' >> {output.vep_lt1_vcf}

        rm {params.tmp_prefix}*tsv
        """

rule run_vep_111:
    input:
        clair3_phased_filtered_vcf="".join([SAMPLE_WORKPATH, ".clair3.phased.filtered.vcf.gz"])
    output:
        vep_vcf=temp("".join([SAMPLE_WORKPATH, ".clair3.phased.vep.111.vcf"]))
    threads: THREADS
    log:
        o = "".join(["logs/",LOG_REGEX,"run_vep_111","-stdout.log"]),
        e = "".join(["logs/",LOG_REGEX,"run_vep_111","-stderr.log"])
    params:
        CLINVAR="{}/clinvar_20240917.vcf.gz".format(config["vep_data_path"]),
        ALPHAMISSENSE="{}/AlphaMissense_hg38.tsv.gz".format(config["vep_data_path"]),
        SPLICEVAULT="{}/SpliceVault_data_GRCh38.tsv.gz".format(config["vep_data_path"]),
        DOSAGE="{}/Collins_rCNV_2022.dosage_sensitivity_scores.tsv.gz".format(config["vep_data_path"]),
        cache_directory="{}/.vep111".format(config["vep_caches_path"]),
        plugin_dir="{}/.vep111/Plugins".format(config["vep_caches_path"])
    conda:
        config["conda_vep"]
    shell:
        """
        input={input.clair3_phased_filtered_vcf}
        output={output.vep_vcf}
        cache_directory={params.cache_directory}
        plugin_dir={params.plugin_dir}
        ALPHAMISSENSE={params.ALPHAMISSENSE}
        CLINVAR={params.CLINVAR}
        SPLICEVAULT={params.SPLICEVAULT}
        DOSAGE={params.DOSAGE}
        THREADS={threads}
        
        vep -i $input --force_overwrite --vcf --buffer_size 50000 --species homo_sapiens \
        --fork $THREADS -o $output --cache --offline --dir_cache $cache_directory --canonical \
        --symbol --numbers --assembly GRCh38 --use_given_ref --pick_allele --domains --pubmed --gene_phenotype \
        --sift b --polyphen b --regulatory --total_length --af --max_af --af_1kg --custom_multi_allelic \
        --dir_plugins $plugin_dir --plugin SpliceVault,file=$SPLICEVAULT \
        --plugin DosageSensitivity,file=$DOSAGE \
        --plugin AlphaMissense,file=$ALPHAMISSENSE \
        --custom file=$CLINVAR,short_name=ClinVar,format=vcf,type=exact,coords=0,fields=CLNSIG%CLNREVSTAT%CLNDN 2>> {log.e}
        """

# this rule  should filter the vep vcf
rule filter_vep_111:
    input:
        vep_vcf="".join([SAMPLE_WORKPATH, ".clair3.phased.vep.111.vcf"])
    output:
        vep_lt1_vcf=temp("".join([SAMPLE_WORKPATH, ".clair3.phased.vep.111.af_lt_1.csv"]))
    conda:
         config["conda_bcftools"]
    params:
        tmp_prefix="".join([SAMPLE_WORKPATH,".vep111temp"])
    shell:
        """
        formatstring="%CHROM\t%POS\t%REF\t%ALT\t%QUAL\t[%GT\t%DP\t%AF\t%PS]\t%CSQ"
        bcftools +split-vep {input.vep_vcf} -f "$formatstring" -A "tab" > {params.tmp_prefix}.1.tsv

        collapsedoutput={params.tmp_prefix}.c.tsv
        notphasedoutput={params.tmp_prefix}.np.tsv

        awk -F "\t|," -v outputphased=$collapsedoutput -v outputnotphased=$notphasedoutput 'NF>90{{print $0 >> outputnotphased}}NF<90{{print $0 >> outputphased}}' {params.tmp_prefix}.1.tsv

        awk -F "\t|," '{{print $1,$2,$3,$4,$6,$7,$8,$9,$11,$12,$14,$16,$18,$20,$22,$24,$26,$28,$30,$32,$34,$36,\
        $38,$40,$42,$44,$46,$48,$50,$52,$54,$56,$58,$60,$62,$64,$66,$68,$70,$72,$74,$76,$78,$80,$82,$84,$86,$88,$90,$92,$94,$96,$98,$100,$102,$104,\
        $106,$108,$110,$112,$114,$116,$118,$120,$122,$124,$126,$128,$130,$132,$134,$136,$138,$140,$142,$144,$146,$148,$150,\
        $152,$154,$156,$158,$160,$162,$164,$166,$168,$170,$172; print $1,$2,$3,$5,$6,$7,$8,$10,$11,$13,\
        $15,$17,$19,$21,$23,$25,$27,$29,$31,$33,$35,$37,$39,$41,$43,$45,$47,$49,$51,$53,$55,$57,$59,$61,$63,$65,$67,$69,$71,$73,$75,$77,$79,$81,$83,\
        $85,$87,$89,$91,$93,$95,$97,$99,$101,$103,$105,$107,$109,$111,$113,$115,$117,$119,$121,$123,$125,$127,$129,$131,$133,$135,$137,$139,$141,$143\
        ,$145,$147,$149,$151,$153,$155,$157,$159,$161,$163,$165,$167,$169,$171,$173}}' $notphasedoutput | tr ' ' '\t' >> $collapsedoutput

        colnames="IGV TYPE DP_ALT DP_REF CHROM POS REF ALT QUAL GT DP AF PS Allele Consequence IMPACT SYMBOL Gene Feature_type Feature BIOTYPE EXON \
        INTRON HGVSc HGVSp cDNA_position CDS_position Protein_position Amino_acids Codons Existing_variation DISTANCE STRAND FLAGS SYMBOL_SOURCE HGNC_ID \
        CANONICAL REFSEQ_MATCH SOURCE REFSEQ_OFFSET GENE_PHENO SIFT PolyPhen DOMAINS AF_POP AFR_AF AMR_AF EAS_AF EUR_AF SAS_AF MAX_AF \
        MAX_AF_POPS CLIN_SIG SOMATIC PHENO PUBMED MOTIF_NAME MOTIF_POS HIGH_INF_POS MOTIF_SCORE_CHANGE TRANSCRIPTION_FACTORS \
        SpliceVault_out_of_frame_events SpliceVault_site_max_depth SpliceVault_site_pos \
        SpliceVault_site_sample_count SpliceVault_site_type SpliceVault_top_events \
        pHaplo pTriplo am_class am_pathogenicity ClinVar ClinVar_CLNSIG ClinVar_CLNREVSTAT ClinVar_CLNDN"

        echo $colnames | tr ' ' ',' > {output.vep_lt1_vcf}
        awk '{{if($47>0.01 || $85 > 0.01){{next}}else{{type="SNV";if(length($3)!=length($4)){{type="INDEL"}};\
        altdp=int($7*$8); refdp=$7-altdp; print $1":"$2,type,altdp,refdp,$0}}}}' $collapsedoutput | tr ' ' '\t' | tr '\t' ',' >> {output.vep_lt1_vcf}

        rm {params.tmp_prefix}*tsv
        """