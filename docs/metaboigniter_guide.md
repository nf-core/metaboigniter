
# Introduction

MetaboIGNITER is a comprehensive pipeline of several independent tools used to pre-process liquid chromatography-mass spectrometry (LCMS) data.  We use Nextflow and nf-core to build and run the workflow but parts of this pipeline have also been implemented using Galaxy as part of [PhenoMeNal](https://github.com/phnmnl/) and [Pachyderm](https://github.com/pharmbio/LC-MS-Pachyderm).

We strongly recommend the users to familiarize themselves with [Nextflow](https://www.nextflow.io/) and [nf-core](https://nf-co.re/) before proceeding with the tutorial. We assume that users have working knowledge of LC-MS data processing.

# Design

The workflow performs MS1 based quantification and MS2 based identification using combinition of different modules. The following steps can be performed using the workflow:

- Centroiding (optional): Also refered to as peak pickering is a step that reduce the distribution of ions derived from a single mass to the peak of the distribution.
- mass trace detection: The ions derived from the same analytes are clustered together forming a mass trace. These are the entities that will be used for quantification.
- mass trace matching and retenetion time (RT) correction: The mass traces across different samples will be match against each other and  RT shift between the samples will be adjusted.
- filtering (optional): The mass traces will be filtered out based on the QC samples.
- Annotation: The isotopes and adducts will be annotated in this step.
- MS2 (identification): At the moment we support two types of identification: in-silico and identificaiton based on internal library. This will be expaned in the correponding section. At the moment we do not support MS1-based identification.

# Where to start

This depends on what type of data you have available. Here we describe three scenarios where 1) you only have MS1 data, 2) you have MS1 and MS2 data (in-silico identification), and 3) you have MS1, MS2, and an internal library.
The flow of the pipeline is controlled using several parameters that should be set in the

## Convert your data

