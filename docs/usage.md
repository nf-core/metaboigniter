# nf-core/metaboigniter: Usage

Please read this documentation on the nf-core website: [MetaboIGNITER documentation page](https://nf-co.re/metaboigniter/usage)

## Table of contents

<!-- Install Atom plugin markdown-toc-auto for this ToC to auto-update on save -->
<!-- TOC START min:2 max:3 link:true asterisk:true update:true -->
* [Table of contents](#table-of-contents)
* [Introduction](#introduction)
* [Running the pipeline](#running-the-pipeline)
  * [Updating the pipeline](#updating-the-pipeline)
  * [Reproducibility](#reproducibility)
* [Main arguments](#main-arguments)
  * [`-profile`](#-profile)
  * [metabolomics specific parameters (**how to run the workflow**)](#how-to-run-the-workflow)
* [Job resources](#job-resources)
  * [Automatic resubmission](#automatic-resubmission)
  * [Custom resource requests](#custom-resource-requests)
* [AWS Batch specific parameters](#aws-batch-specific-parameters)
  * [`--awsqueue`](#--awsqueue)
  * [`--awsregion`](#--awsregion)
* [Other command line parameters](#other-command-line-parameters)
  * [`--outdir`](#--outdir)
  * [`--email`](#--email)
  * [`-name`](#-name)
  * [`-resume`](#-resume)
  * [`-c`](#-c)
  * [`--custom_config_version`](#--custom_config_version)
  * [`--custom_config_base`](#--custom_config_base)
  * [`--max_memory`](#--max_memory)
  * [`--max_time`](#--max_time)
  * [`--max_cpus`](#--max_cpus)
  * [`--plaintext_email`](#--plaintext_email)
  * [`--monochrome_logs`](#--monochrome_logs)
<!-- TOC END -->

## Introduction

Nextflow handles job submissions on SLURM or other environments, and supervises running the jobs. Thus the Nextflow process must run until the pipeline is finished. We recommend that you put the process running in the background through `screen` / `tmux` or similar tool. Alternatively you can run nextflow within a cluster job submitted your job scheduler.

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run nf-core/metaboigniter -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work            # Directory containing the nextflow working files
results         # Finished results (configurable, see below)
.nextflow_log   # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull nf-core/metaboigniter
```

### Reproducibility

It's a good idea to specify a pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [nf-core/metaboigniter releases page](https://github.com/nf-core/metaboigniter/releases) and find the latest version number - numeric only (eg. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future.

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments. Note that multiple profiles can be loaded, for example: `-profile docker` - the order of arguments is important!

If `-profile` is not specified at all the pipeline will be run locally and expects all software to be installed and available on the `PATH`.

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Conda) - see below.

* `docker`
  * A generic configuration profile to be used with [Docker](https://docker.com/)
  * Pulls software from Docker Hub: [`nfcore/metaboigniter`](https://hub.docker.com/r/nfcore/metaboigniter/)
* `singularity`
  * A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
  * Pulls software from Docker Hub: [`nfcore/metaboigniter`](https://hub.docker.com/r/nfcore/metaboigniter/)
* `podman`
  * A generic configuration profile to be used with [Podman](https://podman.io/)
  * Pulls software from Docker Hub: [`nfcore/metaboigniter`](https://hub.docker.com/r/nfcore/metaboigniter/)
* `shifter`
  * A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
  * Pulls software from Docker Hub: [`nfcore/metaboigniter`](https://hub.docker.com/r/nfcore/metaboigniter/)
* `charliecloud`
  * A generic configuration profile to be used with [Charliecloud](https://hpc.github.io/charliecloud/)
  * Pulls software from Docker Hub: [`nfcore/metaboigniter`](https://hub.docker.com/r/nfcore/metaboigniter/)
* `conda`
  * Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter or Charliecloud.
  * A generic configuration profile to be used with [Conda](https://conda.io/docs/)
  * Pulls most software from [Bioconda](https://bioconda.github.io/)
* `test`
  * A profile with a complete configuration for automated testing
  * Includes links to test data so needs no other parameters

## How to run the workflow

### Where to start

This depends on what type of data you have available. Here we describe three scenarios where:

1. You only have MS1 data
2. You have MS1 and MS2 data (in-silico identification), and
3. You have MS1, MS2, and an internal library.

The flow of the pipeline is controlled using several parameters that should be set using the [pipeline parameters](https://nf-co.re/metaboigniter/parameters).

> Note that because there are a large number of parameters for this pipeline, we recommend using a YAML file and supplying to the pipeline with the Nextflow option `-params-file`.
> Alternatively, you can create a Nextflow config file and supply this with `-c`.

### Convert your data

Before proceeding with the analysis you need to convert your data to open source format (`mzML`).
You can do this using the [msconvert](http://proteowizard.sourceforge.net/tools/msconvert.html) package in [ProteoWizard](http://proteowizard.sourceforge.net/index.shtml).
This must be done for all the raw files you have including MS1, MS2 and library files.

## Scenario 1) Only MS1 data

Please set the `perform_identification` parameter to `false`

```yaml
perform_identification: false
```

This will prevent the workflow to perform the identification. So you will not need to change the parameters related to identification

### Organize your mzML files

If you only have MS1 data and you wish to perform quantification, you should first organize your `mzML` files into a folder structure.
An example of such structure can be seen [here](https://github.com/nf-core/test-datasets/tree/metaboigniter).
You don't have to follow the folder tree in the example, you just have to make sure that `mzML` files from different ionization are placed in different folders.

If you only have one ionization mode (positive or negative), just put all the files in a single folder.
If you have both, then create two folders, one for each of the ionization modes.
For example if you want to follow our example, we create to folders called `mzML_NEG_Quant` and `mzML_POS_Quant`.
Then the correponding files will be placed in each directory.

```bash
    Mydata
    ├── mzML_NEG_Quant
    │   ├── Blank_1.mzML
    │   ├── Blank_2.mzML
    │   ├── Blank_3.mzML
    │   ├── D1.mzML
    │   ├── D2.mzML
    │   ├── D3.mzML
    │   ├── D4.mzML
    │   ├── QC_1.mzML
    │   ├── QC_2.mzML
    │   ├── QC_3.mzML
    │   ├── X1_Rep1.mzML
    │   ├── X2_Rep1.mzML
    │   ├── X3_Rep1.mzML
    │   ├── X6_Rep1.mzML
    │   ├── X7_Rep1.mzML
    │   └── X8_Rep1.mzML
    ├── mzML_POS_Quant
    │   ├── Blank_1.mzML
    │   ├── Blank_2.mzML
    │   ├── Blank_3.mzML
    │   ├── D1.mzML
    │   ├── D2.mzML
    │   ├── D3.mzML
    │   ├── D4.mzML
    │   ├── QC_1.mzML
    │   ├── QC_2.mzML
    │   ├── QC_3.mzML
    │   ├── X1_Rep1.mzML
    │   ├── X2_Rep1.mzML
    │   ├── X3_Rep1.mzML
    │   ├── X6_Rep1.mzML
    │   ├── X7_Rep1.mzML
    │   └── X8_Rep1.mzML
```

When you are ready with your folder structure you will need to set the `input` parameter to be a glob path to a folder containing `mzML` files used for doing quantification (MS1 data in positive ionization method).

You will also need to set `quant_mzml_files_neg` to a glob path to a folder containing `mzML` files used for doing quantification (MS1 data in negative ionization method).

For example:

```yaml
input: /User/XXX/myfiles/pos_quant_data/*.mzML
quant_mzml_files_neg: /User/XXX/myfiles/neg_quant_data/*.mzML
```

### Make phenotype file

A phenotype is a CSV (comma separated file) representing a table showing metadata of the samples.
Each row is one sample and each column is a meta field (columns are separated by comma).
An example of such file can be found [here](https://raw.githubusercontent.com/nf-core/test-datasets/metaboigniter/phenotype_positive.csv).

MetaboIGNITER expects a separate phenotype file for each ionization model. So if you have two ionization you will need to create two phenotype files.

This file is used to set class of the samples being analyzed.
The file should have at least two columns:

* The first column is showing the raw file name and extension (for example: `sample1.mzML`)
* The second column should show it's phenotype type.

This file is a comma separated file and should container header. For example:

| RawFile        | Class    | Groups    | Type     | rename     | Technical repl   | Age   | Gender   |
|--|--|--|--|--|--|--|--|
| Sample1.mzML   | Sample   | Disease   | keep     | Disease1   | 1                | 35    | M        |
| Sample2.mzML   | Sample   | Disease   | keep     | Disease2   | 1                | 35    | M        |
| Sample3.mzML   | Sample   | Control   | keep     | Control1   | 2                | 37    | F        |
| Sample4.mzML   | Sample   | Control   | keep     | Control2   | 2                | 37    | F        |
| Blank1.mzML    | Blank    | NA        | remove   | NA         | NA               | NA    | NA       |
| Blank2.mzML    | Blank    | NA        | remove   | NA         | NA               | NA    | NA       |
| Blank3.mzML    | Blank    | NA        | remove   | NA         | NA               | NA    | NA       |
| D1.mzML        | D1       | NA        | remove   | NA         | NA               | NA    | NA       |
| D2.mzML        | D2       | NA        | remove   | NA         | NA               | NA    | NA       |
| D3.mzML        | D3       | NA        | remove   | NA         | NA               | NA    | NA       |

The first column of this table must show the raw data file name (for example: `sample1.mzML`).
The file must have a header. Other information can also be added to this table such as `age`, `gender`, `time` etc.
One can plan ahead and add even more information.
In the example, we have added rename, technical replace and type - this information will be used later in the workflow to pre-process the samples.

For example, `Type` can be used to filter out the samples not needed further down the pipeline.
Rename can be us to rename the samples in the output file.
Technical replicates can be used to average the samples that have been injected more than two times etc.
The minimum number of columns is two showing the raw file name and class of the samples.

Please take your time and design the phenotype file so that you don't have to change it later.
Pretty much all the steps of the workflow will depend on the correct designing of this file.

We have included two examples of phenotype file in the [test data](https://github.com/nf-core/test-datasets/tree/metaboigniter).
The files are called `phenotype_positive.csv` and `phenotype_negative.csv`.
The example design includes six biological samples:

* Three blank samples (e.g, only the buffer were run)
* Dilution samples (D1, D2 etc), in which a different dilution of samples have been run
* QC samples that are the same replicate that was repeatedly run throughout the MS experiment.

After creating the phenotype files, you'll need to set the following parameters:

Set what type of ionization you have. You can either set to `pos` (only positive), `neg` (only negative), `both` (both positive and negative):

```yaml
type_of_ionization: "both"
```

> **Remember to set the path to required parameters for the selected ionization. Otherwise the workflow will fail!**

Set the absolute path to your ionization phenotype files:

* `phenotype_design_pos` - Path to a `csv` file containing the experimental design (MS1 data in positive ionization method).
* `phenotype_design_neg` - Path to a `csv` file containing the experimental design (MS1 data in negative ionization method)

For example, say you have only positive data.
Create you phenotype file and set `phenotype_design_pos` to the absolute path of your file line _(this is just an example!)_:

```yaml
phenotype_design_pos: "/User/XX/mydata/pos_phenotype.csv"
```

There will be a lot of different files generated by the workflow, if you are interested only in the final output part and identification information, please set the `publishDir_intermediate` flag to false:

```yaml
publishDir_intermediate: false
```

### Quantification specific parameters

#### Data Centroiding

We recommend inputting already centroided files. You can achieve this at the conversion steps in msconvert.
However, if your data is not centroided, you can let the workflow doing that for you.

We use the OpenMS _"PeakPickHiRes"_ tool to perform that. Set `need_centroiding` to `true` to perform the centroiding:

```yaml
need_centroiding: true
```

Please be aware that setting `need_centroiding` to `true` will do centroiding on all of your data including both ionizations, identification etc.

If you want non-defualt values, to control the parameters centroiding you can edit `openms_peak_picker_ini_pos.ini` and `openms_peak_picker_ini_neg.ini` files located under `metaboigniter/assets/openms`.
The description of the parameters can be found on [OpenMS website](https://abibuilder.informatik.uni-tuebingen.de/archive/openms/Documentation/nightly/html/TOPP_PeakPickerHiRes.html).

#### Mass Trace Detection (quantification)

MetaboIGNITER can perform quantification either using XCMS (default) or OpenMS (experimental).

> Note: **We only support OpenMS 2.4.0 at this stage**

This behaviour is controlled using two parameters for positive and negative ionization.

First, set whether you want to do quantification with OpenMS (openms) or XCMS (xcms) in positive and negative ionizations:

```yaml
quantification_openms_xcms_pos: "xcms"
quantification_openms_xcms_neg: "xcms"
```

#### Quantification using OpenMS

If you choose to perform the quantification using OpenMS, you should consider changing the parameters for OpenMS only.
You can edit `openms_feature_finder_metabo_ini_pos.ini` and `openms_feature_finder_metabo_ini_neg.ini` files located under `metaboigniter/assets/openms`.
The description of the parameters can be found on [OpenMS website](https://abibuilder.informatik.uni-tuebingen.de/archive/openms/Documentation/nightly/html/TOPP_FeatureFinderMetabo.html).

> When tuning the OpenMS parameters make sure that `report_convex_hulls` is set to true

#### Quantification using XCMS

MetaboIGNITER supports parameter detection using IPO. MetaboIGNITER can run IPO on pos, neg and library separately. Here we demonstrate the usage for positive ionization method.

The same principles apply to negative and library mode. If you decided to go with full IPO, you won't need to set other parameters.
In order to turn this parameter on, one should use:

```yaml
performIPO_pos: "none"
```

The default parameter sets IPO to off, you can control how to perform IPO using possible values:

* `none`: don't perform IPO
* `global`: performs IPO on all or selected number of samples
* `global_quant`: perform IPO only for quantification (not retention time correction and grouping)
* `local`: performs IPO on individual samples one at the time
* `local_quant`: performs IPO on individual samples only for quantification
* `local_RT`: performs IPO only for retention time correction and grouping

There are several parameters that need to be set for IPO to optimize. If you don't want do optimize a parameter, set its higher and lower boundaries to the same value.

If you don't want to do the parameter optimization, set IPO to off and set the XCMS parameters.
This includes the parameters for xcms mass trace detection, grouping and retention time correction.

#### Signal filtering

As described above, currently we support three time of signal filtering. You can turn them on and off depending on availability the data, experimental design or if you wish to do the manually later.

The first method is `blank filtering`. This module filters out the signals that have higher abundance in non-biological samples (e.g. blank) compared to biological samples.

The `dilution filtering` module filters out the signals that do not correlate with a specified dilution trend.

The `CV filtering` module filters out the signals that do not show desired coefficient of variation.
If you don't want to perform the CV filtering. Set the following to `false` and go to the next step of the workflow (no need to set the parameters for this step!):

#### Annotation (CAMERA)

MetaboIGNITER performs annotation using CAMERA package in R. We first do FWHM grouping, then perform adduct detection followed by isotope finding. The specific details of this can be found on [CAMERA webpage](http://bioconductor.org/packages/release/bioc/html/CAMERA.html).

### Identification Specific Parameters

Currently, MetaboIGNITER supports two types of identification. One is based on _in-silico_ (database) approach and the other is based on internal library.

If you would like to perform identification, please set `perform_identification` to `true`:

```yaml
perform_identification: true
```

Please also remember that we only perform identification for the ionization modes that you have quantification data for.

## Scenario 2) In-silico identification in MetaboIGNITER

MetaboIGNITER has a specific design for performing identification.
After performing quantification and annotation of MS1 data, the results will be fed into the identification sub-pipeline this part of the workflow, will first extract the MS2 information from the identification `mzML` files and map them to the quantification data.

If a parent ion was matched against a feature that was successfully annotated, we then estimate the neutral mass for that parent ion.
By doing that, the number of searches needed for identification will significantly decrease.
he rest of the ions that were matched against features without annotation will be searched using different adduct rules and charges.

The resulting scores from metabolite spectrum matches will be transformed into posterior error probability and re-matched to the features at the later step.

### Organize you mzML files (identification)

Before proceeding with setting the parameters for identification you need to complete the `mzMl` folder structure.
This basically follows the same design as the MS1 data preparation.
You need to create separate directories for `mzML` files that contain MS2 information.
So if you have MS2 files both positive and negative mode, you need to create two more folders.
For example, `mzML_NEG_ID` and `mzML_POS_ID` containing, negative and positive MS2 data respectively.

The following file tree shows an example of such structure. In this example, we have both positive and negative ionization. The files have been placed in different folders depending on the ionization and pre-processing needed.

```bash
    Mydata
    ├── hmdb_2017-07-23.csv
    ├── mzML_NEG_ID
    │   ├── Pilot_MS_Control_2_Neg_peakpicked.mzML
    │   └── Pilot_MS_Pool_2_Neg_peakpicked.mzML
    ├── mzML_NEG_Quant
    │   ├── Blank_1.mzML
    │   ├── Blank_2.mzML
    │   ├── Blank_3.mzML
    │   ├── D1.mzML
    │   ├── D2.mzML
    │   ├── D3.mzML
    │   ├── D4.mzML
    │   ├── QC_1.mzML
    │   ├── QC_2.mzML
    │   ├── QC_3.mzML
    │   ├── X1_Rep1.mzML
    │   ├── X2_Rep1.mzML
    │   ├── X3_Rep1.mzML
    │   ├── X6_Rep1.mzML
    │   ├── X7_Rep1.mzML
    │   └── X8_Rep1.mzML
    ├── mzML_POS_ID
    │   ├── Pilot_MS_Control_2_peakpicked.mzML
    │   └── Pilot_MS_Pool_2_peakpicked.mzML
    ├── mzML_POS_Quant
    │   ├── Blank_1.mzML
    │   ├── Blank_2.mzML
    │   ├── Blank_3.mzML
    │   ├── D1.mzML
    │   ├── D2.mzML
    │   ├── D3.mzML
    │   ├── D4.mzML
    │   ├── QC_1.mzML
    │   ├── QC_2.mzML
    │   ├── QC_3.mzML
    │   ├── X1_Rep1.mzML
    │   ├── X2_Rep1.mzML
    │   ├── X3_Rep1.mzML
    │   ├── X6_Rep1.mzML
    │   ├── X7_Rep1.mzML
    │   └── X8_Rep1.mzML
    ├── phenotype_negative.csv
    ├── phenotype_positive.csv
```

When you are ready with the folder structure you will need to set the parameters needed:

* `id_mzml_files_pos`: A glob path to a folder containing `mzML` files used for doing identification (MS2 data in positive ionization method)
* `id_mzml_files_neg`: A glob path to a folder containing `mzML` files used for doing identification (MS2 data in negative ionization method)

For example:

```yaml
id_mzml_files_pos: "/User/XXX/myfiles/id_mzml_files_pos/*mzML"
id_mzml_files_neg: "/User/XXX/myfiles/id_mzml_files_neg/*mzML"
```

If you quantification files also includes MS2 data, you can set `id_mzml_files_pos` and `id_mzml_files_neg` to the path of MS1 data (of course to respective ionization modes).

### Select your search engine

Currently, MetaboIGNITER supports three search engines, [MetFrag](https://ipb-halle.github.io/MetFrag/), [CSI:FingerID](https://bio.informatik.uni-jena.de/software/sirius/), and [CFM-ID](https://cfmid.wishartlab.com/) for performing identification.
These engines share some global parameters but also each of these will need specific set of parameters.

The user can select multiple search engines to do the identification.
In the case of multiple search engines, the workflow will have multiple final output, one for each search engine and ionization.

## Scenario 3) Characterize your own library

This part of the workflow is used to create and characterize in-house library.

This is how it works: we assume that the library consists of one or more `mzML` files, each containing a number of compounds.
A possible scenario is when the users have several standard metabolites that can have overlapping masses with unknown retention times.
The standards with overlapping masses can be run separately using MS, resulting in different runs.

MetaboIGNITER will help you to characterize this type of internal libraries.
You will need to construct the Characterization file (see below) that shows which standards are present in which `mzML` file.
The workflow will then do mass trace detection, MS2 extraction and mapping of parent ions to mass traces.
Doing so will result in finding the retention time and empirical `m/z` of each standard.
This will then be used to create identification parameters and search the biological MS2 files.

Set the library parameter to true if you would like to perform library search:

```yaml
perform_identification_internal_library: true
```

### Create your folder structure

The directory structure will be similar to those describe above. You will need to place positive and negative files in different folders.
In the following example, we provide the complete folder structure used for doing quantification, _in-silico_ and library identification.
In this example, we have plcaed the library files in `mzML_NEG_Lib` and `mzML_POS_Lib` folders.

```bash
    Mydata
    ├── hmdb_2017-07-23.csv
    ├── library_charac_neg.csv
    ├── library_charac_pos.csv
    ├── mzML_NEG_ID
    │   ├── Pilot_MS_Control_2_Neg_peakpicked.mzML
    │   └── Pilot_MS_Pool_2_Neg_peakpicked.mzML
    ├── mzML_NEG_Lib
    │   ├── P1rA_NEG.mzML
    │   ├── P1rB_NEG.mzML
    │   ├── P1rC_NEG.mzML
    │   └── P1rD_NEG.mzML
    ├── mzML_NEG_Quant
    │   ├── Blank_1.mzML
    │   ├── Blank_2.mzML
    │   ├── Blank_3.mzML
    │   ├── D1.mzML
    │   ├── D2.mzML
    │   ├── D3.mzML
    │   ├── D4.mzML
    │   ├── QC_1.mzML
    │   ├── QC_2.mzML
    │   ├── QC_3.mzML
    │   ├── X1_Rep1.mzML
    │   ├── X2_Rep1.mzML
    │   ├── X3_Rep1.mzML
    │   ├── X6_Rep1.mzML
    │   ├── X7_Rep1.mzML
    │   └── X8_Rep1.mzML
    ├── mzML_POS_ID
    │   ├── Pilot_MS_Control_2_peakpicked.mzML
    │   └── Pilot_MS_Pool_2_peakpicked.mzML
    ├── mzML_POS_Lib
    │   ├── P1rA_POS_180522155214.mzML
    │   ├── P1rB_POS_180522163438.mzML
    │   ├── P1rC_POS_180522171703.mzML
    │   └── P1rD_POS_180522175927.mzML
    ├── mzML_POS_Quant
    │   ├── Blank_1.mzML
    │   ├── Blank_2.mzML
    │   ├── Blank_3.mzML
    │   ├── D1.mzML
    │   ├── D2.mzML
    │   ├── D3.mzML
    │   ├── D4.mzML
    │   ├── QC_1.mzML
    │   ├── QC_2.mzML
    │   ├── QC_3.mzML
    │   ├── X1_Rep1.mzML
    │   ├── X2_Rep1.mzML
    │   ├── X3_Rep1.mzML
    │   ├── X6_Rep1.mzML
    │   ├── X7_Rep1.mzML
    │   └── X8_Rep1.mzML
    ├── phenotype_negative.csv
    ├── phenotype_positive.csv
```

Now set the folder paths to the library files - a glob path to a folder containing library `mzML` files used for doing adduct calculation.

If you don't have separate quantification data for the library, set `quant_library_mzml_files_pos` and `quant_library_mzml_files_neg` to the paths of the library files.

Also set a glob path to a folder containing `mzML` files (for library) used for doing identification (as described above) with  `id_library_mzml_files_pos` and `id_library_mzml_files_neg`.

For example, considering the structure above, we can set:

```yaml
quant_library_mzml_files_pos : "mydata/mzML_POS_Lib/*.mzML"
id_library_mzml_files_pos    : "mydata/mzML_POS_Lib/*.mzML"
quant_library_mzml_files_neg : "mydata/mzML_NEG_Lib/*.mzML"
id_library_mzml_files_neg    : "mydata/mzML_NEG_Lib/*.mzML"
```

### Create your library description files

You need to create a separate library description file for each of the ionisation modes.

An example of such file is provided [here](https://raw.githubusercontent.com/nf-core/test-datasets/metaboigniter/library_charac_pos.csv). This file must contain the following information in a comma separate file:

* Name of the `mzML` file containing the compound
* ID of the compound e.g. `HMDBID`
* Name of the compound
* Theoretical m/z of the compound

Here is an example of the expected table format:

| raw.File| HMDBID     | Name               | m.z           |
|--|--|--|--|
| a1.mzML | HMDB0000044  | Ascorbic acid      | 177.032087988 |
| a1.mzML | HMDB0000001  | 1-Methylhistidine  | 170.085126611 |
| a2.mzML | HMDB0000002  | 1,3-Diaminopropane | 75.08439833   |

In the pipeline parameters, set the absolute paths to `csv` files containing description of the library:

```yaml
library_description_pos: "path/to/table.csv"
library_description_neg: "path/to/table.csv"
```

## Parameter groups

The way to set the parameters is to use [nf-core](https://nf-co.re/metaboigniter/parameters) and set the desire parameters in their dedicated group.

Here we mention the parameter groups for the positive mode only.
The parameters for the negative ionization mode can be set similarly.
One just need to look for `negative` instead of `positive`:

* _Control parameters_
  * General parameters used to control what the workflow does. For example, centroiding, type of identification, search engines etc.
* _Quantification input files_
  * This group contains the parameter for setting the quantification input files. Exactly as described above
* _OpenMS setting files_
  * If you choose to do centroiding and/or quantificaiton (using OpenMS) you will need to set the corresponding setting files under this group.
* _Quantification parameter (positive mode)_
  * Used to set XCMS and IPO paramters for the positive or negative mode.
* _Filtering parameters (positive mode)_
  * This group includes the parameters used to control the filtering steps.
* Global identification parameters (positive mode)_
  * This group includes the parameters used to control the identification steps.

We expand the parameters for the filtering and the identification steps:

### Filtering parameters

#### Blank filtering

The first method is `blank filtering`. This module filters out the signals that have higher abundance in non-biological samples (e.g. blank) compared to biological samples.

If you don't want to perform the blank filtering. Set `blank_filter_pos` to `false` and go to the next step of the workflow _(no need to set the parameters for this step!)_:

```yaml
blank_filter_pos: false
```

#### Dilution filtering

This module filters out the signals that do not correlate with a specified dilution trend.

If you don't want to perform the dilution filtering. Set `dilution_filter_pos` to `false` and go to the next step of the workflow _(no need to set the parameters for this step!)_:

```yaml
dilution_filter_pos: false
```

#### CV filtering

This module filters out the signals that do not show the desired coefficient of variation.

If you don't want to perform the CV filtering. Set `cv_filter_pos` to `false` and go to the next step of the workflow _(no need to set the parameters for this step!)_:

```yaml
cv_filter_pos: false
```

### Identification parameters (positive mode)

This module is used to generate search parameters with mapped MS/MS spectra retrieved from the `mzML` files.
These parameters will be sent to all the search engines. You will then have the possibility to set the search engine specific parameters.

> The only exception is `database_msmstoparam_pos/neg_msnbase` that is only applicable in **MetFrag**.

Available databases are KEGG, PubChem, MetChem (a local database that needs to be set up beforehand). In addition, LocalCSV can be used which uses a CSV file for searching.

> Such a CSV file can be downloaded from [here](https://msbi.ipb-halle.de/~cruttkie/databases/).

If LocalCSV is selected, a specific file needs to be provided. The format of this file is very strict. See the database parameter.

```yaml
database_msmstoparam_pos_msnbase: "LocalCSV"
```

Adduct ruleset to be used:

* `primary`: contains most common adduct types:
`([M-H]-, [M-2H+Na]-, [M-2H+K]-, [M+Cl]-, [M+H]+, [M+Na]+, [M+K]+, [M+NH4]+)`
* `extended`: next to primary also additional adduct types

```yaml
adductRules_msmstoparam_pos_msnbase: "primary"
```

#### CSI:FINGERID parameters (positive mode)

This section control FINGERID parameters.

> IMPORTANT: we don't support database file for csi:fingerid. You will need to provide what database to use here, the rest of the parameters will be taken from there parameter file.

Database (this will overwrite the corresponding parameter in the input file). CSI:FingerID does not have `LocalCSV`.
So if you set this in the previous step, change this to your desired database (**one of**: `all`, `chebi`, `kegg`, `bio`, `natural products`, `pubmed`, `hmdb`, `biocyc`, `hsdb`, `knapsack`, `biological`, `zinc bio`, `gnps`, `pubchem`, `mesh`, `maconda`):

#### MetFrag parameters (positive mode)

We only need two parameters if the global parameters have been set properly. The most important is the database file.
An example of such a database can be found [here](https://raw.githubusercontent.com/nf-core/test-datasets/metaboigniter/hmdb_2017-07-23.csv).
You can either use the example for HMDB (2017) or generate your own using [MetChem](https://github.com/c-ruttkies/container-metchemdata). Please contact us if you need to generate this file.

#### CFM-ID parameters (positive mode)

You need to specify the database for CFM-ID. The rest of the parameters will be taken from the global parameters. Please see MetFrag parameter on how to construct the database.
This database must at least contain the following columns: id of the molecules, smile of the molecules, the mass of the molecules, name of the molecules and InChI of the molecules.
The best practice would be to use [MetChem](https://github.com/c-ruttkies/container-metchemdata) to construct the database. After constructing the database, you can then go ahead and set the required parameters.

#### Library controls and files (positive mode)

These parameters are used to provide inputs for library-based identification.
This had already been expanded. However, if you already have your library characterized e.g the results of `process_collect_library_pos_msnbase` and `process_collect_library_neg_msnbase`. You can set the corresponding parameters to prevent the re-characterization of the library.
The most important parameter in this section is `library_charactrization_file_pos` which has to be sent to the results of process_collect_library_pos_msnbase.

#### Internal library quantification and identification parameters (positive mode)

This is used to charactrize the library. Please set the parameters needed for finding the mass traces for the library. These are more or less follow the same design as the quantification of the biological samples.
Please see the description of OpenMS and XCMS above. In brief, if you have selected doing centroiding, you need to change OpenMS PeakPickerHiRes parameter file for the library.

Please edit the following files (separate for positive and negative):

```bash
assets/openms/openms_peak_picker_lib_ini_pos.ini
```

You will have to set whether you do the quantification using either OpenMS (set to OpenMS) or XCMS (set to xcms) (**for library**):

```yaml
quantification_openms_xcms_library_pos: "xcms"
```

If OpenMS selected, please edit the following files for doing mass trace detection for the library:

```bash
assets/openms/openms_feature_finder_metabo_lib_ini_pos.ini
```

If you have selected to do quantification using XCMS, you need to tune the following parameters (See the corresponding sections in the quantification above):

#### Parameters for XCMS and CAMERA (library)

The same parameters that were set for quantification and adducts identification should be set here for identification. See quantification parameters.

For example, one can run IPO for setting the parameters for use individual parameters. In addition you should set the parameters related to mapping of the MS2 ions to mass traces.

#### Internal library parameters (positive mode)

This group of parameters are used to do the charactrization. You need a library description files containing columns: name of the raw files, ID of the compounds, name of the compounds, and `m/z` of the compounds.

> We recommend using a YAML file and supplying to the pipeline with the Nextflow option `-params-file`.
> Alternatively, you can create a Nextflow config file and supply this with `-c`.

## Job resources

### Automatic resubmission

Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the steps in the pipeline, if the job exits with an error code of `143` (exceeded requested resources) it will automatically resubmit with higher requests (2 x original, then 3 x original). If it still fails after three times then the pipeline is stopped.

### Custom resource requests

Wherever process-specific requirements are set in the pipeline, the default value can be changed by creating a custom config file. See the files hosted at [`nf-core/configs`](https://github.com/nf-core/configs/tree/master/conf) for examples.
To find the exact name of a process you wish to modify the compute resources, check the live-status of a nextflow run displayed on your terminal or check the nextflow error for a line like so: `Error executing process > 'bwa'`. In this case the name to specify in the custom config file is `bwa`.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information.

If you are likely to be running `nf-core` pipelines regularly it may be a good idea to request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter (see definition above). You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

If you have any questions or issues please send us a message on [Slack](https://nf-co.re/join/slack) on the [`#configs` channel](https://nfcore.slack.com/channels/configs).

## AWS Batch specific parameters

Running the pipeline on AWS Batch requires a couple of specific parameters to be set according to your AWS Batch configuration. Please use the `-awsbatch` profile and then specify all of the following parameters.

### `--awsqueue`

The JobQueue that you intend to use on AWS Batch.

### `--awsregion`

The AWS region to run your job in. Default is set to `eu-west-1` but can be adjusted to your needs.

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

### `--outdir`

The output directory where the results will be saved.

### `--email`

Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits. If set in your user config file (`~/.nextflow/config`) then you don't need to specify this on the command line for every run.

### `-name`

Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic.

This is used in the MultiQC report (if not default) and in the summary HTML / e-mail (always).

**NB:** Single hyphen (core Nextflow option)

### `-resume`

Specify this when restarting a pipeline. Nextflow will used cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously.

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

**NB:** Single hyphen (core Nextflow option)

### `-c`

Specify the path to a specific config file (this is a core NextFlow command).

**NB:** Single hyphen (core Nextflow option)

Note - you can use this to override pipeline defaults.

### `--custom_config_version`

Provide git commit id for custom Institutional configs hosted at `nf-core/configs`. This was implemented for reproducibility purposes. Default is set to `master`.

```bash
## Download and use config file with following git commid id
--custom_config_version d52db660777c4bf36546ddb188ec530c3ada1b96
```

### `--custom_config_base`

If you're running offline, nextflow will not be able to fetch the institutional config files
from the internet. If you don't need them, then this is not a problem. If you do need them,
you should download the files from the repo and tell nextflow where to find them with the
`custom_config_base` option. For example:

```bash
NXF_OPTS = '-Xms1g -Xmx4g'
```

> Note that the nf-core/tools helper package has a `download` command to download all required pipeline
> files + singularity containers + institutional configs in one go for you, to make this process easier.

### `--max_memory`

Use to set a top-limit for the default memory requirement for each process.
Should be a string in the format integer-unit. eg. `--max_memory '8.GB'`

### `--max_time`

Use to set a top-limit for the default time requirement for each process.
Should be a string in the format integer-unit. eg. `--max_time '2.h'`

### `--max_cpus`

Use to set a top-limit for the default CPU requirement for each process.
Should be a string in the format integer-unit. eg. `--max_cpus 1`

### `--plaintext_email`

Set to receive plain-text e-mails instead of HTML formatted.

### `--monochrome_logs`

Set to disable colourful command line output and live life in monochrome.
