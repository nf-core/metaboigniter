# nf-core/metaboigniter: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v2.1.0](https://github.com/nf-core/metaboigniter/releases/tag/2.1.0) - 2026-10-16

### `Fixed`

- Intermediate outputs of `PYOPENMS_C13DETECTION`, `PYOPENMS_EXTRACTFEATUREMZ`, `PYOPENMS_SPLITFEATUREXML` and `PYOPENMS_GENERATESEARCHPARAMSUNMAPPED` are only published with `--save_intermeds`; identification runs no longer copy every input mzML into `pyopenms/`
- Intermediate results are published with `--publish_dir_mode` (default `copy`) instead of as symlinks into the work directory, and without the per-task `versions.yml` files
- [#95](https://github.com/nf-core/metaboigniter/issues/95) MS2 input files without an mzML index are indexed with OpenMS `FileConverter` before identification instead of failing in `PYOPENMS_GENERATESEARCHPARAMS`
- [#103](https://github.com/nf-core/metaboigniter/issues/103) `PYOPENMS_MSMAPPING` maps MS2 precursors through an m/z index and reads spectra without peak data; same output, about 10x faster on the six-file test set and no longer quadratic in features x spectra
- [#112](https://github.com/nf-core/metaboigniter/issues/112) Use logical `||` instead of bitwise `|` when filtering inputs by MS level
- [#113](https://github.com/nf-core/metaboigniter/issues/113) Sample intensity columns of the exported tables follow the consensusXML map order instead of a random order that changed between runs
- [#127](https://github.com/nf-core/metaboigniter/pull/127) SIRIUS and CSI:FingerID tables no longer contain a repeated header line as a data row for every compound after the first
- [#130](https://github.com/nf-core/metaboigniter/issues/130) Requantification libraries use the proton mass rather than the hydrogen-atom mass when converting m/z to neutral mass
- [#131](https://github.com/nf-core/metaboigniter/issues/131) Every requantification target gets an explicit RT window, centred on the midpoint of the RT range of the consensus feature's handles and `span + 2 x --requantification_rt_margin` wide, instead of FeatureFinderMetaboIdent's fixed default window
- [#133](https://github.com/nf-core/metaboigniter/issues/133) Requantification no longer relinks the samples. Targets are the consensus features without a handle from a sample (matched by feature ID), and every accepted fill is inserted into exactly the consensus feature that requested it, so original detections, consensus IDs, positions, intensities and annotations are unchanged
- Requantification no longer fails when FeatureFinderMetaboIdent finds no candidate at all for a sample's targets after a valid extraction. FeatureFinderMetaboIdent 3.6.0 reports this with exit status 8, which it also uses for other errors, so exit status 8 becomes an empty result only when the log shows exactly this zero-candidate outcome; exit status 8 with `Could not find any points for chromatogram` and every other error still stop the pipeline, so that extraction or configuration failures do not become silent missing values
- Requantification no longer stops when a sample has no detected features. Its consensus column is identified by the feature map's unique ID and the MS run path recorded by the linker, and every consensus feature becomes a target for it. Like any sample, it still stops the pipeline at FeatureFinderMetaboIdent when the extraction itself fails (for example when its MS1 spectra are empty; see [Requantification](docs/usage.md#requantification))

### `Added`

- Hard quality control of requantified values: candidates are rejected when their metadata are malformed, an original feature of the same sample covers the signal, there is no MS1 peak at the apex, the elution model is not valid, too few scans around the apex have signal, or the signal is shared with another candidate. Rejected targets stay missing
- `output_quantification_Linked_data_gapfilled.tsv` (gap-filled matrix), `requantification/Linked_data_gapfilled.consensusXML`, and the requantification mask, provenance (one row per requested sample and target) and summary tables in `TABLE_OUTPUT/`
- `--requantification_rt_margin` (default 30 s) and `--requantification_min_apex_signal_fraction` (default 0.3; calibrated on the positive-mode nf-core test data only, see the known limitations in the usage documentation)

### `Changed`

- With `--requantification`, adduct and isotope annotation now run before linking, as without requantification, and `output_quantification_Linked_data.tsv` is the observed matrix without fills; the gap-filled values are in `output_quantification_Linked_data_gapfilled.tsv`. Identification uses the observed consensus map, so MS2 spectra are never mapped onto fills
- `--model_no_imputation_featurefindermetaboident_openms` now defaults to `true`: failed elution-model fits get intensity 0 instead of a regression estimate. These values were never used, and the imputation regression can fail on degenerate inputs
- Requantification intermediates (libraries, FeatureFinderMetaboIdent output of about 160 MB per sample, candidate tables) are only published with `--save_intermeds`
- The default `--detect_peak_width_featurefindermetaboident_openms 60` is unchanged. On the test data it leaves about 28 % of truly present features without a candidate; retuning is deferred
- OpenMS and pyOpenMS updated from 3.0.0 / 2.9.1 to 3.6.0. Results change slightly because of upstream fixes in feature finding and linking (OpenMS [#10157](https://github.com/OpenMS/OpenMS/pull/10157), [#10225](https://github.com/OpenMS/OpenMS/pull/10225)). On the test data with identification and parallel linking, 99.5 % of consensus features are unchanged with identical intensities, consensus features with an `[M+H]+` adduct annotation go from 7,821 to 9,654, and requantified intensities move by a median of 0.4 %.
- `FeatureFinderMetaboIdent` always receives `-EMGScoring:init_mom`, because OpenMS 3.6 changed its default to `true`; the pipeline default stays `false`
- Template update to nf-core/tools 4.1.0: `nf-validation` replaced by `nf-schema`, `check_max()`/`--max_*` replaced by `process.resourceLimits`, CI moved to nf-test, minimum Nextflow version raised to 25.10.4
- The `arm` profile is replaced by the template's `arm64` (Wave-built arm64 containers) and `emulate_amd64` profiles
- `--mgf_splitmgf_pyopenms` is no longer hidden, and a warning is logged when `--sirius_split` is set without it, because `--sirius_split` alone does not split SIRIUS
- Parameter validation is stricter: OpenMS parameters reject values outside the ranges the OpenMS tools accept, tolerances and timeouts reject negative values, candidate, iteration and split counts must be at least 1, and `msfile` in the samplesheet must end in `.mzML` ([#109](https://github.com/nf-core/metaboigniter/issues/109))

### `Removed`

- Requantification relinking (`PYOPENMS_SPLIT`, `PYOPENMS_RELOADMAPS`, `PYOPENMS_MERGE` and the second annotation and linking passes) with the `split.py`, `reloadmaps.py` and `merge.py` scripts
- `requantification/output/` and `requantification_merged/` output folders
- Unused nf-core `fastqc` module; FastQC is declared as a skipped template feature
- Unused local modules (`MS2QUERY_EXPORT`, `MS2QUERY_MODELFULLTRAIN`, `OPENMS_GNPSEXPORT`, `OPENMS_IDMAPPER`, `OPENMS_IDMAPPERCONSENSUS`, `OPENMS_SIRIUSPARAMS`, `PYOPENMS_EXTRACTMAPPING`, `PYOPENMS_ISOMAPPING`, `PYOPENMS_REMOVEDUP`) and the `bin/` scripts only they used
- `--hook_url`, `--max_cpus`, `--max_memory`, `--max_time` and the nf-validation `--validation*` parameters (dropped by the nf-core template)

## [v2.0.1](https://github.com/nf-core/metaboigniter/releases/tag/2.0.1) - 2024-04-12

- Problems with missing output data after peak picking have been resolved
- The issue with long file names has been fixed
- Charge state handling in negative mode has been improved
- C13 detection is now only applied if identification flag is set
- nf-validation version has been pinned
- Default change: negative adducts have been changed to H-1:-:0.8 H-3O-1:-:0.2
- SIRIUS has been updated to 5.8.6
- MS2QUERY has been updated to 1.2.3
- New parameter `ignore_msms_mapping_charge_pyopenms` has been added to control the MS2 mapping if the charges are inconsistent between the consensus elements and spectra

## [v2.0.0](https://github.com/nf-core/metaboigniter/releases/tag/2.0.0) - 2023-12-18

Initial release of DSL 2 version nf-core/metaboigniter including major modifications.
The support for the previous parameters in version 1.0.1 has been deprecated.

### `Added`

- Inputs are given using a CSV file
- mapAlignerPoseClustering
- featureLinkerUnlabeledkd
- MetaboliteAdductDecharger
- MS2Query

### `Fixed`

- SIRIUS APIs have been fixed

### `Deprecated`

- XCMS
- IPO
- MetFrag
- CFMID
- IPO
- Internal library search

## [v1.0.1](https://github.com/nf-core/metaboigniter/releases/tag/1.0.1) - 2021-05-11

A bug in running using AWS has been fixed.
Also the template has been updated to nf-core/tools v1.14.

## [v1.0.0](https://github.com/nf-core/metaboigniter/releases/tag/1.0.0) - 2021-05-08

Initial release of nf-core/metaboigniter, created with the [nf-core](http://nf-co.re/) template.

This release is the initial version of metaboIGNITER.

metaboIGNITER is used to pre-process untargeted metabolomics data. This version (v1.0.0) of the workflow can perform:

- IPO parameter tuning
- mass trace detection using XCMS or OpenMS
- Retention time alignment and grouping
- Adduct and isotope detection
- Noise filtering using QC stability, blank filtering, and dilution series
- Metabolite identification using FINGER:ID, MetFrag, CFM-ID, and Internal library
- Normalization and transformation

In addition, the version of nf-core template has been updated to 1.13.3.
All containers have been merged to one. And some clean up in the main.nf

Thanks to everyone who contributed to the workflow!
