# metaboigniter

**Get your metabolomics analysis up and running**.

[![Build Status](https://travis-ci.com/nf-core/metaboigniter.svg?branch=master)](https://travis-ci.com/nf-core/metaboigniter)
[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A50.32.0-brightgreen.svg)](https://www.nextflow.io/)

[![install with bioconda](https://img.shields.io/badge/install%20with-bioconda-brightgreen.svg)](http://bioconda.github.io/)
[![Docker](https://img.shields.io/docker/automated/nfcore/metaboigniter.svg)](https://hub.docker.com/r/nfcore/metaboigniter)



## Introduction
The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It comes with docker containers making installation trivial and results highly reproducible.


## Documentation
The nf-core/metaboigniter pipeline comes with documentation about the pipeline, found in the `docs/` directory:

1. [Installation](https://nf-co.re/usage/installation)
2. Pipeline configuration
    * [Local installation](https://nf-co.re/usage/local_installation)
    * [Adding your own system config](https://nf-co.re/usage/adding_own_config)
3. [Running the pipeline](docs/usage.md)
4. [Output and how to interpret the results](docs/output.md)
5. [Troubleshooting](https://nf-co.re/usage/troubleshooting)

<!-- TODO nf-core: Add a brief overview of what the pipeline does and how it works -->
MetaboIGNITER is a comprehensive pipeline of several independent tools used to pre-process liquid chromatography-mass spectrometry (LCMS) data.  We use Nextflow and nf-core to build and run the workflow but parts of this pipeline have also been implemented using Galaxy as part of [PhenoMeNal](https://github.com/phnmnl/) and [Pachyderm](https://github.com/pharmbio/LC-MS-Pachyderm).

## Credits
metaboigniter was originally written by Payam Emami.

## IMPORTANT
This workflow is not part of nf-core yet. We plan to to make it available as soon as possible.
