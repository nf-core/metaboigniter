include {OPENMS_FILEFILTERMS2 } from '../../modules/local/openms_filefilter.nf'
include {PYOPENMS_FILEMERGER } from '../../modules/local/pyopenms_filemerger.nf'

workflow MERGEMS1MS2 {
    take:
    mzml_files

    main:

    ch_versions = Channel.empty()


     // remove MS1
    mzml_files.filter{meta,file->meta.level == "MS2"} | OPENMS_FILEFILTERMS2

ch_versions       = ch_versions.mix(OPENMS_FILEFILTERMS2.out.versions.first())
    // merge

    mzml_files.filter{meta,file->meta.level != "MS2"}.combine(OPENMS_FILEFILTERMS2.out.mzml.map{it[1]}).groupTuple(by:[0,1]) | OPENMS_FILEMERGER
ch_versions       = ch_versions.mix(OPENMS_FILEMERGER.out.versions.first())





    emit:
    mzml_files = OPENMS_FILEMERGER.out.mzml
    versions       = ch_versions

}
