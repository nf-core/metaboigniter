


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//

include {REQUANTIFICATION } from '../subworkflows/local/requantification.nf'
include {QUANTIFICATION } from '../subworkflows/local/quantification.nf'
include {ANNOTATION as ANNOTATION} from '../subworkflows/local/annotation.nf'
include {ANNOTATION as ANNOTATION_SEP} from '../subworkflows/local/annotation.nf'
include {ANNOTATION as ANNOTATION_REQ_SEP} from '../subworkflows/local/annotation.nf'
include {ANNOTATION as ANNOTATION_REQ} from '../subworkflows/local/annotation.nf'
include {LINKER as LINKER} from '../subworkflows/local/linker.nf'
include {LINKER as LINKER_REQ} from '../subworkflows/local/linker.nf'
include {IDENTIFICATION } from '../subworkflows/local/identification.nf'
include {PYOPENMS_EXPORT as PYOPENMS_EXPORTQUANTIFICATION } from '../modules/local/pyopenms_export.nf'
include {PYOPENMS_EXPORT as PYOPENMS_EXPORTIDENTIFICATION } from '../modules/local/pyopenms_export.nf'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-validation'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_metaboigniter_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow METABOIGNITER {
    take:
    ch_samplesheet

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    mzml_files = ch_samplesheet

    empty_id=Channel.fromPath("$projectDir/assets/emptyfile.idXML")


    //
    // SUBWORKFLOW: First quantification + alignment
    //
    QUANTIFICATION(mzml_files,params.skip_centroiding,params.ms2_collection_model,params.skip_alignment)
    quantified_features = QUANTIFICATION.out.quantified_features
    quantificaiton_data = QUANTIFICATION.out.quantificaiton_data
    mzml_files = QUANTIFICATION.out.mzml_files
    quantification_information = quantified_features.join(quantificaiton_data,by:[0])
    ch_versions = ch_versions.mix(QUANTIFICATION.out.versions)
    //
    // SUBWORKFLOW: If requantification is goint to be performed, skip annotation
    //


    if(!params.requantification){
        ANNOTATION(quantification_information,empty_id,false,Channel.empty(),params.skip_adduct_detection,!params.identification)
        quantification_information=ANNOTATION.out.quantification_information
        ch_versions = ch_versions.mix(ANNOTATION.out.versions)
    }

    //
    // SUBWORKFLOW: Link the features across runs
    //

    LINKER(quantification_information,params.parallel_linking)
    consensusxml_data=LINKER.out.consensusxml_data
    ch_versions = ch_versions.mix(LINKER.out.versions)

    //
    // SUBWORKFLOW: requantification and annotation and also linking
    //

    if(params.requantification){
        REQUANTIFICATION(consensusxml_data,quantified_features,quantificaiton_data)
        ch_versions = ch_versions.mix(REQUANTIFICATION.out.versions)

        quantification_information = REQUANTIFICATION.out.quantified_features.join(quantificaiton_data,by:[0])
        ANNOTATION_REQ(quantification_information,empty_id,false,channel.empty(),params.skip_adduct_detection,!params.identification)
        ch_versions = ch_versions.mix(ANNOTATION_REQ.out.versions)

        LINKER_REQ(ANNOTATION_REQ.out.quantification_information,params.parallel_linking)
        consensusxml_data=LINKER_REQ.out.consensusxml_data
        ch_versions = ch_versions.mix(LINKER_REQ.out.versions)
    }


    //
    // SUBWORKFLOW: export the entire data matrix
    //
    if(!params.identification){
        PYOPENMS_EXPORTQUANTIFICATION(consensusxml_data,[[],[]],[[],[]],[[],[]])
        consensusxml_data_tsv = PYOPENMS_EXPORTQUANTIFICATION.out.tsv
        ch_versions = ch_versions.mix(PYOPENMS_EXPORTQUANTIFICATION.out.versions)
    }

    //
    // SUBWORKFLOW: Perform identification
    //
    if(params.identification){
        IDENTIFICATION(consensusxml_data,
        mzml_files,
        quantification_information,
        params.offline_model_ms2query,
        params.models_dir_ms2query,
        params.train_library_ms2query,
        params.library_path_ms2query,
        params.polarity,
        params.split_consensus_parts,
        params.run_umapped_spectra,
        params.mgf_splitmgf_pyopenms,
        params.sirius_split,
        params.run_ms2query,
        params.run_sirius)
        ch_versions = ch_versions.mix(IDENTIFICATION.out.versions)

        PYOPENMS_EXPORTIDENTIFICATION(consensusxml_data,
        IDENTIFICATION.out.sirius.ifEmpty([[],[]]),
        IDENTIFICATION.out.fingerid.ifEmpty([[],[]]),
        IDENTIFICATION.out.ms2query.ifEmpty([[],[]]))
        ch_versions = ch_versions.mix(PYOPENMS_EXPORTIDENTIFICATION.out.versions)
    }


    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_pipeline_software_mqc_versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))

    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
