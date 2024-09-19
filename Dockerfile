FROM --platform=linux/amd64 continuumio/miniconda3

ADD workflow/envs/ /envs/
RUN conda config --add channels conda-forge && \
    conda config --add channels bioconda && \
    conda config --add channels R && \
    conda config --add channels esri && \
    conda env create -f /envs/alignment.yaml && \
    conda env create -f /envs/alignmentCalling.yaml && \
    conda env create -f /envs/bcftools-1.19.yaml && \
    conda env create -f /envs/bedtools-2.31.1.yaml && \
    conda env create -f /envs/multisample_env.yaml && \
    conda env create -f /envs/qdnaseq-1.34.0.yaml && \
    conda env create -f /envs/rust_plus.yaml && \
    conda env create -f /envs/rustenv.yaml && \
    conda env create -f /envs/gfftools.yaml && \
    conda env create -f /envs/rtools.yaml && \
    conda env create -f /envs/pychopper.yaml && \
    conda env create -f /envs/stringtie.yaml && \
    conda env create -f /envs/vep-111.0.yaml && \
    conda env create -f /envs/longphase-1.7.3.yaml && \
    conda clean --all --yes
RUN conda run -n qdnaseq-1.34.0 Rscript -e "devtools::install_github('asntech/QDNAseq.hg38@main');"
RUN conda install -n base -c conda-forge mamba && \
    mamba init && \
    mamba create -c conda-forge -c bioconda -n snakemake snakemake && \
    mamba clean --all --yes && \
    mamba run -n snakemake snakemake --version
ADD https://cdn.oxfordnanoportal.com/software/analysis/models/clair3/r1041_e82_400bps_sup_v500.tar.gz /opt/conda/envs/alignmentCalling/bin/models/
RUN cd /opt/conda/envs/alignmentCalling/bin/models/ && \
    tar -xvf r1041_e82_400bps_sup_v500.tar.gz && \
    rm r1041_e82_400bps_sup_v500.tar.gz