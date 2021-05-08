# nf-core/metaboigniter: Output

## Table of contents

* [Table of contents](#table-of-contents)
* [Introduction](#introduction)
* [Quantification](#quantification)
* [Annotation](#annotation)
* [Identification](#identification)
* [Final output](#final-output)

## Introduction

nf-core/metaboigniter produces various different output files.

Each process in the workflow will create a folder with the following pattern:

```nextflow
(output directory)/process_(name of the process)_(if it is library or not)_(ionization mode)_(name of the process).
```

The default behavior of the pipeline is to write output for identification and the final results of the pipeline (see below).

However, one can set the following parameter that instructs the pipeline to produce outputs for all of the tools.

```yaml
publishDir_intermediate: true
```

> Note that because there are a large number of parameters for this pipeline, we recommend using a YAML file and supplying to the pipeline with the Nextflow option `-params-file`.
> Alternatively, you can create a Nextflow config file and supply this with `-c`.

## Quantification

Quantification is performed using several steps including peak picking, feature detection, alignment, and linking.

If one chooses to perform the centroiding using OpenMS, the output of the centroiding will be `mzML` files.

If one chooses to perform the mass trace detection using OpenMS, the output of the detection will be `featureXML` files.

All other modes of quantification will produce `rdata` output files. These files have been specifically designed to work across various tools in the pipeline.

The general way of reading these files outside of the workflow is to load the files using R. In almost all the cases each `rdata` file contains three important variables:

* an object of XCMSSet: Contains the results of the step performed on the data (e.g alignment)
* varNameForNextStep: Contains the actual name of the XCMSSet object
* preprocessingSteps: Contains name of the previous processing steps performed on the data

One can load the `rdata` using the following commands:

```r
library(xcms)
load("path to rdata")
xcms_object <- get(varNameForNextStep)
```

## Annotation

Annotation is done using CAMERA. The results will be `rdata` files with the same format as described in the [quantification](#quantification) section.

However, for reading the files, the CAMERA package must be available.

In this case, the `varNameForNextStep` will refer to a CAMERA object rather than an XCMS object.

```r
library(CAMERA)
load("path to rdata")
camera_object <- get(varNameForNextStep)
```

## Identification

Identification is performed using 4 search engines: Metfrag, CSI:FINGERID, CFM-ID and an internal search engine after various pre-processing steps.

The results of reading MS2 data, quantification of library, and mapping MS2 to CAMERA are `rdata` files as described in the [quantification](#quantification) section.

The output of the search engines is tab-separated text files that among search engine specific columns include ID of the metabolites, identification scores, parent RT and mz, and the original MS2 file which were used to identify the metabolite.

## Final output

The most important outputs are the results of `process_output` which contains three tabular files, one for the peak table, one for the variable information (including identification etc) and metadata information.

* Peak table file: This is a tab-separated file that contains variables in rows and samples in columns.  
It uses . as decimal, and NA for missing values; the table does not contain metadata apart from row and column names; the row and column names are identical to the row names of the sample and variable metadata, respectively (see below)

* Sample metadata file: This is a tab-separated file that contains samples in rows and metadata in columns. It uses . as decimal and NA for missing values. The metadata includes the original file names for each sample and additional information provided by the phenotype file

* Variable metadata file: This is a tab-separated file that contains variables in rows and variable metadata in columns. It uses. as decimal and NA for missing values. This file contains mz, RT, adduct, isotope, and identification information (IDs, names of the metabolite, and scores) for each mass trace.

These three files are generated for each search engine and each ionization mode.
