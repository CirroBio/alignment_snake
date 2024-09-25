#!/bin/bash

# Write out the config used to run the workflow
echo """{
  \"samples\": \"config/samples.tsv\",
  \"targetfile\": \"config/targets.txt\",
  \"project\": \"${params.project}\",
  \"prefix_regex\": \"{SAMPLEID}-NP-{STRATEGY}_{PORE}-{KIT}-{PROJECT_ID}-{OUTSIDE_ID}_{GENE}-{METH}-{MB}\",
  \"prefix_lookup\": \"{sid}-NP-{strat}_{pore}-{kit}-{project}-{oid}_{gene}-{meth}-{member}\",
  \"sampleDB_prefix_format_columns\": \"sid,strat,pore,kit,project,oid,gene,meth,member\",
  \"sampleDB_prefix_column_names\": \"SampleID,Strategy,Flowcell,Kit,Project,ExternalID,TargetGene,Methylation,Member\",
  \"basecalled_bam_string\": \"{wildcards.SAMPLEID}*{wildcards.STRATEGY}*\",
  \"explicitLibraries\": true,
  \"input_dir\": \"\$PWD\",
  \"final_dir\": \"\$PWD/output\",
  \"working_dir\": \"\$PWD/work\",
  \"threads\": ${task.cpus},
  \"allTargets\": false,
  \"allTranscriptomeTargets\": false,
  \"qcCaller\": \"${params.qc_caller}\",
  \"outputs\": {    
    \"alignBam\": true,
    \"clair3\": true,
    \"sniffles\": true,
    \"svim\": false,
    \"cuteSV\": true,
    \"CNVcalls\": true,
    \"VEP\": true,
    \"phaseQC\": true,
    \"basicQC\": true,
    \"report\": true
  },
  \"transcriptomeOutputs\": {
    \"alignment\": true,
    \"annotation\": true,
    \"transcriptome\": false
  },
  \"refgenome\": \"${refgenome_fa}\",
  \"ontmmifile\": \"${refgenome_mmi}\",
  \"geneAnnotationBed\": \"${gene_annotation_bed}\",
  \"transcript_reference\": \"${transcript_reference}\",
  \"bedfiledir\": \"/n/alignments/bed_targets\",
  \"clairmodelpath\": \"/opt/conda/envs/alignmentCalling/bin/models\",
  \"vep_caches_path\": \"\$PWD/vep_cache\",
  \"vep_data_path\": \"\$PWD/annotationData\",
  \"conda_alignment\": \"alignmentCalling\",
  \"conda_rust\": \"rust_plus\",
  \"conda_vep\": \"vep-111.0\",
  \"conda_bcftools\": \"bcftools-1.19\",
  \"conda_bedtools\": \"bedtools-2.31.1\",
  \"conda_r\": \"rtools\",
  \"conda_gffread\": \"gfftools\",
  \"conda_gffcompare\": \"gfftools\",
  \"conda_pychopper\": \"pychopper\",
  \"conda_stringtie\": \"stringtie\",
  \"conda_samtools\": \"alignmentCalling\",
  \"conda_minimap\": \"alignmentCalling\",
  \"conda_clair3\": \"alignmentCalling\",
  \"conda_cutesv\": \"alignmentCalling\",
  \"conda_sniffles\": \"alignmentCalling\",
  \"conda_svim\": \"alignmentCalling\",
  \"conda_longphase\": \"longphase-1.7.3\",
  \"conda_qdnaseq\": \"qdnaseq-1.34.0\",
  \"conda_cramino\": \"cramino-0.14.1 \",
  \"conda_karyoplotR\": \"karyplotR-1.28.0\"
}""" > config/config.json

# Write out the name of the BAM file to process
echo "BAM file to process: input.bam"
echo -ne 'input.bam' > config/targets.txt

echo "Targets file:"
cat config/targets.txt

# Write out the sample metadata table
echo """SampleID	ExternalID	Project	Member	Flowcell	Kit	Sex	Methylation	TargetGene	BedFile	Strategy
input.bam	${sample_id}	${params.project}	${params.member}	${params.flowcell}	${params.kit}		${params.methylation}	${params.target_gene}	${gene_annotation_bed}	${params.strategy}""" > config/samples.tsv

echo "Sample metadata table:"
cat config/samples.tsv

# Run the snakemake command inside the conda environment alignmentCalling
mamba run -n snakemake snakemake -p --use-conda --cores ${task.cpus} --configfile config/config.json --report-html-path report.html
