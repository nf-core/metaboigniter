workflow MS2QUERY_MODELDOWNLOADER {
    take:
    polarity

    main:

    if(polarity=="positive")
    {
    Channel
    .fromPath("$projectDir/assets/m2query_model_positive.csv")
        .splitCsv ( header:true, sep:',' )
        .map { create_model_channel(it) }.set{model_files}
    }else if(polarity=="negative")
    {
        Channel
    .fromPath("$projectDir/assets/m2query_model_negative.csv")
        .splitCsv ( header:true, sep:',' )
        .map { create_model_channel(it) }.set{model_files}
    }


    emit:
    model_files                                     // channel: [ val(meta), [ reads ] ]
    //versions = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}

def create_model_channel(LinkedHashMap row) {


    if (!file(row.model_files).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> Model file does not exist!\n${row.model_files}"
    }
    return [file(row.model_files)]
}
