# nf-core/metaboigniter: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v2.1.0dev - [unreleased<!-- TODO nf-core: replace with date on release -->]

### `Fixed`

- Intermediate outputs of `PYOPENMS_C13DETECTION`, `PYOPENMS_EXTRACTFEATUREMZ`, `PYOPENMS_SPLITFEATUREXML` and `PYOPENMS_GENERATESEARCHPARAMSUNMAPPED` are only published with `--save_intermeds`; identification runs no longer copy every input mzML into `pyopenms/`
- Intermediate results are published with `--publish_dir_mode` (default `copy`) instead of as symlinks into the work directory, and without the per-task `versions.yml` files
- [#95](https://github.com/nf-core/metaboigniter/issues/95) MS2 input files without an mzML index are indexed with OpenMS `FileConverter` before identification instead of failing in `PYOPENMS_GENERATESEARCHPARAMS`
- [#103](https://github.com/nf-core/metaboigniter/issues/103) `PYOPENMS_MSMAPPING` maps MS2 precursors through an m/z index and reads spectra without peak data; same output, about 10x faster on the six-file test set and no longer quadratic in features x spectra
- [#112](https://github.com/nf-core/metaboigniter/issues/112) Use logical `||` instead of bitwise `|` when filtering inputs by MS level
- [#113](https://github.com/nf-core/metaboigniter/issues/113) Sample intensity columns of the exported tables follow the consensusXML map order instead of a random order that changed between runs

### `Changed`

- OpenMS and pyOpenMS updated from 3.0.0 / 2.9.1 to 3.6.0. Results change slightly because of upstream fixes in feature finding and linking (OpenMS [#10157](https://github.com/OpenMS/OpenMS/pull/10157), [#10225](https://github.com/OpenMS/OpenMS/pull/10225)). On the test data with identification and parallel linking, 99.5 % of consensus features are unchanged with identical intensities, consensus features with an `[M+H]+` adduct annotation go from 7,821 to 9,654, and requantified intensities move by a median of 0.4 %.
- `FeatureFinderMetaboIdent` always receives `-EMGScoring:init_mom`, because OpenMS 3.6 changed its default to `true`; the pipeline default stays `false`
- Template update to nf-core/tools 4.1.0: `nf-validation` replaced by `nf-schema`, `check_max()`/`--max_*` replaced by `process.resourceLimits`, CI moved to nf-test, minimum Nextflow version raised to 25.10.4
- The `arm` profile is replaced by the template's `arm64` (Wave-built arm64 containers) and `emulate_amd64` profiles

### `Removed`

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
