#!/usr/bin/env python3

from cirro.helpers.preprocess_dataset import PreprocessDataset
import pandas as pd

# Get the information about the dataset provided by the user for analysis
ds = PreprocessDataset()

# The table of files that are provided as inputs to the analysis
# are in the table ds.files:
# ds.files is a pandas DataFrame with the columns 'sample', and 'file'.
# We need to add a column 'filetype' which indicates whether it is a BAM or FASTQ file.
input = ds.files.assign(
    filetype=ds.files.apply(
        lambda r: "bam" if r['file'].endswith('.bam') else "fastq",
        axis=1
    )
)

# Write the table to 'input.csv'
input.to_csv('input.csv', index=False)
# The workflow already knows to read that file as input (as defined in process-input.json)