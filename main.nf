#!/usr/bin/env nextflow

// The input is a CSV with the following columns:
// sample_id, file, filetype
// Where filetype is either "fastq" or "bam"
// Any "fastq" inputs will be converted into BAM files
// prior to running the rest of the workflow.

// Process used to convert a single FASTQ file into an unaligned BAM file
process convertFastqToBam {
  // See: https://gatk.broadinstitute.org/hc/en-us/articles/4403687183515--How-to-Generate-an-unmapped-BAM-from-FASTQ-or-aligned-BAM

  input:
  tuple val(sample_id), path(fastq)

  output:
  tuple val(sample_id), path('*.bam')

  script:
  """
picard FastqToSam \
    -FASTQ '${fastq}' \
    -OUTPUT '${sample_id}.bam' \
    -READ_GROUP_NAME '${sample_id}' \
    -SAMPLE_NAME '${sample_id}' \
    -LIBRARY_NAME '${sample_id}' \
    -PLATFORM ONT    
  """
}

// Process used to index the reference genome
process minimap2_index {

    input:
    path refgenome_fa

    output:
    path "${refgenome_fa}.mmi"

    script:
    """
    minimap2 -d ${refgenome_fa}.mmi ${refgenome_fa}
    """
}

// Process used to run the snakemake workflow
process alignment_snake {
    publishDir "${params.outdir}", mode: 'copy', overwrite: true
    input:
    path "*"
    path refgenome_fa
    path refgenome_mmi
    path gene_annotation_bed
    path transcript_reference
    path clair_model
    tuple val(sample_id), path(bam)

    output:
    path "output"

    script:
    template "alignment_snake.sh"

}


workflow {

    // Read the file defined by the `input` parameter,
    // parse it as a CSV file, and split it into three
    // channels based on the value of the `filetype` column.
    Channel
        .fromPath(params.input, checkIfExists: true)
        .splitCsv(header: true, sep: ',')
        .branch {
            bam: it.filetype == 'bam'
            fastq: it.filetype == 'fastq'
            other: true
        }
        .set { input_ch }

    // If any input files have an unexpected value in the `filetype`
    // column, notify the user.
    input_ch.other.view{ "Unexpected input: $it" }

    // Generate any BAM files as needed from FASTQ files provided as inputs
    input_ch.fastq
        .map { it -> tuple(it.sample, file(it.file, checkIfExists: true)) }
        | convertFastqToBam

    // To run the snakemake workflow, first get the complete set of files
    // which are in the workflow repository.
    // All of those files will be placed in the working directory for
    // the snakemake workflow execution.
    repo = Channel.fromPath("$projectDir/*", type: "any").toSortedList()

    // REFERENCE FILES //
    // All of the files below will be placed into the working directory
    // for the snakemake workflow execution.
    // The names of the files will be populated into the config.yaml file
    // at runtime.

    // BED file
    bed = file(params.bed, checkIfExists: true)

    // Reference genome FASTA
    refgenome = file(params.refgenome, checkIfExists: true)

    // Transcript reference GTF 
    transcript_reference = file(params.transcript_reference, checkIfExists: true)

    // Clair model folder
    clair_model = file(params.clair_model, checkIfExists: true, type: "dir")

    // Index the reference genome
    minimap2_index(refgenome)

    // Run the snakemake workflow for each of the input files
    alignment_snake(
        repo,
        refgenome,
        minimap2_index.out,
        bed,
        transcript_reference,
        clair_model,
        input_ch.bam.mix(convertFastqToBam.out)
    )

}