# nf-core/metaboigniter: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v2.1.0dev - [date]

- Several bug fixes
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
