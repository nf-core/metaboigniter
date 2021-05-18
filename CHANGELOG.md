# nf-core/metaboigniter: Changelog

## [v1.0.1](https://github.com/nf-core/metaboigniter/releases/tag/1.0.1) - 2021-05-11

A bug in running using AWS has been fixed.
Also the template has been updated to nf-core/tools v1.14.

## [v1.0.0](https://github.com/nf-core/metaboigniter/releases/tag/1.0.0) - 2021-05-08

Initial release of nf-core/metaboigniter, created with the [nf-core](http://nf-co.re/) template.

This release is the initial version of metaboIGNITER.

metaboIGNITER is used to pre-process untargeted metabolomics data. This version (v1.0.0) of the workflow can perform:

* IPO parameter tuning
* mass trace detection using XCMS or OpenMS
* Retention time alignment and grouping
* Adduct and isotope detection
* Noise filtering using QC stability, blank filtering, and dilution series
* Metabolite identification using FINGER:ID, MetFrag, CFM-ID, and Internal library
* Normalization and transformation

In addition, the version of nf-core template has been updated to 1.13.3.
All containers have been merged to one. And some clean up in the main.nf

Thanks to everyone who contributed to the workflow!
