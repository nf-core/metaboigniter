
include { PYOPENMS_LIBBUILDER } from '../../modules/local/pyopenms_libbuilder.nf'
include { PYOPENMS_RELOADMAPS } from '../../modules/local/pyopenms_reloadmaps.nf'
include { OPENMS_FEATUREFINDERMETABOIDENT } from '../../modules/local/openms_featurefindermetaboident.nf'
include { PYOPENMS_MERGE } from '../../modules/local/pyopenms_merge.nf'
include { PYOPENMS_SPLIT } from '../../modules/local/pyopenms_split.nf'
workflow REQUANTIFICATION {
    take:
    consensusxml_data
    quantified_features
    quantificaiton_data

    main:
    ch_versions = Channel.empty()

consensusxml_data | PYOPENMS_SPLIT
 data_split=PYOPENMS_SPLIT.out.consensusxml
ch_versions       = ch_versions.mix(PYOPENMS_SPLIT.out.versions.first())

quantified_features.combine(data_split.map{it[1]}) |  PYOPENMS_RELOADMAPS

ch_versions       = ch_versions.mix(PYOPENMS_RELOADMAPS.out.versions.first())

quantified_features_complete=PYOPENMS_RELOADMAPS.out.featurexml

data_split.map{it[0,2]} | PYOPENMS_LIBBUILDER

ch_versions       = ch_versions.mix(PYOPENMS_LIBBUILDER.out.versions.first())

quantificaiton_data.combine(PYOPENMS_LIBBUILDER.out.tsv.map{it[1]}) | OPENMS_FEATUREFINDERMETABOIDENT

ch_versions       = ch_versions.mix(OPENMS_FEATUREFINDERMETABOIDENT.out.versions.first())

quantified_features_complete.join(OPENMS_FEATUREFINDERMETABOIDENT.out.featurexml,by:[0]) | PYOPENMS_MERGE

ch_versions       = ch_versions.mix(PYOPENMS_MERGE.out.versions.first())

features = PYOPENMS_MERGE.out.featurexml

    emit:
    quantified_features = features
    versions       = ch_versions



}
