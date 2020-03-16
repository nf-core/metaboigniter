# MetaboIGNITER


**Get your metabolomics analysis up and running**.

[![Build Status](https://travis-ci.com/MetaboIGNITER/metaboigniter.svg?branch=master)](https://travis-ci.com/MetaboIGNITER/metaboigniter)
[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A50.32.0-brightgreen.svg)](https://www.nextflow.io/)

[![install with bioconda](https://img.shields.io/badge/install%20with-bioconda-brightgreen.svg)](http://bioconda.github.io/)
[![Docker](https://img.shields.io/docker/cloud/automated/metaboigniter/metaboigniter)](https://hub.docker.com/r/metaboigniter/metaboigniter)

[![Gitter chat](https://badges.gitter.im/MetaboIGNITER/gitter.png)](https://gitter.im/MetaboIGNITER/community)

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

The complete pipeline will go through the following steps:

<img src="assets/flowchart.png">

## Credits
MetaboIGNITER was originally written by Payam Emami.

This works has been done with collaboration with several groups.

<a href="https://www.nbis.se/">
<img src="assets/NBIS.svg" width="100" height="100">&nbsp;&nbsp;&nbsp;</a>
<a href="https://elixir-europe.org/"><img src="assets/elixir.png" width="100" height="100">&nbsp;&nbsp;&nbsp;</a><a href="http://www.caramba.clinic/">
<img src="assets/caramba.png" width="120" height="100">&nbsp;&nbsp;&nbsp;</a><a href="https://phenomenal-h2020.eu/home/">
<img src="assets/PhenoMeNal_logo.png" width="330" height="100">&nbsp;&nbsp;&nbsp;</a>


## IMPORTANT
This workflow is not part of nf-core yet. We plan to to make it available as soon as possible.
