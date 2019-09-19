FROM nfcore/base
LABEL authors="Payam Emami" \
      description="Docker image containing all requirements for nf-core/metaboigniter pipeline"

COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a
ENV PATH /opt/conda/envs/nf-core-metaboigniter-1.0dev/bin:$PATH
