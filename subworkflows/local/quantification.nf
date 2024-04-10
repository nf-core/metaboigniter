include { OPENMS_PEAKPICKERHIRES       } from '../../modules/local/openms_peakpickerhires.nf'
include { OPENMS_FEATUREFINDERMETABO       } from '../../modules/local/openms_featurefindermetabo.nf'
include { OPENMS_MAPALIGNERPOSECLUSTERING       } from '../../modules/local/openms_mapalignerposeclustering.nf'
include { OPENMS_MAPALIGNERPOSECLUSTERINGMZML       } from '../../modules/local/openms_mapalignerposeclusteringmzml.nf'
include { OPENMS_MAPRTTRANSFORMER       } from '../../modules/local/openms_maprttransformer.nf'
include { OPENMS_METABOLITEADDUCTDECHARGER       } from '../../modules/local/openms_metaboliteadductdecharger.nf'

include {     MERGEMS1MS2   } from '../../subworkflows/local/mergems1ms2.nf'

workflow QUANTIFICATION {
    take:
    mzml_files
    skip_centroiding
    ms2_collection_model
    skip_alignment


    main:

    ch_versions = Channel.empty()

if (!skip_centroiding){

    OPENMS_PEAKPICKERHIRES(mzml_files)
    mzml_files=OPENMS_PEAKPICKERHIRES.out.mzml
    ch_versions       = ch_versions.mix(OPENMS_PEAKPICKERHIRES.out.versions.first())
}

if(ms2_collection_model=="separate" && !skip_alignment)
{
    mzml_files.collect{it[0]}.toList().combine(mzml_files.collect{it[1]}.toList()) | OPENMS_MAPALIGNERPOSECLUSTERINGMZML


    mzml_files = mzml_files.map{meta,mzml->
    idd=mzml.baseName
    [[map_id:idd],meta,mzml]}.join(OPENMS_MAPALIGNERPOSECLUSTERINGMZML.out.mzml.map{it[1]}.flatten().map{mzml ->
     idd=mzml.baseName
     [[map_id:idd], mzml]}).map{it[1,3]}

    ch_versions       = ch_versions.mix(OPENMS_MAPALIGNERPOSECLUSTERINGMZML.out.versions.first())

}




quantificaiton_data=mzml_files.filter{meta,file->meta.level == "MS1" | meta.level == "MS12"}

OPENMS_FEATUREFINDERMETABO(quantificaiton_data)

quantified_features=OPENMS_FEATUREFINDERMETABO.out.featurexml

ch_versions       = ch_versions.mix(OPENMS_FEATUREFINDERMETABO.out.versions.first())
if(ms2_collection_model=="paired" && !skip_alignment)
{
    quantified_features.collect{it[0]}.toList().combine(quantified_features.collect{it[1]}.toList()) | OPENMS_MAPALIGNERPOSECLUSTERING

    ch_versions       = ch_versions.mix(OPENMS_MAPALIGNERPOSECLUSTERING.out.versions.first())

   combined_data =quantified_features.map{meta,featurexml->
   tuple(featurexml.baseName, meta)}
    .join(OPENMS_MAPALIGNERPOSECLUSTERING.out.featurexml.map{it[1]}.flatten().map{featurexml ->
    tuple(featurexml.baseName, featurexml)})
     .join(OPENMS_MAPALIGNERPOSECLUSTERING.out.trafoxml.map{it[1]}.flatten().map{trafoxml ->
    tuple(trafoxml.baseName, trafoxml)})
    .join(quantificaiton_data.map{meta,mzml->
 tuple(mzml.baseName, mzml)}).map{it[1..4]}


    combined_data.map{it[0,2,3]} | OPENMS_MAPRTTRANSFORMER

    ch_versions       = ch_versions.mix(OPENMS_MAPRTTRANSFORMER.out.versions.first())

    quantificaiton_data=OPENMS_MAPRTTRANSFORMER.out.mzml
    quantified_features=combined_data.map{it[0,1]}



}


    emit:
    quantified_features = quantified_features
    quantificaiton_data = quantificaiton_data
    mzml_files = mzml_files
    versions       = ch_versions

}
