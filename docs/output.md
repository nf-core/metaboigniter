# nf-core/metaboigniter: Output

## Introduction

This document describes the output produced by the pipeline.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

## Pipeline overview

The pipeline consists of various steps each will produce multiple files types.

- [nf-core/metaboigniter: Output](#nf-coremetaboigniter-output)
  - [Introduction](#introduction)
  - [Pipeline overview](#pipeline-overview)
  - [Preprocessing](#preprocessing)
    - [Centroiding](#centroiding)
  - [Quantification](#quantification)
    - [Quantification](#quantification-1)
    - [Requantification](#requantification)
    - [Annotation](#annotation)
  - [Alignment and linking](#alignment-and-linking)
    - [Alignment](#alignment)
    - [Linking](#linking)
  - [Expression output](#expression-output)
  - [Pipeline information](#pipeline-information)

## Preprocessing

### Centroiding

<details markdown="1">
<summary>Output files</summary>

- `centroided/<sample>/output/`
  - `*.mzML`: Centroided `mzML` files.

</details>

## Quantification

### Quantification

<details markdown="1">
<summary>Output files</summary>

- `quantification/<sample>/output/`
  - `*.featureXML`: Mass traces in `featureXML` format.

</details>

### Requantification

With `--requantification`, missing values of the linked consensus map are filled by targeted extraction. The consensus map from [Linking](#linking) stays authoritative and unchanged: requantification never relinks it, and every accepted fill is added to exactly the consensus feature that requested it.

<details markdown="1">
<summary>Output files</summary>

- `requantification/`
  - `Linked_data_gapfilled.consensusXML`: copy of the linked consensus map with one feature handle added for every accepted fill. Consensus IDs, m/z, RT, intensities, annotations and all original handles are identical to `linker/output/Linked_data.consensusXML`.
- `TABLE_OUTPUT/`
  - `output_quantification_Linked_data_gapfilled.tsv`: gap-filled matrix, see [Expression output](#expression-output).
  - `output_requantification_mask_Linked_data.tsv`: one row per consensus feature in consensus order (`consensus_index`, `consensus_uid`, which equals `id` in the matrices) and one column per sample, named like the matrix columns. Each cell is `observed` (original detection), `requantified` (accepted fill), `missing_no_candidate` (FeatureFinderMetaboIdent reported no feature for the target), `missing_existing_signal_overlap` (rejected because an original feature of the same sample covers the signal) or `missing_failed_qc` (rejected by another quality check).
  - `output_requantification_provenance_Linked_data.tsv`: one row per requested sample and target, sorted by sample and `consensus_index`. It gives the target (`target_mz`, `target_rt` = centre of the window, `window_min`, `window_max`, `n_observed`, `charge`), the outcome (`status` = `accepted`, `rejected` or `no_candidate`; `rejection_reason` = the first failing check; `failed_checks` = all failing checks), the inserted handle ID (`fill_feature_uid`) and the FeatureFinderMetaboIdent evidence: `candidate_rt` (FeatureFinderMetaboIdent's feature RT, which is the RT of the inserted handle), `candidate_apex_rt` (`peak_apex_position`, the apex of the extracted-ion chromatogram that the quality checks use), `rt_error_s` (apex minus target RT), `ffmi_masserror_ppm` (intensity-weighted centroid of the peaks within ±0.025 Th of the target in the apex MS1 spectrum versus the theoretical m/z; `-1` means no peak), `model_status`, `model_area`, `raw_intensity` (summed extracted-ion chromatogram, not exported), `exported_intensity` (`model_area` of accepted fills), `left_width` and `right_width` (integration interval), `apex_signal_fraction`, `peak_apex_int` and `overlapping_original_uids`. There is no measured m/z column, because the m/z that FeatureFinderMetaboIdent reports is the theoretical target m/z.
  - `output_requantification_summary_Linked_data.tsv`: one row per sample and a final `all` row with the number of consensus rows, observed values, requested targets, recovered candidates, accepted, rejected and `no_candidate` targets, one column per rejection reason, and the values still missing afterwards.
- With `--save_intermeds` only:
  - `requantification/targets/`: per-sample FeatureFinderMetaboIdent libraries (`*.library.tsv`), targets (`*.targets.tsv`), compact tables of the original features (`*.originals.tsv`) and the resolved map index of each sample (`*.sample_map.tsv`). A sample without detected features has an `*.originals.tsv` with only the header line, `n_features` 0 in its `*.sample_map.tsv`, and every consensus feature as a target.
  - `requantification/candidates/`: FeatureFinderMetaboIdent output (`*.featureXML`) and logs (`*.ffmi.log`) per sample.
  - `requantification/qc/`: per-sample candidate tables (`*.candidates.tsv`) and accepted fills (`*.fills.tsv`).

</details>

### Annotation

<details markdown="1">
<summary>Output files</summary>

- `annotation/<sample>/output/`
  - `*.featureXML`: Mass traces in `featureXML` format including adduct information.

</details>

## Alignment and linking

### Alignment

<details markdown="1">
<summary>Output files</summary>

- `alignment/output/` (`--ms2_collection_model paired`)
  - `*.featureXML`: Time aligned mass traces in `featureXML` format.
  - `*.trafoXML`: Retention time transformations of the alignment.
- `alignment_mzml/output/` (`--ms2_collection_model separate`)
  - `*.mzML`, `*.trafoXML`: Time aligned `mzML` files of all inputs and their transformations.
- `alignment_mzml/<sample>/output/` (`--ms2_collection_model paired`)
  - `*.mzML`: Time aligned `mzML` files.

</details>

### Linking

<details markdown="1">
<summary>Output files</summary>

- `linker/output/`
  - `*.consensusXML`: Linked consensus traces in `consensusXML` format.

</details>

## Intermediate files

With `--save_intermeds`, the outputs of the other steps are saved as well, each under `<PROCESS_NAME>/output/` (for example `PYOPENMS_MSMAPPING/output/`). Steps whose module writes into its own `output/` folder keep it, so their files are one level deeper, for example `PYOPENMS_C13DETECTION/output/output/`. Requantification intermediates go to `requantification/targets/`, `requantification/candidates/` and `requantification/qc/` instead (see [Requantification](#requantification)).

## Expression output

The most important output are TSV files produced by quantification and identification step.

These can be found under `TABLE_OUTPUT`.

Depending on the pipeline parameters, it can contain one, and up to four different files.

- the file starting with `output_sirius_` contains the formula identification by SIRIUS
- the file starting with `output_fingerid_` contains the structural identification by FINGERID
- the file starting with `output_ms2query_` contains the analogue identification by MS2Query
- the file starting with `output_quantification_` contains quantification information
- with `--requantification`, the file `output_quantification_Linked_data_gapfilled.tsv` contains the gap-filled quantification matrix, and the `output_requantification_` files describe the gap filling (see [Requantification](#requantification))

All files are TSV (tab separate files) and have a column called "id". This ID can be used to match rows across different files.

In the `output_quantification_` file, each sample has its own intensity column. A missing value is written as `0`: when a consensus feature was not detected in a sample, its intensity in that sample's column is `0`, not empty or `NA`. Treat these zeros as missing values, not as measured intensities, before imputation, normalization or statistical testing.

With `--requantification`, `output_quantification_Linked_data.tsv` is the observed matrix: it is produced exactly as without requantification and contains no fills. `output_quantification_Linked_data_gapfilled.tsv` has the same rows, columns and IDs, with the accepted fills added; every other value is identical. The two kinds of values are different estimators: original values are FeatureFinderMetabo areas of the smoothed monoisotopic mass trace within its full width at half maximum, fills are FeatureFinderMetaboIdent Gaussian model areas. For a Gaussian peak the model area is expected to be about 1.31 times the FeatureFinderMetabo area (1/erf(sqrt(ln 2))); on the test data the observed median ratio was 1.30 (5-95 %: 1.07-3.4). No global intensity correction is applied, so the gap-filled matrix is not scale-equivalent across observed and filled cells. Missing cells are still written as `0`; use the requantification mask to tell observed, filled and missing values apart. Identification tables can be joined to both matrices by `id`.

## Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.

</details>

[Nextflow](https://docs.seqera.io/platform-cloud/reports/overview) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
