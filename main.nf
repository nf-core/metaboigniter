#!/usr/bin/env nextflow
/*
========================================================================================
    nf-core/metaboigniter
========================================================================================
    Github : https://github.com/nf-core/metaboigniter
    Website: https://nf-co.re/metaboigniter
    Slack  : https://nfcore.slack.com/channels/metaboigniter
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
========================================================================================
    GENOME PARAMETER VALUES
========================================================================================
*/

params.fasta = WorkflowMain.getGenomeAttribute(params, 'fasta')

/*
========================================================================================
    VALIDATE & PRINT PARAMETER SUMMARY
========================================================================================
*/

WorkflowMain.initialise(workflow, params, log)

/*
========================================================================================
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

include { METABOIGNITER } from './workflows/metaboigniter'

//
// WORKFLOW: Run main nf-core/metaboigniter analysis pipeline
//
workflow NFCORE_METABOIGNITER {
    METABOIGNITER ()
}

/*
========================================================================================
    RUN ALL WORKFLOWS
========================================================================================
*/

//
// WORKFLOW: Execute a single named workflow for the pipeline
// See: https://github.com/nf-core/rnaseq/issues/619
//
workflow {
    NFCORE_METABOIGNITER ()
}

/*
========================================================================================
    THE END
========================================================================================
*/
