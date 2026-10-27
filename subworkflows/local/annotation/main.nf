
include { OPENMS_METABOLITEADDUCTDECHARGER       } from '../../../modules/local/openms_metaboliteadductdecharger/main'
include { PYOPENMS_C13DETECTION } from '../../../modules/local/pyopenms_c13detection/main'


workflow ANNOTATION {
    take:
        quantification_information
        skip_adduct_detection
        skip_c13_detection

    main:
    ch_versions = channel.empty()

        if(!skip_adduct_detection)
        {
        OPENMS_METABOLITEADDUCTDECHARGER(quantification_information.map{ entry -> entry[0,1]})
        quantification_information = OPENMS_METABOLITEADDUCTDECHARGER.out.featurexml
        .join(quantification_information.map{ entry -> entry[0,2]},by:[0])

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
