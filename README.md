# ![nf-core/metaboigniter](docs/images/nf-core-metaboigniter_logo.png)

**Pre-processing of mass spectrometry-based metabolomics data with quantification and identification based on MS1 and MS2 data**.

[![GitHub Actions CI Status](https://github.com/nf-core/metaboigniter/workflows/nf-core%20CI/badge.svg)](https://github.com/nf-core/metaboigniter/actions)
[![GitHub Actions Linting Status](https://github.com/nf-core/metaboigniter/workflows/nf-core%20linting/badge.svg)](https://github.com/nf-core/metaboigniter/actions)
[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A519.10.0-brightgreen.svg)](https://www.nextflow.io/)

[![install with bioconda](https://img.shields.io/badge/install%20with-bioconda-brightgreen.svg)](https://bioconda.github.io/)
[![Docker](https://img.shields.io/docker/automated/nfcore/metaboigniter.svg)](https://hub.docker.com/r/nfcore/metaboigniter)
[![Get help on Slack](http://img.shields.io/badge/slack-nf--core%20%23metaboigniter-4A154B?logo=slack)](https://nfcore.slack.com/channels/metaboigniter)

[![Gitter chat](https://badges.gitter.im/MetaboIGNITER/gitter.png)](https://gitter.im/MetaboIGNITER/community)

## Introduction

**nf-core/metaboigniter** is bioinformatics pipeline for pre-processing of mass spectrometry-based metabolomics data.

The workflow performs MS1 based quantification and MS2 based identification using combination of different modules. The following steps can be performed using the workflow:

- Centroiding (optional): Also referred to as peak pickering is a step that reduce the distribution of ions derived from a single mass to the peak of the distribution.
- parameter tuning using IPO: MS1 quantification and library characterization parameters can be tuned using IPO
- mass trace detection: The ions derived from the same analytes are clustered together forming a mass trace. These are the entities that will be used for quantification.
- mass trace matching and retention time (RT) correction: The mass traces across different samples will be match against each other and  RT shift between the samples will be adjusted.
- filtering (optional): The mass traces will be filtered out based on the QC samples.
- Annotation: The isotopes and adducts will be annotated in this step.
- MS2 (identification): At the moment we support two types of identification: in-silico and identificaiton based on internal library. This will be expanded in the corresponding section. At the moment we do not support MS1-based identification.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It comes with docker containers making installation trivial and results highly reproducible.

## Quick Start

i. Install [`nextflow`](https://nf-co.re/usage/installation)

ii. Install either [`Docker`](https://docs.docker.com/engine/installation/) or [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/) for full pipeline reproducibility (please only use [`Conda`](https://conda.io/miniconda.html) as a last resort; see [docs](https://nf-co.re/usage/configuration#basic-configuration-profiles))

iii. Download the pipeline and test it on a minimal dataset with a single command

```bash
nextflow run nf-core/metaboigniter -profile test,<docker/singularity/conda/institute>
```

> Please check [nf-core/configs](https://github.com/nf-core/configs#documentation) to see if a custom config file to run nf-core pipelines already exists for your Institute. If so, you can simply use `-profile <institute>` in your command. This will enable either `docker` or `singularity` and set the appropriate execution settings for your local compute environment.

iv. Start running your own analysis!
We highly recommend that you use the parameter file located in conf/parameters.config. Since the number of parameters is large, it's going to be a fairly complex bash command to run the workflow. Nevertheless, the parameters can always be passed to the workflow as argument using two dashes "--".

```bash
nextflow run nf-core/metaboigniter -profile <docker/singularity/conda/institute>
```

See [usage docs](docs/usage.md) for all of the available options when running the pipeline.

## Documentation

The nf-core/metaboigniter pipeline comes with documentation about the pipeline, found in the `docs/` directory:

The nf-core/metaboigniter pipeline comes with documentation about the pipeline: [usage](https://nf-co.re/metaboigniter/usage) and [output](https://nf-co.re/metaboigniter/output).

MetaboIGNITER is a comprehensive pipeline of several independent tools used to pre-process liquid chromatography-mass spectrometry (LCMS) data. We use Nextflow and nf-core to build and run the workflow but parts of this pipeline have also been implemented using Galaxy as part of [PhenoMeNal](https://github.com/phnmnl/) and [Pachyderm](https://github.com/pharmbio/LC-MS-Pachyderm).

## Credits

nf-core/metaboigniter was originally written by Payam Emami.

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on [Slack](https://nfcore.slack.com/channels/metaboigniter) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citation

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi. -->
<!-- If you use  nf-core/metaboigniter for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
> ReadCube: [Full Access Link](https://rdcu.be/b1GjZ)
