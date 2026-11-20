include { PYOPENMS_LIBBUILDER             } from '../../../modules/local/pyopenms_libbuilder/main'
include { OPENMS_FEATUREFINDERMETABOIDENT } from '../../../modules/local/openms_featurefindermetaboident/main'
include { PYOPENMS_REQUANTQC              } from '../../../modules/local/pyopenms_requantqc/main'
include { PYOPENMS_GAPFILLCONSENSUS       } from '../../../modules/local/pyopenms_gapfillconsensus/main'

workflow REQUANTIFICATION {

    take:
    consensusxml_data          // channel: [ val(meta), path(consensusXML) ] authoritative consensus map (one item)
    quantification_information // channel: [ val(meta), path(featureXML), path(mzML) ] the per-sample maps that were linked

    main:
    def ch_versions = channel.empty()

    //
    // One target per consensus row that lacks this sample
    //
    PYOPENMS_LIBBUILDER(
        quantification_information.map { meta, featurexml, _mzml -> [ meta, featurexml ] },
        consensusxml_data.first()
    )
    ch_versions = ch_versions.mix(PYOPENMS_LIBBUILDER.out.versions.first())

    def libraries = PYOPENMS_LIBBUILDER.out.library
        .branch { _meta, _library, n_targets ->
            with_targets: n_targets.toInteger() > 0
            without_targets: true
        }

    //
    // Targeted extraction; samples without targets skip FeatureFinderMetaboIdent
    //
    OPENMS_FEATUREFINDERMETABOIDENT(
        quantification_information
            .map { meta, _featurexml, mzml -> [ meta, mzml ] }
            // with_targets is a subset of the samples, so only failOnDuplicate applies here;
            // the PYOPENMS_REQUANTQC joins below enforce failOnMismatch over all samples
            .join(
                libraries.with_targets.map { meta, library, _n_targets -> [ meta, library ] },
                failOnDuplicate: true
            )
    )
    ch_versions = ch_versions.mix(OPENMS_FEATUREFINDERMETABOIDENT.out.versions.first())

    def candidates = OPENMS_FEATUREFINDERMETABOIDENT.out.featurexml
        .mix(libraries.without_targets.map { meta, _library, _n_targets -> [ meta, [] ] })

    //
    // Per-sample quality control of the candidates
    //
    PYOPENMS_REQUANTQC(
        PYOPENMS_LIBBUILDER.out.targets
            .join(PYOPENMS_LIBBUILDER.out.originals, failOnMismatch: true, failOnDuplicate: true)
            .join(candidates, failOnMismatch: true, failOnDuplicate: true)
    )
    ch_versions = ch_versions.mix(PYOPENMS_REQUANTQC.out.versions.first())

    //
    // Insert the accepted fills into the requesting consensus rows
    //
    def sample_tables = PYOPENMS_LIBBUILDER.out.sample_map
        .join(PYOPENMS_REQUANTQC.out.candidates, failOnMismatch: true, failOnDuplicate: true)
        .join(PYOPENMS_REQUANTQC.out.fills, failOnMismatch: true, failOnDuplicate: true)
        .toSortedList { left, right -> left[0].id <=> right[0].id }
        .map { entries ->
            [
                entries.collect { entry -> entry[0].id },
                entries.collect { entry -> entry[1] },
                entries.collect { entry -> entry[2] },
                entries.collect { entry -> entry[3] }
            ]
        }

    PYOPENMS_GAPFILLCONSENSUS(consensusxml_data.first(), sample_tables)
    ch_versions = ch_versions.mix(PYOPENMS_GAPFILLCONSENSUS.out.versions)

    emit:
    consensusxml = PYOPENMS_GAPFILLCONSENSUS.out.consensusxml // channel: [ val(meta), path(consensusXML) ] gap-filled consensus map
    mask         = PYOPENMS_GAPFILLCONSENSUS.out.mask         // channel: [ val(meta), path(tsv) ]
    provenance   = PYOPENMS_GAPFILLCONSENSUS.out.provenance   // channel: [ val(meta), path(tsv) ]
    summary      = PYOPENMS_GAPFILLCONSENSUS.out.summary      // channel: [ val(meta), path(tsv) ]
    versions     = ch_versions                                // channel: [ path(versions.yml) ]
}
