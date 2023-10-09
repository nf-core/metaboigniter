/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryLog; paramsSummaryMap } from 'plugin/nf-validation'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

//WorkflowMetaboigniter.initialise(params, log)


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK    } from '../subworkflows/local/input_check.nf'
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







///


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//

include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary


workflow METABOIGNITER {


    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //

empty_id=Channel.fromPath("$projectDir/assets/emptyfile.idXML")

if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

INPUT_CHECK(ch_input)
mzml_files = INPUT_CHECK.out.mzml_files

ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)


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


if(!params.requantification)
{

ANNOTATION(quantification_information,empty_id,false,Channel.empty(),params.skip_adduct_detection)
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

if(params.requantification)//params.requantification
{

    REQUANTIFICATION(consensusxml_data,quantified_features,quantificaiton_data)


    ch_versions = ch_versions.mix(REQUANTIFICATION.out.versions)

    quantification_information = REQUANTIFICATION.out.quantified_features.join(quantificaiton_data,by:[0])

    ANNOTATION_REQ(quantification_information,empty_id,false,channel.empty(),params.skip_adduct_detection)

    ch_versions = ch_versions.mix(ANNOTATION_REQ.out.versions)


LINKER_REQ(ANNOTATION_REQ.out.quantification_information,params.parallel_linking)
consensusxml_data=LINKER_REQ.out.consensusxml_data
ch_versions = ch_versions.mix(LINKER_REQ.out.versions)

}


    //
    // SUBWORKFLOW: export the entire data matrix
    //
if(!params.identification)
{
PYOPENMS_EXPORTQUANTIFICATION(consensusxml_data,[[],[]],[[],[]],[[],[]])
consensusxml_data_tsv = PYOPENMS_EXPORTQUANTIFICATION.out.tsv
ch_versions = ch_versions.mix(PYOPENMS_EXPORTQUANTIFICATION.out.versions)
}



    //
    // SUBWORKFLOW: Perform identification
    //
if(params.identification)
{


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


    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )


}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
