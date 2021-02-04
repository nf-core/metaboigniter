# nf-core/metaboigniter: Output

## :warning: Please read this documentation on the nf-core website: [https://nf-co.re/metaboigniter/output](https://nf-co.re/metaboigniter/output)

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Introduction

This document describes the output produced by the pipeline. Most of the plots are taken from the MultiQC report, which summarises results at the end of the pipeline.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

<!-- TODO nf-core: Write this documentation describing your workflow's output -->

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/)
and processes data using the following steps:

* [Quantification](#quantification) - quantification is performed using several steps including peak picking, feature detection, aligment and linking
* [Annotation](#annotation) - annotation is performed using CAMERA
* [Identification](#identification) - identification is performed using 4 search engines: Metfrag, CSI:FINGERID, CFM-ID and an internal search engine

There are many steps in the workflow and all will be written out as output in the following format:

**Output directory: `results/[name of the step]`**

Each process in the workflow will create a folder with the following pattern:
(output directory)/process_(name of the process)_(if it is library or not)_(ionization mode)_(name of the process)

The most import outputs are the results of "process_output" that contains three tabular files, one for the peak table, one for the variable information (including identification etc) and metadata information.

Data matrix file: variable x sample **dataMatrix** tabular separated file of the numeric data matrix, with . as decimal, and NA for missing values; the table must not contain metadata apart from row and column names; the row and column names must be identical to the rownames of the sample and variable metadata, respectively (see below)

Sample metadata file: sample x metadata **sampleMetadata** tabular separated file of the numeric and/or character sample metadata, with . as decimal and NA for missing values

Variable metadata file: variable x metadata **variableMetadata** tabular separated file of the numeric and/or character variable metadata, with . as decimal and NA for missing values
