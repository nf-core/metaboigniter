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

<!-- TODO nf-core: Add documentation about anything specific to running your pipeline. For general topics, please point to (and add to) the main nf-core website. -->

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

## Main arguments

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

### `How to run the workflow`

#### Where to start

This depends on what type of data you have available. Here we describe three scenarios where 1) you only have MS1 data, 2) you have MS1 and MS2 data (in-silico identification), and 3) you have MS1, MS2, and an internal library.
The flow of the pipeline is controlled using several parameters that should be set using **nf-core schemas**

#### Convert your data

Before proceeding with the analysis you need to convert your data to open source format (mzML). You can do this using **[msconvert](http://proteowizard.sourceforge.net/tools/msconvert.html)** package in **[ProteoWizard](http://proteowizard.sourceforge.net/index.shtml)**. This must be done for all the raw files you have including MS1, MS2 and library files.

**Senario 1) you only have MS1 data:**
Please open the parameter file and set the following parameter to "false"

```nextflow
perform_identification=false
```

This will prevent the workflow to perform the identification. So you will not need to change the parameters related to identification

#### Organize you mzML files

If you only have MS1 data and you wish to perform quantification, you should first organize your mzML files into a folder structure. An example of such structure can be seen [here](https://github.com/nf-core/test-datasets/tree/metaboigniter). You don't have to follow the folder tree in the example. You just have to make sure that mzML files from different ionization are placed in different folders. If you only have one ionization mode (positive or negative), just put all the files in a single folder. If you have both, then create two folders, one for each of the ionization modes. For example if you want to follow our example, we create to folders called mzML_NEG_Quant and mzML_POS_Quant. Then the correponding files will be placed in each directory.

```bash
    Mydata
    ├── mzML_NEG_Quant
    │   ├── Blank_1.mzML
    │   ├── Blank_2.mzML
    │   ├── Blank_3.mzML
    │   ├── D1.mzML
    │   ├── D2.mzML
    │   ├── D3.mzML
    │   ├── D4.mzML
    │   ├── QC_1.mzML
    │   ├── QC_2.mzML
    │   ├── QC_3.mzML
    │   ├── X1_Rep1.mzML
    │   ├── X2_Rep1.mzML
    │   ├── X3_Rep1.mzML
    │   ├── X6_Rep1.mzML
    │   ├── X7_Rep1.mzML
    │   └── X8_Rep1.mzML
    ├── mzML_POS_Quant
    │   ├── Blank_1.mzML
    │   ├── Blank_2.mzML
    │   ├── Blank_3.mzML
    │   ├── D1.mzML
    │   ├── D2.mzML
    │   ├── D3.mzML
    │   ├── D4.mzML
    │   ├── QC_1.mzML
    │   ├── QC_2.mzML
    │   ├── QC_3.mzML
    │   ├── X1_Rep1.mzML
    │   ├── X2_Rep1.mzML
    │   ├── X3_Rep1.mzML
    │   ├── X6_Rep1.mzML
    │   ├── X7_Rep1.mzML
    │   └── X8_Rep1.mzML
```

When you are ready with your folder structure you will need to set the parameters needed:
a glob path to a folder containing mzML files used for doing quantification (MS1 data in positive ionization method)

```nextflow
input
```

a glob path to a folder containing mzML files used for doing quantification (MS1 data in negative ionization method)

```nextflow
quant_mzml_files_neg
```

for example:

```nextflow
input =/User/XXX/myfiles/pos_quant_data/*mzML
```

#### Make phenotype file

A phenotype is a CSV (comma separated file) representing a table showing metadata of the samples. Each row is one sample and each column is a meta field (columns are separated by comma). An example of such file can be found [here](https://raw.githubusercontent.com/nf-core/test-datasets/metaboigniter/phenotype_positive.csv). MetaboIGNITER expects a separate phenotype file for each ionization model. So if you have two ionization you will need to create two phenotype file.
This file is used to set class of the samples being analyzed. The file should have at least two column: the first column is showing the raw file name and extension (for example sample1.mzML) and the second column should show it's phenotype type. This file is a comma separated file and should container header (see the example):

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

The first column of this table must show the raw data file name (for example sample1.mzML). The file must have a header. Other information can also be added to this table such as age, gender, time etc. One can plan ahead and add even more information. In the example, we have added rename, technical replace and type. This information will be used later in the workflow to pre-process the samples. For example, Type can be used to filter out the samples not needed further down the pipeline. Rename can be us to rename the samples in the output file. Technical replicates can be used to average the samples that have been injected more than two times etc. The minimum number of columns is two showing the raw file name and class of the samples.

Please take your time and design the phenotype file so that you don't have to change it later. Pretty much all the steps of the workflow will depend on the correct designing of this file.

We included two examples of phenotype file in the [test data](https://github.com/nf-core/test-datasets/tree/metaboigniter). The files are called *phenotype_positive.csv* and *phenotype_negative.csv*. The example design, includes six biological samples, three blank samples (e.g, only the buffer were run), dilution samples (D1, D2 etc), in which a different dilution of samples have been run. QC samples that are the same replicate that was repeatedly run throughout the MS experiment.

After fixing the phenotype files, please set the following parameters

 Set what type of ionization you have. You can either set to 'pos' (only positive), 'neg' (only negative), 'both' (both positive and negative):

```nextflow
type_of_ionization
```

**Remember to set the path to required parameters for the selected ionization. Otherwise the workflow will fail!**

Set absolute path to your ionization phenotype files:

Path to a csv file containing the experimental design (MS1 data in positive ionization method)

```nextflow
phenotype_design_pos=""
```

Path to a csv file containing the experimental design (MS1 data in negative ionization method)

```nextflow
phenotype_design_neg=""
```

*for example you have only positive data. Create you phenotype file and set "phenotype_design_pos" to absolute path of your file line (this is just an example!):*

```nextflow
phenotype_design_pos="/User/XX/mydata/pos_phenotype.csv"
```

In the rest of the document we will describe the overall flow of the pipeline. You can set specific parameters using nf-core schemas

```nextflow
peakwidthlow_quant_pos_xcms
peakwidthlow_quant_neg_xcms
```

but you only have positive data. Take peakwidthlow_quant_pos_xcms, search it in the parameters file and set its value with your desired parameter like peakwidthlow_quant_pos_xcms=5. You can ignore the neg part.

There will be a lot of different files generated by the workflow, if you are interested only in the final output part and identification information, please set this flag to false

```nextflow
publishDir_intermediate
```

#### Quantification specific parameters

**Data Centroiding:**

We recommend inputting already centroided files. You can achieve this at the conversion steps in msconvert. However, if your data is not centroided, you can let the workflow doing that for you. We use OpenMS "PeakPickHiRes" tool to perform that. Set the following parameter to *true* to perform the centroiding:

```nextflow
need_centroiding
```

Please be aware that setting need_centroiding to true will do centroiding on all of your data including both ionizations, identification etc.

If you want non-defualt values, to control the parameters centroiding you can edit *openms_peak_picker_ini_pos.ini* and *openms_peak_picker_ini_neg.ini* files located under *metaboigniter/assets/openms*. The description of the parameters can be found on [OpenMS website](https://abibuilder.informatik.uni-tuebingen.de/archive/openms/Documentation/nightly/html/TOPP_PeakPickerHiRes.html).

**Mass Trace Detection (quantification):**

MetaboIGNITER can perform quantification either using XCMS (default) or OpenMS (experimental). **We only support OpenMS 2.4.0 at this stage**
This behaviour is controlled using two parameters for positive and negative ionization:

set whether you want to do quantification with OpenMS (openms) or XCMS (xcms) in positive ionization:

```nextflow
quantification_openms_xcms_pos
```

set whether you want to do quantification with OpenMS (openms) or XCMS (xcms) for negative ionization:

```nextflow
quantification_openms_xcms_neg="xcms"
```

**Quantification using OpenMS:**

If you choose to perform the quantification using OpenMS, you should consider changing the parameters for OpenMS only. You can edit *openms_feature_finder_metabo_ini_pos.ini* and *openms_feature_finder_metabo_ini_neg.ini* files located under *metaboigniter/assets/openms*. The description of the parameters can be found on [OpenMS website](https://abibuilder.informatik.uni-tuebingen.de/archive/openms/Documentation/nightly/html/TOPP_FeatureFinderMetabo.html). **When tuning the OpenMS parameters make sure that "report_convex_hulls" is set to true**

**Quantification using XCMS:**

MetaboIGNITER supports parameter detection using IPO. MetaboIGNITER can run IPO on pos, neg and library separately. Here we demonstrate the usage for positive ionization method.
The same principles apply to negative and library mode. If you decided to go with full IPO, you won't need to set other parameters.
In order to turn this parameter on, one should use:

```nextflow
performIPO_pos="none"
```

The default parameter sets IPO to off, you can control how to perform IPO using possible values: "none": don't perform IPO, "global": performs IPO on all or selected number of samples. "global_quant": perform IPO only for quantification (not retention time correction and grouping), "local": performs IPO on individual samples one at the time. "local_quant": performs IPO on individual samples only for quantification, "local_RT": performs IPO only for retention time correction and grouping.

There are several parameters that need to be set for IPO to optimize. If you don't want do optimize a parameter, set its higher and lower boundaries to the same value.

If you don't want to do the parameter optimization, set IPO to off and set the XCMS parameters. This includes the parameters for xcms mass trace detection, grouping and retention time correction.

**Signal filtering:**

As described above, currently we support three time of signal filtering. You can turn them on and off depending on availability the data, experimental design or if you wish to do the manually later.

The first method is *blank filtering*. This module filters out the signals that have higher abundance in non-biological samples (e.g. blank) compared to biological samples.

The *dilution filtering* module filters out the signals that do not correlate with a specified dilution trend.

The *CV filtering* module filters out the signals that do not show desired coefficient of variation.
If you don't want to perform the CV filtering. Set the following to *false* and go to the next step of the workflow (no need to set the parameters for this step!):

**Annotation (CAMERA):**

MetaboIGNITER performs annotation using CAMERA package in R. We first do FWHM grouping, then perform adduct detection followed by isotope finding. The specific details of this can be found on [CAMERA webpage](http://bioconductor.org/packages/release/bioc/html/CAMERA.html).

#### Identification Specific Parameters

Currently, MetaboIGNITER supports two types of identification. One is based on in-silico (database) approach and the other is based on internal library.

If you would like to perform identification, please set the following parameters to true:

```nextflow
perform_identification=true
```

Please also remember that we only perform identification for the ionization modes that you have quantification data for.

**Senario 2) In-silico identification in MetaboIGNITER:**

MetaboIGNITER has a specific design for performing identification. After performing quantification and annotation of MS1 data, the results will be fed into the identification sub-pipeline this part of the workflow, will first extract the MS2 information from the identification mzML files and map them to the quantification data. If a parent ion was matched against a feature that was successfully annotated, we then estimate the neutral mass for that parent ion. By doing that, the number of searches needed for identification will significantly decrease. The rest of the ions that were matched against features without annotation will be searched using different adduct rules and charges. The resulting scores from metabolite spectrum matches will be transformed into posterior error probability and re-matched to the features at the later step.

#### Organize you mzML files (identification)

Before proceeding with setting the parameters for identification you need to complete the mzMl folder structure.
This basically follows the same design as the MS1 data preparation. You need to create separate directories for mzML files that contain MS2 information. So if you have MS2 files both positive and negative mode, you need to create two more folders. For example, mzML_NEG_ID and mzML_POS_ID containing, negative and positive MS2 data respectively. The following file tree shows an example of such structure. In this example, we have both positive and negative ionization. The files have been placed in different folders depending on the ionization and pre-processing needed.

```bash
    Mydata
    ├── hmdb_2017-07-23.csv
    ├── mzML_NEG_ID
    │   ├── Pilot_MS_Control_2_Neg_peakpicked.mzML
    │   └── Pilot_MS_Pool_2_Neg_peakpicked.mzML
    ├── mzML_NEG_Quant
    │   ├── Blank_1.mzML
    │   ├── Blank_2.mzML
    │   ├── Blank_3.mzML
    │   ├── D1.mzML
    │   ├── D2.mzML
    │   ├── D3.mzML
    │   ├── D4.mzML
    │   ├── QC_1.mzML
    │   ├── QC_2.mzML
    │   ├── QC_3.mzML
    │   ├── X1_Rep1.mzML
    │   ├── X2_Rep1.mzML
    │   ├── X3_Rep1.mzML
    │   ├── X6_Rep1.mzML
    │   ├── X7_Rep1.mzML
    │   └── X8_Rep1.mzML
    ├── mzML_POS_ID
    │   ├── Pilot_MS_Control_2_peakpicked.mzML
    │   └── Pilot_MS_Pool_2_peakpicked.mzML
    ├── mzML_POS_Quant
    │   ├── Blank_1.mzML
    │   ├── Blank_2.mzML
    │   ├── Blank_3.mzML
    │   ├── D1.mzML
    │   ├── D2.mzML
    │   ├── D3.mzML
    │   ├── D4.mzML
    │   ├── QC_1.mzML
    │   ├── QC_2.mzML
    │   ├── QC_3.mzML
    │   ├── X1_Rep1.mzML
    │   ├── X2_Rep1.mzML
    │   ├── X3_Rep1.mzML
    │   ├── X6_Rep1.mzML
    │   ├── X7_Rep1.mzML
    │   └── X8_Rep1.mzML
    ├── phenotype_negative.csv
    ├── phenotype_positive.csv
```

When you are ready with the folder structure you will need to set the parameters needed:
A glob path to a folder containing mzML files used for doing identification (MS2 data in positive ionization method)

```nextflow
id_mzml_files_pos =""
```

A glob path to a folder containing mzML files used for doing identification (MS2 data in negative ionization method)

```nextflow
id_mzml_files_neg=""
```

for example:

```nextflow
input ="/User/XXX/myfiles/id_mzml_files_pos/*mzML"
```

If you quantification files also includes MS2 data, you can set *id_mzml_files_pos* and *id_mzml_files_neg* to the path of MS1 data (of course to respective ionization modes)

**Select your search engine:**

Currently, MetaboIGNITER supports three search engines, [MetFrag](https://ipb-halle.github.io/MetFrag/), [CSI:FingerID](https://bio.informatik.uni-jena.de/software/sirius/), and [CFM-ID](https://cfmid.wishartlab.com/) for performing identification. These engines share some global parameters but also each of these will need specific set of parameters. The user can select multiple search engines to do the identification. In the case of multiple search engines, the workflow will have multiple final output, one for each search engine and ionization.

**Senario 3) Characterize your own library:**

This part of the workflow is used to create and characterize in-house library. This is how it works: we assume that the library consists of one or more mzML files, each containing a number of compounds. A possible scenario is when the users have several standard metabolites that can have overlapping masses with unknown retention times. The standards with overlapping masses can be run separately using MS, resulting in different runs. MetaboIGNITER will help you to characterize this type of internal libraries. You will need to construct the Characterization file (see below) that shows which standards are present in which mzML file. The workflow will then do mass trace detection, MS2 extraction and mapping of parent ions to mass traces. Doing so will result in finding the retention time and empirical m/z of each standard. This will then be used to create identification parameters and search the biological MS2 files.

Set the library parameter to true if you would like to perform library search:

```nextflow
perform_identification_internal_library=true
```

#### Create your folder structure

The directory structure will be similar to those describe above. You will need to place positive and negative files in different folders. In the following example, we provide the complete folder structure used for doing quantification, in-silico and library identification. In this example, we have plcaed the library files in mzML_NEG_Lib and mzML_POS_Lib folders.

```bash
    Mydata
    ├── hmdb_2017-07-23.csv
    ├── library_charac_neg.csv
    ├── library_charac_pos.csv
    ├── mzML_NEG_ID
    │   ├── Pilot_MS_Control_2_Neg_peakpicked.mzML
    │   └── Pilot_MS_Pool_2_Neg_peakpicked.mzML
    ├── mzML_NEG_Lib
    │   ├── P1rA_NEG.mzML
    │   ├── P1rB_NEG.mzML
    │   ├── P1rC_NEG.mzML
    │   └── P1rD_NEG.mzML
    ├── mzML_NEG_Quant
    │   ├── Blank_1.mzML
    │   ├── Blank_2.mzML
    │   ├── Blank_3.mzML
    │   ├── D1.mzML
    │   ├── D2.mzML
    │   ├── D3.mzML
    │   ├── D4.mzML
    │   ├── QC_1.mzML
    │   ├── QC_2.mzML
    │   ├── QC_3.mzML
    │   ├── X1_Rep1.mzML
    │   ├── X2_Rep1.mzML
    │   ├── X3_Rep1.mzML
    │   ├── X6_Rep1.mzML
    │   ├── X7_Rep1.mzML
    │   └── X8_Rep1.mzML
    ├── mzML_POS_ID
    │   ├── Pilot_MS_Control_2_peakpicked.mzML
    │   └── Pilot_MS_Pool_2_peakpicked.mzML
    ├── mzML_POS_Lib
    │   ├── P1rA_POS_180522155214.mzML
    │   ├── P1rB_POS_180522163438.mzML
    │   ├── P1rC_POS_180522171703.mzML
    │   └── P1rD_POS_180522175927.mzML
    ├── mzML_POS_Quant
    │   ├── Blank_1.mzML
    │   ├── Blank_2.mzML
    │   ├── Blank_3.mzML
    │   ├── D1.mzML
    │   ├── D2.mzML
    │   ├── D3.mzML
    │   ├── D4.mzML
    │   ├── QC_1.mzML
    │   ├── QC_2.mzML
    │   ├── QC_3.mzML
    │   ├── X1_Rep1.mzML
    │   ├── X2_Rep1.mzML
    │   ├── X3_Rep1.mzML
    │   ├── X6_Rep1.mzML
    │   ├── X7_Rep1.mzML
    │   └── X8_Rep1.mzML
    ├── phenotype_negative.csv
    ├── phenotype_positive.csv
```

Now set the folder paths to the library files.
a glob path to a folder containing library mzML files used for doing adduct calculation. If you don't have separate quantification data for the library, set this to path of the library file:

```nextflow
quant_library_mzml_files_pos=""
quant_library_mzml_files_neg=""
```

a glob path to a folder containing mzML files (for library) used for doing identification (as described above):

```nextflow
id_library_mzml_files_pos=""
id_library_mzml_files_neg=""
```

For example, considering the structure above, we can set quant_library_mzml_files_pos and id_library_mzml_files_pos to "mydata/mzML_POS_Lib/\*.mzML" and quant_library_mzml_files_neg and id_library_mzml_files_neg to "mydata/mzML_NEG_Lib/\*.mzML".

#### Create your library description files

You need to fix for each of the ionisation mode, a separate library description file. An example of such file is provided [here](https://raw.githubusercontent.com/nf-core/test-datasets/metaboigniter/library_charac_pos.csv). This file must contain the following information in a comma separate file:

* Name of the mzML file containing the compound

* ID of the compound e.g. HMDB ID

* Name of the compound

* Theoretical m/z of the compound

Here is an example of the expected table format:

```bash
| raw.File| HMDB.ID      | Name               | m.z           |
|--|--|--|--|
| a1.mzML | HMDB0000044  | Ascorbic acid      | 177.032087988 |
| a1.mzML | HMDB0000001  | 1-Methylhistidine  | 170.085126611 |
| a2.mzML | HMDB0000002  | 1,3-Diaminopropane | 75.08439833   |
```

Absolute path to a csv file containing description of the library:

```nextflow
library_description_pos=""
library_description_neg=""
```

The rest of the parameters are described in the nf-core parameter schema.

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
NXF_OPTS='-Xms1g -Xmx4g'
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
