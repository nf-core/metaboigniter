include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check'

workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:
    SAMPLESHEET_CHECK ( samplesheet )
        .csv
        .splitCsv ( header:true, sep:',' )
        .map { create_msms_channel(it) }
        .set { mzml_files }

    emit:
    mzml_files                                     // channel: [ val(meta), [ reads ] ]
    versions = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}

def create_msms_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.sample_name       = row.sample
    meta.level   = row.level
    meta.type = row.type

    // add path(s) of the ms file(s) to the meta map
    def ms_meta = []
    if (!file(row.msfile).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> MS file does not exist!\n${row.msfile1}"
    }
    meta.id=file(row.msfile).baseName
    ms_meta = [ meta, file(row.msfile)  ]
    return ms_meta
}
