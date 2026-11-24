include { OPENMS_PEAKPICKERHIRES       } from '../../../modules/local/openms_peakpickerhires/main'
include { OPENMS_FEATUREFINDERMETABO       } from '../../../modules/local/openms_featurefindermetabo/main'
include { OPENMS_MAPALIGNERPOSECLUSTERING       } from '../../../modules/local/openms_mapalignerposeclustering/main'
include { OPENMS_MAPALIGNERPOSECLUSTERINGMZML       } from '../../../modules/local/openms_mapalignerposeclusteringmzml/main'
include { OPENMS_MAPRTTRANSFORMER       } from '../../../modules/local/openms_maprttransformer/main'

workflow QUANTIFICATION {
    take:
    mzml_files
    skip_centroiding
    ms2_collection_model
    skip_alignment


    main:

    ch_versions = channel.empty()

if (!skip_centroiding){

    OPENMS_PEAKPICKERHIRES(mzml_files)
    mzml_files=OPENMS_PEAKPICKERHIRES.out.mzml
    ch_versions       = ch_versions.mix(OPENMS_PEAKPICKERHIRES.out.versions.first())
}

if(ms2_collection_model=="separate" && !skip_alignment)
{
    mzml_files.collect{ entry -> entry[0]}.toList().combine(mzml_files.collect{ entry -> entry[1]}.toList()) | OPENMS_MAPALIGNERPOSECLUSTERINGMZML


    mzml_files = mzml_files.map{meta,mzml->
    def idd=mzml.baseName
    [[map_id:idd],meta,mzml]}.join(OPENMS_MAPALIGNERPOSECLUSTERINGMZML.out.mzml.map{ entry -> entry[1]}.flatten().map{mzml ->
    def idd=mzml.baseName
    [[map_id:idd], mzml]}).map{ entry -> entry[1,3]}

    ch_versions       = ch_versions.mix(OPENMS_MAPALIGNERPOSECLUSTERINGMZML.out.versions.first())

}




quantificaiton_data=mzml_files.filter{meta,_file->meta.level == "MS1" || meta.level == "MS12"}

// MS2 spectra must be mapped in the same retention time frame as the features.
// Without paired-mode alignment these are the files above (aligned in separate mode).
identification_mzml=mzml_files.filter{meta,_file->meta.level == "MS2" || meta.level == "MS12"}

OPENMS_FEATUREFINDERMETABO(quantificaiton_data)

quantified_features=OPENMS_FEATUREFINDERMETABO.out.featurexml

ch_versions       = ch_versions.mix(OPENMS_FEATUREFINDERMETABO.out.versions.first())
if(ms2_collection_model=="paired" && !skip_alignment)
{
    quantified_features.collect{ entry -> entry[0]}.toList().combine(quantified_features.collect{ entry -> entry[1]}.toList()) | OPENMS_MAPALIGNERPOSECLUSTERING

    ch_versions       = ch_versions.mix(OPENMS_MAPALIGNERPOSECLUSTERING.out.versions.first())

combined_data =quantified_features.map{meta,featurexml->
tuple(featurexml.baseName, meta)}
    .join(OPENMS_MAPALIGNERPOSECLUSTERING.out.featurexml.map{ entry -> entry[1]}.flatten().map{featurexml ->
    tuple(featurexml.baseName, featurexml)})
    .join(OPENMS_MAPALIGNERPOSECLUSTERING.out.trafoxml.map{ entry -> entry[1]}.flatten().map{trafoxml ->
    tuple(trafoxml.baseName, trafoxml)})
    .join(quantificaiton_data.map{_meta,mzml->
tuple(mzml.baseName, mzml)}).map{ entry -> entry[1..4]}


    combined_data.map{ entry -> entry[0,2,3]} | OPENMS_MAPRTTRANSFORMER

    ch_versions       = ch_versions.mix(OPENMS_MAPRTTRANSFORMER.out.versions.first())

    quantificaiton_data=OPENMS_MAPRTTRANSFORMER.out.mzml
    quantified_features=combined_data.map{ entry -> entry[0,1]}

    // Paired mode aligns the features, so identification must use the RT-transformed
    // MS12 files. level=MS2 identification files have no transformation and pass through unchanged.
    identification_mzml=mzml_files.filter{meta,_file->meta.level == "MS2"}
        .mix(OPENMS_MAPRTTRANSFORMER.out.mzml.filter{meta,_file->meta.level == "MS12"})



}


    emit:
    quantified_features = quantified_features
    quantificaiton_data = quantificaiton_data
    mzml_files = mzml_files
    identification_mzml = identification_mzml
    versions       = ch_versions

}