Before proceeding with the analysis you need to convert your data to open source format (mzML). You can do this using **[msconvert](http://proteowizard.sourceforge.net/tools/msconvert.html)** package in **[ProteoWizard](http://proteowizard.sourceforge.net/index.shtml)**. This must be done for all the raw files you have including MS1, MS2 and library files.

## Install Nextflow

You will need to have Nextflow installed. We only tested the workflow on Linux, the containers should work equally good on other operating systems. [Please consult Nextflow documentation on how to install Nextflow](https://www.nextflow.io/docs/latest/getstarted.html).

## Install Docker or Singularity

Currently MetaboIGNITER only works using Docker (the recommended way) or Singularity. Please make sure that you have at least one of them installed. There are excellent guides on how to install **[Docker](https://docs.docker.com/install/)** and **[Singularity](https://sylabs.io/guides/3.0/user-guide/installation.html)**.

## Pull the MetaboIGNITER repository

Assuming that you already have [Git installed](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git),you can either pull the repository with or without the testing data.

With testing data:

    git clone --recursive https://github.com/MetaboIGNITER/metaboigniter.git

without the testing data:

    git clone https://github.com/MetaboIGNITER/metaboigniter.git

This will create a directory called "metaboigniter" where all the necessary files will be there.

## Run the workflow

For running the test dataset:

    nextflow run main.nf -profile test,docker

For running on your own data, set the parameters below and then:

    nextflow run main.nf -profile analysis,docker

If you want to run singularity, replace docker with singularity. The main workflow path (main.nf) is in the case that you are standing in the main directory of the workflow. Otherwise, replace main.nf with its correct path

## Set the parameters

Currently all the parameters of the workflow can be set using a setting file which is located in ***"metaboigniter/conf/parameters.config"***. You can use regular text editors to edit this file. Depending on the type of the analysis you wish to run, some parameters can be left unchanged. Please follow the tutorial.

**When setting parameters, add the values within the double quotations ("") if the parameters (equal sign) is followed by double quotation Otherwise just set the value in front of the equal sign. For example:**

If we want to set the following parameter we need to put the value within quotations because the parameter is followed by an equal sign and quotation!:

    quant_mzml_files_pos=""

But for the following one, you don't need quotation because the parameters defualt value does not have quotation.

     perform_identification=false

**In general, when setting parameters, use quotations for text, names. The rest of the parameters do not need quotations.**

# 1) you only have MS1 data

Please open the parameter file and set the following parameter to "false"

    perform_identification=false

This will prevent the workflow to perform the identification. So you will not need to change the parameters related to identification

## Organize you mzML files

If you only have MS1 data and you wish to perform quantification, you should first organize your mzML files into a folder structure. An example of such structure can be seen [here](https://github.com/MetaboIGNITER/test-datasets). You don't have to follow the folder tree in the example. You just have to make sure that mzML files from different ionization are placed in different folders. If you only have one ionization mode (positive or negative), just put all the files in a single folder. If you have both, then create two folders, one for each of the ionization modes. For example if you want to follow our example, we create to folders called mzML_NEG_Quant and mzML_POS_Quant. Then the correponding files will be placed in each directory.

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

When you are ready with your folder structure you will need to set the parameters needed:
a glob path to a folder containing mzML files used for doing quantification (MS1 data in positive ionization method)

    quant_mzml_files_pos =""

a glob path to a folder containing mzML files used for doing quantification (MS1 data in negative ionization method)

    quant_mzml_files_neg=""

for example:

    quant_mzml_files_pos ="/User/XXX/myfiles/pos_quant_data/*mzML"

## Make phenotype file

A phenotype is a CSV (comma separated file) representing a table showing metadata of the samples. Each row is one sample and each column is a meta field (columns are separated by comma). An example of such file can be found [here](https://raw.githubusercontent.com/MetaboIGNITER/test-datasets/master/phenotype_positive.csv). MetaboIGNITER expects a separate phenotype file for each ionization model. So if you have two ionization you will need to create two phenotype file.
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

We included two examples of phenotype file in the [test data](https://github.com/MetaboIGNITER/test-datasets). The files are called *phenotype_positive.csv* and *phenotype_negative.csv*. The example design, includes six biological samples, three blank samples (e.g, only the buffer were run), dilution samples (D1, D2 etc), in which a different dilution of samples have been run. QC samples that are the same replicate that was repeatedly run throughout the MS experiment.

After fixing the phenotype files, please set the following parameters

 Set what type of ionization you have. You can either set to 'pos' (only positive), 'neg' (only negative), 'both' (both positive and negative):

      type_of_ionization

Set absolute path to your ionization phenotype files:

Path to a csv file containing the experimental design (MS1 data in positive ionization method)

    phenotype_design_pos=""

Path to a csv file containing the experimental design (MS1 data in negative ionization method)

    phenotype_design_neg=""

*for example you have only positive data. Create you phenotype file and set "phenotype_design_pos" to absolute path of your file line (this is just an example!):*

    phenotype_design_pos="/User/XX/mydata/pos_phenotype.csv"

In the rest of the document we will describe both positive (parameters with "pos" in their names) and negative (parameters with "neg" in their names) parameters you only need to set the parameters for the ionization that you have. The best way to find the parameters is to search them using search function of your text editor. For example if we ask you to set:

    peakwidthlow_quant_pos_xcms
    peakwidthlow_quant_neg_xcms

but you only have positive data. Take peakwidthlow_quant_pos_xcms, search it in the parameters file and set its value with your desired parameter like peakwidthlow_quant_pos_xcms=5. You can ignore the neg part.

## Quantification specific parameters

### Data Centroiding

We recommend inputting already centroided files. You can achieve this at the conversion steps in msconvert. However, if your data is not centroided, you can let the workflow doing that for you. We use OpenMS "PeakPickHiRes" tool to perform that. Set the following parameter to *true* to perform the centroiding:

    need_centroiding

Please be aware that setting need_centroiding=true will do centroiding on all of your data including both ionization, identification etc.

If you want non-defualt values, to control the parameters centroiding you can edit *openms_peak_picker_ini_pos.ini* and *openms_peak_picker_ini_neg.ini* files located under *metaboigniter/assets/openms*. The description of the parameters can be found on [OpenMS website](https://abibuilder.informatik.uni-tuebingen.de/archive/openms/Documentation/nightly/html/TOPP_PeakPickerHiRes.html).

### Mass Trace Detection (quantification)

MetaboIGNITER can perform quantification either using XCMS (default) or OpenMS (experimental). **We only support OpenMS 2.4.0 at this stage**
This behavior is controlled using two parameters for positive and negative ionization:

set whether you want to do quantification with OpenMS (openms) or XCMS (xcms) in positive ionization:

    quantification_openms_xcms_pos="xcms"

set whether you want to do quantification with OpenMS (openms) or XCMS (xcms) for negative ionization:

    quantification_openms_xcms_neg="xcms"

#### Quantification using OpenMS

If you choose to perform the quantification using OpenMS, you should consider changing the parameters for OpenMS only. You can edit *openms_feature_finder_metabo_ini_pos.ini* and *openms_feature_finder_metabo_ini_neg.ini* files located under *metaboigniter/assets/openms*. The description of the parameters can be found on [OpenMS website](https://abibuilder.informatik.uni-tuebingen.de/archive/openms/Documentation/nightly/html/TOPP_FeatureFinderMetabo.html). **When tuning the OpenMS parameters make sure that "report_convex_hulls" is set to true**

#### Quantification using XCMS

This is the default behavior of the workflow. You need to set the following parameters:

Maxmial tolerated m/z deviation in consecutive scans, in ppm (parts per million):

    masstrace_ppm_pos_xcms=10
    masstrace_ppm_neg_xcms=10

Minimum value of chromatographic peak width in seconds:

    peakwidthlow_quant_pos_xcms=5
    peakwidthlow_quant_neg_xcms=5

Maximum value of chromatographic peak width in seconds:

    peakwidthhigh_quant_pos_xcms=30
    peakwidthhigh_quant_neg_xcms=30

Argument which is useful for data that was centroided without any intensity threshold, centroids with intensity smaller noise are omitted from ROI detection:

    noise_quant_pos_xcms=1000
    noise_quant_neg_xcms=1000

This should show the column name in the CSV file representing the class of the metabolite. In the case of the above phenotype table it should be set to Class

    phenodatacolumn_quant_pos="Class"
    phenodatacolumn_quant_neg="Class"

### Grouping and retention time correction (sample matching)

We use XCMS to do the group and retention time correction. You should set the following parameters:

Bandwidth (standard deviation or half width at half maximum) of gaussian smoothing kernel to apply to the peak density chromatogram:

    bandwidth_group_N1_pos_xcms=15
    bandwidth_group_N1_neg_xcms=15

Width of overlapping m/z slices to use for creating peak density chromatograms and grouping peaks across samples"

    mzwid_group_N1_pos_xcms=0.005
    mzwid_group_N1_neg_xcms=0.005

Method to use for retention time correction. There are 2 methods available:
loess: Fit a polynomial surface determined by one or more numerical predictors, using local fitting.

obiwarp:Calculate retention time deviations for each sample. It is based on the code at [here](http://obi-warp.sourceforge.net/). However, this function is able to align multiple samples, by a center-star strategy.

    method_align_N1_pos_xcms="loess"
    method_align_N1_neg_xcms="loess"

The following parameters are the same as above, but will be applied after correction for the retention time shift. You should potentially consider decreasing these depending on the amount if shift your spectra have.

    bandwidth_group_N2_pos_xcms=15
    bandwidth_group_N2_neg_xcms=15
    mzwid_group_N2_pos_xcms=0.005
    mzwid_group_N2_neg_xcms=0.005

### Signal filtering

As described above, currently we support three time of signal filtering. You can turn them on and off depending on availability the data, experimental design or if you wish to do the manually later.

#### Blank filtering

The first method is *blank filtering*. This module filters out the signals that have higher abundance in non-biological samples (e.g. blank) compared to biological samples.

If you don't want to perform the blank filtering. Set the following to *false* and go to the next step of the workflow (no need to set the parameters for this step!):

    blank_filter_pos
    blank_filter_neg

Which method to use for summarizing blank and biological sample for comparisons. For example if Max is selected, a signal will be remove if it Maximun abundance in the blank samples is higher than maximum abundance in biological samples (one of max, mean, median):

    method_blankfilter_pos_xcms="max"
    method_blankfilter_neg_xcms="max"

This must indicate the class of blank samples extactly as you refer to them in your phenotype file. IMPORTANT: this class should be identical for all the blank samples:

    blank_blankfilter_pos_xcms
    blank_blankfilter_neg_xcms

If ture, the (average,median,max) abundance of blank samples will be compared against all other samples. For false see the next parameter:

    rest_blankfilter_pos_xcms="true"
    rest_blankfilter_neg_xcms="true"

If the previous parameter is false, a sample class can be specified so that blank abundance will be compared against this sample class:

    sample_blankfilter_pos_xcms
    sample_blankfilter_neg_xcms

#### Dilution filtering

his module filters out the signals that do not correlate with a specified dilution trend.
If you don't want to perform the dilution filtering. Set the following to *false* and go to the next step of the workflow (no need to set the parameters for this step!):

    dilution_filter_pos
    dilution_filter_neg

This series will used for calculation of correlation. For example if this parameter is set like 1,2,3 and the class of dilution trends is set as D1,D2,D3 the following the pairs will be used for calculating the correlation: (D1,1),(D2,2),(D3,3):

    corto_dilutionfilter_pos_xcms="0.5,1,2,4"
    corto_dilutionfilter_neg_xcms="0.5,1,2,4"

This must indicate the class of dilution trend samples. IMPORTANT: the samples are correlated to the exact order of the sequence as set here:

    dilution_dilutionfilter_pos_xcms="D1,D2,D3,D4"
    dilution_dilutionfilter_neg_xcms="D1,D2,D3,D4"

Signals with correlation p-value higher than this will be removed:

    pvalue_dilutionfilter_pos_xcms="0.05"
    pvalue_dilutionfilter_neg_xcms="0.05"

ignals with lower correlation than this will be removed:

    corcut_dilutionfilter_pos_xcms="-1"
    corcut_dilutionfilter_neg_xcms="-1"

Should the algorithm use the correlation as it is (negative and positive) or absolute correlation (either true or false):

    abs_dilutionfilter_pos_xcms="false"
    abs_dilutionfilter_neg_xcms="false"

#### CV filtering

This module filters out the signals that do not show desired coefficient of variation.
If you don't want to perform the CV filtering. Set the following to *false* and go to the next step of the workflow (no need to set the parameters for this step!):

    cv_filter_pos
    cv_filter_neg

This must indicate the class of QC samples:

    qc_cvfilter_pos_xcms="QC"
    qc_cvfilter_neg_xcms="QC"

Signals with CVs higher than this will be removed:

    cvcut_cvfilter_pos_xcms="0.3"
    cvcut_cvfilter_neg_xcms="0.3"

### Annotation (CAMERA)

MetaboIGNITER performs annotation using CAMERA package in R. We first do FWHM grouping, then perform adduct detection followed by isotpe finding. The specific details of this can be found on [CAMERA webpage](http://bioconductor.org/packages/release/bioc/html/CAMERA.html).

#### CAMERA Group FWHM

Group peaks of a xsAnnotate object according to there retention time into pseudospectra-groups. Uses the peak FWHMs as grouping borders. Returns xsAnnotate object with pseudospectra informations.
The multiplier of the standard deviation:

    sigma_group_pos_camera="8"
    sigma_group_neg_camera="8"

Percentage of the width of the FWHM:

    perfwhm_group_pos_camera="0.6"
    perfwhm_group_neg_camera="0.6"

Intensity values for ordering. Allowed values are into, maxo, intb"

    intval_group_pos_camera="maxo"
    intval_group_neg_camera="maxo"

#### CAMERA Find Adducts

Annotate adducts (and fragments) for a xsAnnotate object. Returns a xsAnnotate object with annotated pseudospectra:

The ppm error for the search:

    ppm_findaddcuts_pos_camera="10"
    ppm_findaddcuts_pos_camera="10"

#### CAMERA Find Isotopes

Annotate isotope peaks for a xsAnnotate object. Returns a xsAnnotate object with annotated isotopes.

Max. number of the isotope charge:

    maxcharge_findisotopes_pos_camera="1"
    maxcharge_findisotopes_neg_camera="1"

### Output the results

This module converts the quantification and identification results to tabular files for multivariate and univariate data analysis. If you are only doing the identification, you can set the parameters and this stage and run the workflow. If you would like to do identification, you can still set the parameters of this stage and but also don't run the workflow, continue with this guide to set the parameters for identification and then run the workflow. This stage will output three tabular files: peak table containing abundances, sample metadata, and  variable data containing identification (if identification is selected).

m/z tolerance for matching identification results to quantification (ppm). **Only if you have selected to do identification**:

    ppm_output_pos_camera="10"
    ppm_output_neg_camera="10"

Retention time tolerance for matching identification results to quantification (sec). **Only if you have selected to do identification**:

    rt_output_pos_camera="5"
    rt_output_neg_camera="5"

Metabolites quantification profile often result in a number signals. One some of this signal can be identified. If this parameter is set, the unidentified signals will be imputed by the identification based on CAMERA grouping. **Only if you have selected to do identification**:

    impute_output_pos_camera="true"
    impute_output_neg_camera="true"

The phenotype file must have a column showing which samples to keep and which to remove. Enter name of that column.

    type_column_output_pos_camera="Class"
    type_column_output_neg_camera="Class"

Based on information in "type_column_output_pos/neg_camera", enter which sample type should be kept:

    selected_type_output_pos_camera="Sample"
    selected_type_output_neg_camera="Sample"

If true. The samples will be renamed based on information provide in column "rename_col_output_pos/neg_camera":

    rename_output_pos_camera="true"
    rename_output_neg_camera="true"

Enter name of the column showing the new file name of the samples:

    rename_col_output_pos_camera="rename"
    rename_col_output_neg_camera="rename"

If true. Only identified metabolites will be reported. **Only if you have selected to do identification**:

    only_report_with_id_output_pos_camera="false"
    only_report_with_id_output_neg_camera="false"

If yes. The technical replicates (duplicate injections) will be averaged (median). This information should be provide in an additional column in the phenotype information:

    combine_replicate_output_pos_camera="false"
    combine_replicate_output_neg_camera="false"

Enter the column name indicating technical replicate in the phenotype file. See the example in the phenotype design:

    combine_replicate_column_output_pos_camera="rep"
    combine_replicate_column_output_neg_camera="rep"

Do you want to perform log2 transformation ?:

    log_output_pos_camera="true"
    log_output_neg_camera="true"

How much of non-missing value should be present for each feature:

    sample_coverage_output_pos_camera="50"
    sample_coverage_output_neg_camera="50"

Do you want to apply coverage globally across all the runs or per group? For applying globally write global otherwise write name of the column showing the grouping:

    sample_coverage_method_output_pos_camera="global"
    sample_coverage_method_output_neg_camera="global"

Number of cores for performing mapping of IDs to features. **Only if you have selected to do identification**:

    ncore_output_pos_camera="1"
    ncore_output_neg_camera="1"

Normalize the data using this method, select the number for each normalization (1:Cyclic Loess, 2:Median, 3:Reference, 4:Regression), set to *"NA"* if you don't want to perform any normalization:

    normalize_output_pos_camera="1"
    normalize_output_neg_camera="1"

## Identification Specific Parameters

Currently, MetaboIGNITER supports two types of identification. One is based on in-silico (database) approach and the other is based on internal library.

If you would like to perform identification, please set the following parameters to true:

    perform_identification=true

Please also remember that we only perform identification for the ionization modes that you have quantification data for.

### 2) In-silico identification in MetaboIGNITER

MetaboIGNITER has a specific design for performing identification. After performing quantification and annotation of MS1 data, the results will be fed into the identification sub-pipeline this part of the workflow, will first extract the MS2 information from the identification mzML files and map them to the quantification data. If a parent ion was matched against a feature that was successfully annotated, we then estimate the neutral mass for that parent ion. By doing that, the number of searches needed for identification will significantly decrease. The rest of the ions that were matched against features without annotation will be searched using different adduct rules and charges. The resulting scores from metabolite spectrum matches will be transformed into posterior error probability and re-matched to the features at the later step.

#### Organize you mzML files

Before proceeding with setting the parameters for identification you need to complete the mzMl folder structure.

This basically follows the same design as the MS1 data preparation. You need to create separate directories for mzML files that contain MS2 information. So if you have MS2 files both positive and negative mode, you need to create two more folders. For example, mzML_NEG_ID and mzML_POS_ID containing, negative and positive MS2 data respectively. The following file tree shows an example of such structure. In this example, we have both positive and negative ionization. The files have been placed in different folders depending on the ionization and pre-processing needed.

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

When you are ready with the folder structure you will need to set the parameters needed:
A glob path to a folder containing mzML files used for doing identification (MS2 data in positive ionization method)

    id_mzml_files_pos =""

A glob path to a folder containing mzML files used for doing identification (MS2 data in negative ionization method)

    id_mzml_files_neg=""

for example:

        quant_mzml_files_pos ="/User/XXX/myfiles/id_mzml_files_pos/*mzML"

If you quantification files also includes MS2 data, you can set *id_mzml_files_pos* and *id_mzml_files_neg* to the path of MS1 data (of course to respective ionization modes)

#### Select your search engine

Currently, MetaboIGNITER supports three search engines, [MetFrag](https://ipb-halle.github.io/MetFrag/), [CSI:FingerID](https://bio.informatik.uni-jena.de/software/sirius/), and [CFM-ID](https://cfmid.wishartlab.com/) for performing identification. These engines share some global parameters but also each of these will need specific set of parameters. The user can select multiple search engines to do the identification. In the case of multiple search engines, the workflow will have multiple final output, one for each search engine and ionization. Please set the parameter to true for the desired search engine:

    perform_identification_metfrag=false // Should Metfrag be used for doing identification?
    perform_identification_csifingerid=false // Should CSI:FingerID be used for doing identification?
    perform_identification_cfmid=false // Should CFM-ID be used for doing identification?

#### global parameters (Mapping MS2 to MS1)

This module is used to map MS/MS spectra to annotated CAMERA features. The mapping is performed based on retention time and m/z values of the annotated features.

The ppm error used for the mapping:

    ppm_mapmsmstocamera_pos_msnbase="10"
    ppm_mapmsmstocamera_neg_msnbase="10"

The retention time error (in seconds) used for the mapping:

    rt_mapmsmstocamera_pos_msnbase="5"
    rt_mapmsmstocamera_neg_msnbase="5"

#### global parameters (Producing search files)

This module is used to generate search parameters with mapped MS/MS spectra retrieved from the mzML files. These parameters will be send to all the search engines. You will then have the possibility to set the serach engine sepcific parameters. The only exception is *database_msmstoparam_pos/neg_msnbase* that is only applicable in **MetFrag**.

The ppm error for the precursor mass to search candidates:

    precursorppm_msmstoparam_pos_msnbase="10"
    precursorppm_msmstoparam_neg_msnbase="10"

The ppm error to assign fragments to fragment peaks:

    fragmentppm_msmstoparam_pos_msnbase="20"
    fragmentppm_msmstoparam_neg_msnbase="20"

Absolute mass error to assign fragments to fragment peaks:

    fragmentabs_msmstoparam_pos_msnbase="0.05"
    fragmentabs_msmstoparam_neg_msnbase="0.05"

Available databases are: KEGG, PubChem, MetChem (local database which needs to be set up beforehand). In addition, LocalCSV can be used which uses a csv file for searching. Such a csv file can be downloaded from [here](https://msbi.ipb-halle.de/~cruttkie/databases/).
If LocalCSV is selected, a specific file needs to be provided. The format of this file is very strict. See the database parameter.

    database_msmstoparam_pos_msnbase="LocalCSV"
    database_msmstoparam_neg_msnbase="LocalCSV"

Adduct ruleset to be used:
primary - contains most common adduct types ([M-H]-, [M-2H+Na]-, [M-2H+K]-, [M+Cl]-, [M+H]+, [M+Na]+, [M+K]+, [M+NH4]+)
extended - next to primary also additional adduct types

    adductRules_msmstoparam_pos_msnbase="primary"
    adductRules_msmstoparam_neg_msnbase="primary"

Filter spectra by a minimum number of fragment peaks:

    minPeaks_msmstoparam_pos_msnbase="2"
    minPeaks_msmstoparam_neg_msnbase="2"

#### MetFrag parameter

We only need one parameter if the global parameters have been set properly. This is the database file. An example of such database can be found [here](https://github.com/MetaboIGNITER/test-datasets/blob/d2bc5c484fa292af686ac197f35955ba73083934/hmdb_2017-07-23.csv). You can either use the example for HMDB (2017) or generate your own using [MetChem](https://github.com/c-ruttkies/container-metchemdata). Please contact us if you need to generate this file.

Absolute path to the generated database file:

    database_csv_files_pos_metfrag=""
    database_csv_files_neg_metfrag=""

#### CSIFingerID parameters

Please select the database to be used for CSIFingerID. **IMPORTANT: we don't support database file for csi:fingerid. You will need to provide what database to use here, the rest of the parameters will be taken from there parameter file**

Database (this will overwrite the corresponding parameter in the input file). CSI:FingerID does not have LocalCSV. So if you set this in the previous step, change this to your desired database (**one of**: all, chebi, kegg, bio, natural products, pubmed, hmdb, biocyc, hsdb, knapsack, biological, zinc bio, gnps, pubchem, mesh, maconda):

    database_csifingerid_pos_csifingerid="hmdb"
    database_csifingerid_neg_csifingerid="hmdb"

#### CFM-ID parameters

You need to specify the database for CFM-ID. The rest of the parameters will be taken from the global parameters. Please see MetFrag parameter on how to construct the database.
This database must at least contain the following columns: id of the molecules, smile of the molecules, mass of the molecules, name of the molecules and InChI of the molecules. The best practice would be to use [MetChem](https://github.com/c-ruttkies/container-metchemdata) to construct the database.

Absolute path to a csv file containing your database:

    database_csv_files_pos_cfmid=""
    database_csv_files_neg_cfmid=""

Name of the column in the database file for id of the molecules:

    candidate_id_identification_pos_cfmid="Identifier"
    candidate_id_identification_neg_cfmid="Identifier"

Name of the column in the database file for smile of the molecules:

    candidate_inchi_smiles_identification_pos_cfmid="SMILES"
    candidate_inchi_smiles_identification_neg_cfmid="SMILES"

Name of the column in the database file for mass of the molecules:

    candidate_mass_identification_pos_cfmid="MonoisotopicMass"
    candidate_mass_identification_neg_cfmid="MonoisotopicMass"

Name of the column in the database file for name of the molecules:

    database_name_column_identification_pos_cfmid="Name"
    database_name_column_identification_neg_cfmid="Name"

Name of the column in the database file for InChI of the molecules:

    database_inchI_column_identification_pos_cfmid="InChI"
    database_inchI_column_identification_neg_cfmid="InChI"

### 3) Characterize your own library

This part of the workflow is used to create and characterize in-house library. This is how it works: we assume that the library consists of one or more mzML files, each containing a number of compounds. A possible scenario is when the users have several standard metabolites that can have overlapping masses with unknown retention times. The standards with overlapping masses can be run separately using MS, resulting in different runs. MetaboIGNITER will help you to characterize this type of internal libraries. You will need to construct the Characterization file (see below) that shows which standards are present in which mzML file. The workflow will then do mass trace detection, MS2 extraction and mapping of parent ions to mass traces. Doing so will result in finding the retention time and empirical m/z of each standard. This will then be used to create identification parameters and search the biological MS2 files.

Set the library parameter to true if you would like to perform library search:

    perform_identification_internal_library=true  

#### Create your folder structure

The directory structure will be similar to those describe above. You will need to place positive and negative files in different folders. In the following example, we provide the complete folder structure used for doing quantification, in-silico and library identification. In this example, we have plcaed the library files in mzML_NEG_Lib and mzML_POS_Lib folders.

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

Now set the folder paths to the library files.
a glob path to a folder containing library mzML files used for doing adduct calculation. If you don't have separate quantification data for the library, set this to path of the library file:

    quant_library_mzml_files_pos=""
    quant_library_mzml_files_neg=""

a glob path to a folder containing mzML files (for library) used for doing identification (as described above):

    id_library_mzml_files_pos=""
    id_library_mzml_files_neg=""

For example, considering the structure above, we can set *quant_library_mzml_files_pos* and *id_library_mzml_files_pos* to "mydata/mzML_POS_Lib/*.mzML" and *quant_library_mzml_files_neg* and *id_library_mzml_files_neg* to "mydata/mzML_NEG_Lib/*.mzML".

#### Create your library description files

You need to fix for each of the ionization mode, a separate library description file. An example of such file is provided [here](https://github.com/MetaboIGNITER/test-datasets/blob/d2bc5c484fa292af686ac197f35955ba73083934/library_charac_pos.csv). This file must contain the following information in a comma separate file:

- Name of the mzML file containing the compound

- ID of the compound e.g. HMDB ID

- Name of the compound

- Theoretical m/z of the compound

Here is an example of the expected table format:

| raw.File| HMDB.ID      | Name               | m.z           |
|--|--|--|--|
| a1.mzML | HMDB0000044  | Ascorbic acid      | 177.032087988 |
| a1.mzML | HMDB0000001  | 1-Methylhistidine  | 170.085126611 |
| a2.mzML | HMDB0000002  | 1,3-Diaminopropane | 75.08439833   |

Absolute path to a csv file containing description of the library:

    library_description_pos=""
    library_description_neg=""

Please set the following parameters based on the your library description files

Column name showing name of the raw file in the library file e.g. "raw.File" in the table above:

    raw_file_name_preparelibrary_pos_msnbase=""
    raw_file_name_preparelibrary_neg_msnbase=""

Column name showing ID of the compound in the library file e.g. "HMDB.ID" in the table above:

    compund_id_preparelibrary_pos_msnbase=""
    compund_id_preparelibrary_neg_msnbase=""

Column name showing name of the compound in the library file e.g. "Name" in the table above:

    compound_name_preparelibrary_pos_msnbase=""
    compound_name_preparelibrary_neg_msnbase=""

Column name showing m/z of the compound in the library file e.g. "m.z" in the table above:

    mz_col_preparelibrary_pos_msnbase="mz"
    mz_col_preparelibrary_neg_msnbase="mz"

The function can use feature range (f), centroid (c), and parent m/z (Parent) information in order to map a compound to MS1 and MS2 information:

    which_mz_preparelibrary_pos_msnbase="f"
    which_mz_preparelibrary_neg_msnbase="f"

Set the relative mass deviation (ppm) between the experimental and theoretical masses of metabolites:

    ppm_create_library_pos_msnbase=10
    ppm_create_library_neg_msnbase=10

Number of cores for mapping the features:

    ncore_searchengine_library_pos_msnbase=1
    ncore_searchengine_library_neg_msnbase=1

#### Quantification of library

Please set the parameters needed for finding the mass traces for the library. These more or less follow the same design as the quantification of the biological samples. Please see the description of OpenMS and XCMS above. In brief, if you have selected doing centroiding, you need to change OpenMS PeakPickerHiRes parameter file for the library.

Please edit the following files (separate for positive and negative):

    assets/openms/openms_peak_picker_lib_ini_pos.ini
    assets/openms/openms_peak_picker_lib_ini_neg.ini

you will have to set whether you do the quantification using either OpenMS (set to openms) or XCMS (set to xcms) (**for library**):

    quantification_openms_xcms_library_pos="xcms"
    quantification_openms_xcms_library_neg="xcms"

If OpenMS selected, please edit the following files for doing mass trace detection for library:

    assets/openms/openms_feature_finder_metabo_lib_ini_pos.ini
    assets/openms/openms_feature_finder_metabo_lib_ini_neg.ini

If you have selected to do quantification using XCMS, you need to tune the following parameters (See the corresponding sections in the quantification above):

#### Paramaters for XCMS (library)

Masstrance deviation in ppm:

    masstrace_ppm_library_pos_xcms=10
    masstrace_ppm_library_neg_xcms=10

Lower width of peaks:

    peakwidthlow_quant_library_pos_xcms=5
    peakwidthlow_quant_library_neg_xcms=5

Highest width of peaks:

    peakwidthhigh_quant_library_pos_xcms=30
    peakwidthhigh_quant_library_neg_xcms=30

Level of noise:

    noise_quant_library_pos_xcms=1000
    noise_quant_library_neg_xcms=1000

#### CAMERA parameters group FWHM (library)

Sigma value for grouping the peaks across chromatogram:

    sigma_group_library_pos_camera="8"
    sigma_group_library_neg_camera="8"

Full width at half maximum for finding overlaping peaks:

    perfwhm_group_library_pos_camera="0.6"
    perfwhm_group_library_neg_camera="0.6"

which intensity value to use:

    intval_group_library_pos_camera="maxo"
    intval_group_library_neg_camera="maxo"

#### CAMERA find adduct library

ppm deviation between theoritical adduct mass and the experimental one:

    ppm_findaddcuts_library_pos_camera="10"
    ppm_findaddcuts_library_neg_camera="10"

#### Camera find isotopes library

Number of changes to consider (most often 1 is enough):

    maxcharge_findisotopes_library_pos_camera="1"
    maxcharge_findisotopes_library_neg_camera="1"

#### Mapping MS2 to features (within the library)

ppm deviation when mapping MS2 parent ion to a mass trace:

    ppm_mapmsmstocamera_library_pos_msnbase="10"
    ppm_mapmsmstocamera_library_neg_msnbase="10"

rt difference (in second) for mapping MS2 parent ion to a mass trace (the mass trace is a range, star and end of the trace):

    rt_mapmsmstocamera_library_pos_msnbase="5"
    rt_mapmsmstocamera_library_neg_msnbase="5"

if you already have your library characterize e.g the results of *process_collect_library_pos_msnbase* and *process_collect_library_neg_msnbase*. You can set the following parameters to true and also set the absolute paths to the the characterization file:

If you have already characterized your library, set this to true and specify the path for library_charactrization_file_pos/neg:

    library_charactrized_pos=false
    library_charactrized_neg=false

Absolute path to the file from characterized library:

    library_charactrization_file_pos=""
    library_charactrization_file_neg=""

Using this option will prevent re-characterization of the library.

# Out put of the workflow

Each process in the workflow will create a folder with the following pattern:
(output directory)/process_(name of the process)_(if it is library or not)_(ionization mode)_(name of the process)

The most import outputs are the results of process_output that contains three tabular files, one for the peak table, one for the variable information (including identification etc) and metadata information.
