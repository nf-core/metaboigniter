# nf-core/metaboigniter: Output

This document describes the output produced by the pipeline. Most of the plots are taken from the MultiQC report, which summarises results at the end of the pipeline.

<!-- TODO nf-core: Write this documentation describing your workflow's output -->

## Pipeline overview
The pipeline is built using [Nextflow](https://www.nextflow.io/)
and processes data using the following steps:

* [Quantification](#quantification) - quantification is performed using several steps including peak picking, feature detection, aligment and linking
* [Annotation](#annotation) - annotation is performed using CAMERA
* [Identification](#identification) - identification is performed using 4 search engines: Metfrag, CSI:FINGERID, CFM-ID and an internal search engine

There are many steps in the workflow and all will be written out as output in the following format:

**Output directory: `results/[name of the step]`**
