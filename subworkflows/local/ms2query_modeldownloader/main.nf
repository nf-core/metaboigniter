include { MS2QUERY_DOWNLOADMODEL } from '../../../modules/local/ms2query_downloadmodel/main'

workflow MS2QUERY_MODELDOWNLOADER {
    take:
    polarity

    main:
    ch_versions = channel.empty()

    if(polarity=="positive")
    {
    channel
    .fromPath("$projectDir/assets/m2query_model_positive.csv") |  MS2QUERY_DOWNLOADMODEL

    model_files = MS2QUERY_DOWNLOADMODEL.out.model_files
    }else if(polarity=="negative")
    {
    channel
    .fromPath("$projectDir/assets/m2query_model_negative.csv") |  MS2QUERY_DOWNLOADMODEL

    model_files = MS2QUERY_DOWNLOADMODEL.out.model_files
    }

    ch_versions       = ch_versions.mix(MS2QUERY_DOWNLOADMODEL.out.versions.first())

    emit:
    model_files
    versions = ch_versions
}
