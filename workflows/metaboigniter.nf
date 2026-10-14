/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { REQUANTIFICATION                                  } from '../subworkflows/local/requantification/main'
include { QUANTIFICATION                                    } from '../subworkflows/local/quantification/main'
include { ANNOTATION                                        } from '../subworkflows/local/annotation/main'
include { ANNOTATION as ANNOTATION_REQ                      } from '../subworkflows/local/annotation/main'
include { LINKER                                            } from '../subworkflows/local/linker/main'
include { LINKER as LINKER_REQ                              } from '../subworkflows/local/linker/main'
include { IDENTIFICATION                                    } from '../subworkflows/local/identification/main'
include { PYOPENMS_EXPORT as PYOPENMS_EXPORTQUANTIFICATION  } from '../modules/local/pyopenms_export/main'
include { PYOPENMS_EXPORT as PYOPENMS_EXPORTIDENTIFICATION  } from '../modules/local/pyopenms_export/main'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline/main'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline/main'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_metaboigniter_pipeline/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow METABOIGNITER {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    multiqc_config
    multiqc_logo
    multiqc_methods_description
    outdir

    main:

    def ch_versions = channel.empty()
    def ch_multiqc_files = channel.empty()

    def mzml_files = ch_samplesheet

    def empty_id = channel.fromPath("${projectDir}/assets/emptyfile.idXML")

    //
    // SUBWORKFLOW: First quantification + alignment
    //
    QUANTIFICATION(mzml_files,params.skip_centroiding,params.ms2_collection_model,params.skip_alignment)
    def quantified_features = QUANTIFICATION.out.quantified_features
    def quantificaiton_data = QUANTIFICATION.out.quantificaiton_data
    mzml_files = QUANTIFICATION.out.mzml_files
    def quantification_information = quantified_features.join(quantificaiton_data,by:[0])
    ch_versions = ch_versions.mix(QUANTIFICATION.out.versions)

    //
    // SUBWORKFLOW: If requantification is goint to be performed, skip annotation
    //
    if(!params.requantification){
        ANNOTATION(quantification_information,empty_id,false,channel.empty(),params.skip_adduct_detection,!params.identification)
        quantification_information=ANNOTATION.out.quantification_information
        ch_versions = ch_versions.mix(ANNOTATION.out.versions)
    }

    //
    // SUBWORKFLOW: Link the features across runs
    //
    LINKER(quantification_information,params.parallel_linking)
    def consensusxml_data=LINKER.out.consensusxml_data
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
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'nf_core_'  +  'metaboigniter_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        )

    //
    // MODULE: MultiQC
    //
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    def ch_summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def ch_workflow_summary = channel.value(paramsSummaryMultiqc(ch_summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    def ch_multiqc_custom_methods_description = multiqc_methods_description
        ? file(multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    def ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))
    MULTIQC(
        ch_multiqc_files.flatten().collect().map { files ->
            [
                [id: 'metaboigniter'],
                files,
                multiqc_config
                    ? file(multiqc_config, checkIfExists: true)
                    : file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                multiqc_logo ? file(multiqc_logo, checkIfExists: true) : [],
                [],
                [],
            ]
        }
    )
    emit:multiqc_report = MULTIQC.out.report.map { _meta, report -> [report] }.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
