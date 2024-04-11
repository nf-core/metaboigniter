
include { OPENMS_METABOLITEADDUCTDECHARGER       } from '../../modules/local/openms_metaboliteadductdecharger.nf'
include { PYOPENMS_C13DETECTION } from '../../modules/local/pyopenms_c13detection.nf'


workflow ANNOTATION {
    take:
        quantification_information
        empty_id
        separate
        mzml_files
        skip_adduct_detection
        skip_c13_detection

    main:
    ch_versions = Channel.empty()

        if(!skip_adduct_detection)
        {
        OPENMS_METABOLITEADDUCTDECHARGER(quantification_information.map{it[0,1]})
        quantified_features=OPENMS_METABOLITEADDUCTDECHARGER.out.featurexml
        quantification_information = OPENMS_METABOLITEADDUCTDECHARGER.out.featurexml
        .join(quantification_information.map{it[0,2]},by:[0])

        ch_versions       = ch_versions.mix(OPENMS_METABOLITEADDUCTDECHARGER.out.versions.first())
        }

        if(!skip_c13_detection)
        {
        quantification_information | PYOPENMS_C13DETECTION
        quantification_information = PYOPENMS_C13DETECTION.out.featurexml
        ch_versions       = ch_versions.mix(PYOPENMS_C13DETECTION.out.versions.first())
        }

    emit:
        quantification_information = quantification_information
        versions       = ch_versions

}
