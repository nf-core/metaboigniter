#!/usr/bin/env nextflow
/*
========================================================================================
                         nf-core/metaboigniter
========================================================================================
 nf-core/metaboigniter Analysis Pipeline.
 #### Homepage / Documentation
 https://github.com/nf-core/metaboigniter
----------------------------------------------------------------------------------------
*/

def helpMessage() {
    // TODO nf-core: Add to this help message with new command line parameters
    log.info nfcoreHeader()
    log.info"""

    Usage:

    The typical command for running the pipeline is as follows:

    nextflow run MetaboIGNITER/metaboigniter -profile docker

    We highly recommend you edit the parameter file (conf/parameters.config) as the number of parameters is large. You can then run the workflow without specifying any parameters

    Please do remember than if you would like to use OpenMS tools (PeakPickerHiRes or FeatureFinderMetabo) you need to edit the OpenMS parameters in the "conf/params" folder.

    Other options:
      --outdir                      The output directory where the results will be saved
      --email                       Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits
      -name                         Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic.

    AWSBatch options:
      --awsqueue                    The AWSBatch JobQueue that needs to be set when running on AWSBatch
      --awsregion                   The AWS Region for your AWS Batch job to run on
    """.stripIndent()
}



/*
 * SET UP CONFIGURATION VARIABLES
 */

// Show help emssage
if (params.help){
    helpMessage()
    exit 0
}


// Has the run name been specified by the user?
//  this has the bonus effect of catching both -name and --name
custom_runName = params.name
if( !(workflow.runName ==~ /[a-z]+_[a-z]+/) ){
  custom_runName = workflow.runName
}


if( workflow.profile == 'awsbatch') {
  // AWSBatch sanity checking
  if (!params.awsqueue || !params.awsregion) exit 1, "Specify correct --awsqueue and --awsregion parameters on AWSBatch!"
  // Check outdir paths to be S3 buckets if running on AWSBatch
  // related: https://github.com/nextflow-io/nextflow/issues/813
  if (!params.outdir.startsWith('s3:')) exit 1, "Outdir not on S3 - specify S3 Bucket to run on AWSBatch!"
  // Prevent trace files to be stored on S3 since S3 does not support rolling files.
  if (workflow.tracedir.startsWith('s3:')) exit 1, "Specify a local tracedir or run without trace! S3 cannot be used for tracefiles."
}


/*
 * check if identification is needed
*/

if(params.containsKey('perform_identification') && params.perform_identification instanceof Boolean){
  if(params.perform_identification==true)
  {
    println("Information: Identification will be performed!")
  }else{
    println("Information: Identification will not be performed!")
  }
}else{
  "perform_identification is missing or not defined as boolean! You need to specify whether you want to do identification or not. If you don't want, set perform_identification to false in the parameter file (conf/parameter.config))"
}

/*
 * check which inonization is needed
*/

if(params.containsKey('type_of_ionization') && params.type_of_ionization instanceof String)
{
  if(!(params.type_of_ionization in (["pos","neg","both"])))
  {
    error("unkonw value '$params.type_of_ionization' for params.type_of_ionization. This has to be set to either 'pos', 'neg', or 'both'")
  }
  println("Information: Ionization method: $params.type_of_ionization")
}else{
  exit 1, "type_of_ionization is missing or not defined as string! You need to specify which ionization is needed. This has to be set to either 'pos', 'neg', or 'both' in conf/parameter.config"
}

/*
 * check if centroiding is needed
*/

if(params.containsKey('need_centroiding') && params.need_centroiding instanceof Boolean){
  if(params.need_centroiding==true)
  {
    println("Information: Centroiding will be performed!")
    if((params.type_of_ionization in (["pos","both"])))
    {
      if(params.containsKey('peakpicker_ini_file_pos_openms') && params.peakpicker_ini_file_pos_openms instanceof String){
    Channel
          .fromPath(params.peakpicker_ini_file_pos_openms)
          .ifEmpty { exit 1, "params.peakpicker_ini_file_pos_openms was empty - no input files supplied" }
          .set { peakpicker_ini_file_pos_openms}
        }else{
          exit 1, "params.peakpicker_ini_file_pos_openms is missing or not defined as String! You need to specify whether params.peakpicker_ini_file_pos_openms in the parameter file (conf/parameter.config))"

        }
    }

    if((params.type_of_ionization in (["neg","both"])))
    {
      if(params.containsKey('peakpicker_ini_file_neg_openms') && params.peakpicker_ini_file_neg_openms instanceof String){
    Channel
          .fromPath(params.peakpicker_ini_file_neg_openms)
          .ifEmpty { exit 1, "params.peakpicker_ini_file_neg_openms was empty - no input files supplied" }
          .set { peakpicker_ini_file_neg_openms}
        }else{
          exit 1, "params.peakpicker_ini_file_neg_openms is missing or not defined as String! You need to specify whether params.peakpicker_ini_file_neg_openms in the parameter file (conf/parameter.config))"

        }
    }

  }else{
    println("Information: Centroiding will not be performed!")
  }
}else{
  exit 1, "need_centroiding is missing or not defined as boolean! You need to specify whether you want to do centroiding or not. If you don't want, set need_centroiding to false in the parameter file (conf/parameter.config))"
}

/*
 * Create a channel for quantification (positive MS1) input files
 */
if((params.type_of_ionization in (["pos","both"])))
{
  if(params.containsKey('quant_mzml_files_pos') && params.quant_mzml_files_pos instanceof String){
        Channel
              .fromPath(params.quant_mzml_files_pos+"/*.mzML")
              .ifEmpty { exit 1, "params.quant_mzml_files_pos was empty - no input files supplied" }
              .set { quant_mzml_files_pos}
  } else{
    exit 1, "params.quant_mzml_files_pos was not found or not defined as string! You need to set quant_mzml_files_pos in conf/parameters.config to the path to a folder containing you input files"
  }
}

/*
 * Create a channel for quantification (negative MS1) input files
 */
if((params.type_of_ionization in (["neg","both"])))
{
  if(params.containsKey('quant_mzml_files_neg') && params.quant_mzml_files_neg instanceof String){
        Channel
              .fromPath(params.quant_mzml_files_neg+"/*.mzML")
              .ifEmpty { exit 1, "params.quant_mzml_files_neg was empty - no input files supplied" }
              .set { quant_mzml_files_neg}
  } else{
    exit 1, "params.quant_mzml_files_neg was not found or not defined as string! You need to set quant_mzml_files_neg in conf/parameters.config to the path to a folder containing you input files"
  }
}

/*
 * Create a channel for the design file (positive)
 */
if((params.type_of_ionization in (["pos","both"])))
{
  if(params.containsKey('phenotype_design_pos') && params.phenotype_design_pos instanceof String){
        Channel
              .fromPath(params.phenotype_design_pos)
              .ifEmpty { exit 1, "params.quant_mzml_files_pos was empty - no input files supplied" }
              .into { phenotype_design_pos; phenotype_design_pos_csifingerid; phenotype_design_pos_cfmid; phenotype_design_pos_metfrag; phenotype_design_pos_library; phenotype_design_pos_noid}
  } else{
    exit 1, "params.phenotype_design_pos was not found or not defined as string! You need to set phenotype_design_pos in conf/parameters.config to the path to a csv file containing your experimental design"
  }
}

/*
 *  Create a channel for the design file (positive)
 */
if((params.type_of_ionization in (["neg","both"])))
{
  if(params.containsKey('phenotype_design_neg') && params.phenotype_design_neg instanceof String){
        Channel
              .fromPath(params.phenotype_design_neg)
              .ifEmpty { exit 1, "params.phenotype_design_neg was empty - no input files supplied" }
              .into { phenotype_design_neg;  phenotype_design_neg_csifingerid; phenotype_design_neg_cfmid; phenotype_design_neg_metfrag; phenotype_design_neg_library; phenotype_design_neg_noid}
  } else{
    exit 1, "params.phenotype_design_neg was not found or not defined as string! You need to set phenotype_design_neg in conf/parameters.config to the path to a file containing your experimental design for negative ionization"
  }
}

/*
 *  Create a channel for the ID files (MS2)
 */
if(params.perform_identification==true)
{
  if((params.type_of_ionization in (["pos","both"])))
  {
    if(params.containsKey('id_mzml_files_pos') && params.id_mzml_files_pos instanceof String){
          Channel
                .fromPath(params.id_mzml_files_pos+"/*.mzML")
                .ifEmpty { exit 1, "params.id_mzml_files_pos was empty - no input files supplied" }
                .set { id_mzml_files_pos}
    } else{
      exit 1, "params.id_mzml_files_pos was not found or not defined as string! You need to set id_mzml_files_pos in conf/parameters.config to the path to a folder containing you input files (MS2 files in positive mode)"
    }
  }

  /*
   *  Create a channel for the design file (positive)
   */
  if((params.type_of_ionization in (["neg","both"])))
  {
    if(params.containsKey('id_mzml_files_neg') && params.id_mzml_files_neg instanceof String){
          Channel
                .fromPath(params.id_mzml_files_neg+"/*.mzML")
                .ifEmpty { exit 1, "params.id_mzml_files_neg was empty - no input files supplied" }
                .set { id_mzml_files_neg}
    } else{
       exit 1, "params.id_mzml_files_neg was not found or not defined as string! You need to set id_mzml_files_neg in conf/parameters.config to the path to a folder containing you input files (MS2 files in negative mode)"
    }
  }
}

/*
 *  Check which search engine to use for identification
 */

if(params.perform_identification==true)
{
if(
  !params.containsKey('perform_identification_metfrag') &&
!params.containsKey('perform_identification_csifingerid') &&
!params.containsKey('perform_identification_cfmid') &&
!params.containsKey('perform_identification_internal_library'))
{
exit 1, "None of the params.perform_identification_metfrag, params.perform_identification_csifingerid, params.perform_identification_cfmid and params.perform_identification_internal_library has been specified. You need to select at least one search engine in conf/parameters.config"
}

if(!(params.perform_identification_metfrag instanceof Boolean) ||
   !(params.perform_identification_csifingerid instanceof Boolean) ||
   !(params.perform_identification_cfmid instanceof Boolean) || !(params.perform_identification_internal_library instanceof Boolean))
{

  exit 1, "The params.perform_identification_metfrag, params.perform_identification_csifingerid, params.perform_identification_cfmid and params.perform_identification_internal_library should be true or false. You need to select at least one search engine in conf/parameters.config"

}
if(params.perform_identification_metfrag==false &&
  params.perform_identification_csifingerid==false &&
  params.perform_identification_cfmid==false &&
  params.perform_identification_internal_library==false)
  {
    exit 1, "None of the params.perform_identification_metfrag, params.perform_identification_csifingerid, params.perform_identification_cfmid and params.perform_identification_internal_library has been set to true. You need to select at least one search engine in conf/parameters.config"

  }

}


/*
 *  Check search engine parameters for library identification
 */

if(params.perform_identification==true && params.perform_identification_internal_library==true)
{

// for positive data
  if(params.containsKey('library_charactrized_pos') && params.library_charactrized_pos instanceof Boolean)
  {
    if(params.library_charactrized_pos==true)
    {
      if(params.containsKey('library_charactrization_file_pos') && params.library_charactrization_file_pos instanceof String)
      {
        Channel
              .fromPath(params.library_charactrization_file_pos)
              .ifEmpty { exit 1, "params.library_charactrization_file_pos was empty - no input files supplied" }
              .set { library_charactrization_file_pos}
      }else{
        exit 1, "params.library_charactrization_file_pos was not found or not defined as string! You need to set library_charactrization_file_pos in conf/parameters.config to the path to a file containing your charaztrized library"
      }
    }else{

      if(!params.containsKey('quant_library_mzml_files_pos') || !(params.library_charactrized_pos instanceof Boolean) ||
    !params.containsKey('id_library_mzml_files_pos') || !(params.id_library_mzml_files_pos instanceof String) ||
    !params.containsKey('library_description_pos') || !(params.library_description_pos instanceof String))
    {
      exit 1, "One of params.quant_library_mzml_files_pos,params.id_library_mzml_files_pos or param.library_description_pos was not found or not defined as string! You need to set them in conf/parameters.config!"

    }
    Channel
          .fromPath(params.quant_library_mzml_files_pos+"/*.mzML")
          .ifEmpty { exit 1, "params.quant_library_mzml_files_pos was empty - no input files supplied" }
          .set { quant_library_mzml_files_pos}

    Channel
          .fromPath(params.id_library_mzml_files_pos+"/*.mzML")
          .ifEmpty { exit 1, "params.id_library_mzml_files_pos was empty - no input files supplied" }
          .set { id_library_mzml_files_pos}

    Channel
          .fromPath(params.library_description_pos)
          .ifEmpty { exit 1, "params.library_description_pos was empty - no input files supplied" }
          .set { library_description_pos}


    }
    if(!(params.type_of_ionization in (["pos","both"])))
    {
      println("WARNING: The type of ionization in quantification does not include pos. The library won't be used!")
    }
  }else{
    exit 1, "library_charactrized_pos is missing or not defined as Boolean! You need to specify if you have already charaztrized your library in positive mode. This has to be set to either true or false in conf/parameter.config"
  }

  // for negative data
  if(params.containsKey('library_charactrized_neg') && params.library_charactrized_neg instanceof Boolean)
  {
    if(params.library_charactrized_neg==true)
    {
      if(params.containsKey('library_charactrization_file_neg') && params.library_charactrization_file_neg instanceof String)
      {
        Channel
              .fromPath(params.library_charactrization_file_neg)
              .ifEmpty { exit 1, "params.library_charactrization_file_neg was empty - no input files supplied" }
              .set { library_charactrization_file_neg}
      }else{
        exit 1, "params.library_charactrization_file_neg was not found or not defined as string! You need to set library_charactrization_file_neg in conf/parameters.config to the path to a file containing your charaztrized library"
      }
    }else{
      if(!params.containsKey('quant_library_mzml_files_neg') || !(params.library_charactrized_neg instanceof Boolean) ||
    !params.containsKey('id_library_mzml_files_neg') || !(params.id_library_mzml_files_neg instanceof String) ||
    !params.containsKey('library_description_neg') || !(params.library_description_neg instanceof String))
    {
      exit 1, "One of params.quant_library_mzml_files_neg, params.id_library_mzml_files_neg or param.library_description_neg was not found or not defined as string! You need to set them in conf/parameters.config!"

    }
    Channel
          .fromPath(params.quant_library_mzml_files_neg+"/*.mzML")
          .ifEmpty { exit 1, "params.quant_library_mzml_files_neg was empty - no input files supplied" }
          .set { quant_library_mzml_files_neg}

    Channel
          .fromPath(params.id_library_mzml_files_neg+"/*.mzML")
          .ifEmpty { exit 1, "params.id_library_mzml_files_neg was empty - no input files supplied" }
          .set { id_library_mzml_files_neg}

    Channel
          .fromPath(params.library_description_neg)
          .ifEmpty { exit 1, "params.library_description_neg was empty - no input files supplied" }
          .set { library_description_neg}


    }
    if(!(params.type_of_ionization in (["neg","both"])))
    {
      println("WARNING: The type of ionization in quantification does not include neg. The negative library won't be used!")
    }
  }else{
    exit 1, "library_charactrized_neg is missing or not defined as Boolean! You need to specify if you have already charaztrized your library in negative mode. This has to be set to either true or false in conf/parameter.config"
  }

}

if(!params.containsKey('quantification_openms_xcms_pos') ||
!(params.quantification_openms_xcms_pos in (["openms","xcms"])) ||
!(params.quantification_openms_xcms_pos instanceof String))
{
  exit 1, "quantification_openms_xcms_pos is missing or not defined as String! This should be either 'xcms' or 'openms' in conf/parameter.config"

}


if(!params.containsKey('quantification_openms_xcms_neg') ||
!params.quantification_openms_xcms_neg in (["openms","xcms"]) ||
 !(params.quantification_openms_xcms_neg instanceof String))
{
  exit 1, "quantification_openms_xcms_neg is missing or not defined as String! This should be either 'xcms' or 'openms' in conf/parameter.config"

}


if(!params.containsKey('quantification_openms_xcms_library_pos') ||
!(params.quantification_openms_xcms_library_pos in (["openms","xcms"])) || !(params.quantification_openms_xcms_library_pos instanceof String))
{
  exit 1, "quantification_openms_xcms_library_pos is missing or not defined as String! This should be either 'xcms' or 'openms' in conf/parameter.config"

}

if(!params.containsKey('quantification_openms_xcms_library_neg') ||
!(params.quantification_openms_xcms_library_neg in (["openms","xcms"])) || !(params.quantification_openms_xcms_library_neg instanceof String))
{
  exit 1, "quantification_openms_xcms_library_neg is missing or not defined as String! This should be either 'xcms' or 'openms' in conf/parameter.config"

}

if(params.quantification_openms_xcms_pos=="openms")
{
  if(params.containsKey('featurefinder_ini_pos_openms') && (params.featurefinder_ini_pos_openms instanceof String)){
        Channel
              .fromPath(params.featurefinder_ini_pos_openms)
              .ifEmpty { exit 1, "params.featurefinder_ini_pos_openms was empty - no input files supplied" }
              .set { featurefinder_ini_pos_openms}
  } else{
     exit 1, "params.featurefinder_ini_pos_openms was not found or not defined as string! You need to set featurefinder_ini_pos_openms in conf/parameters.config"
  }

}

if(params.quantification_openms_xcms_neg=="openms")
{
  if(params.containsKey('featurefinder_ini_neg_openms') && (params.featurefinder_ini_neg_openms instanceof String)){
        Channel
              .fromPath(params.featurefinder_ini_neg_openms)
              .ifEmpty { exit 1, "params.featurefinder_ini_pos_openms was empty - no input files supplied" }
              .set { featurefinder_ini_neg_openms}
  } else{
     exit 1, "params.featurefinder_ini_neg_openms was not found or not defined as string! You need to set featurefinder_ini_neg_openms in conf/parameters.config"
  }

}

if(params.quantification_openms_xcms_library_pos=="openms")
{
  if(params.containsKey('featurefinder_ini_library_pos_openms') && params.featurefinder_ini_library_pos_openms instanceof String){
        Channel
              .fromPath(params.featurefinder_ini_library_pos_openms)
              .ifEmpty { exit 1, "params.featurefinder_ini_library_pos_openms was empty - no input files supplied" }
              .set { featurefinder_ini_library_pos_openms}
  } else{
     exit 1, "params.featurefinder_ini_library_pos_openms was not found or not defined as string! You need to set featurefinder_ini_library_pos_openms in conf/parameters.config"
  }

}

if(params.quantification_openms_xcms_library_neg=="openms")
{
  if(params.containsKey('featurefinder_ini_library_neg_openms') && params.featurefinder_ini_library_neg_openms instanceof String){
        Channel
              .fromPath(params.featurefinder_ini_library_neg_openms)
              .ifEmpty { exit 1, "params.featurefinder_ini_library_pos_openms was empty - no input files supplied" }
              .set { featurefinder_ini_library_neg_openms}
  } else{
     exit 1, "params.featurefinder_ini_library_neg_openms was not found or not defined as string! You need to set featurefinder_ini_library_neg_openms in conf/parameters.config"
  }

}



if(params.type_of_ionization in (["pos","both"]))
{
if(params.containsKey('blank_filter_pos') && params.blank_filter_pos instanceof Boolean){
  if(params.blank_filter_pos==true)
  {
    println("Information: blank filtering will be performed in positive data!")
  }else{
    println("Information: blank filtering will not be performed in positive data!")
  }
}else{
  "blank_filter_pos is missing or not defined as boolean! You need to specify whether you want to do blank filtering or not. If you don't want, set blank_filter_pos to false in the parameter file (conf/parameter.config))"
}


if(params.containsKey('dilution_filter_pos') && params.dilution_filter_pos instanceof Boolean){
  if(params.dilution_filter_pos==true)
  {
    println("Information: dilution filtering will be performed in positive data!")
  }else{
    println("Information: dilution filtering will not be performed in positive data!")
  }
}else{
  "dilution_filter_pos is missing or not defined as boolean! You need to specify whether you want to do dilution filtering or not. If you don't want, set dilution_filter_pos to false in the parameter file (conf/parameter.config))"
}


if(params.containsKey('cv_filter_pos') && params.cv_filter_pos instanceof Boolean){
  if(params.cv_filter_pos==true)
  {
    println("Information: CV filtering will be performed in positive data!")
  }else{
    println("Information: CV filtering will not be performed in positive data!")
  }
}else{
  "cv_filter_pos is missing or not defined as boolean! You need to specify whether you want to do CV filtering or not. If you don't want, set cv_filter_pos to false in the parameter file (conf/parameter.config))"
}
}


if(params.type_of_ionization in (["neg","both"]))
{
  if(params.containsKey('blank_filter_neg') && params.blank_filter_neg instanceof Boolean){
    if(params.blank_filter_neg==true)
    {
      println("Information: blank filtering will be performed in negative data!")
    }else{
      println("Information: blank filtering will not be performed in negative data!")
    }
  }else{
    "blank_filter_neg is missing or not defined as boolean! You need to specify whether you want to do blank filtering or not. If you don't want, set blank_filter_neg to false in the parameter file (conf/parameter.config))"
  }


  if(params.containsKey('dilution_filter_neg') && params.dilution_filter_neg instanceof Boolean){
    if(params.dilution_filter_neg==true)
    {
      println("Information: dilution filtering will be performed in negative data!")
    }else{
      println("Information: dilution filtering will not be performed in negative data!")
    }
  }else{
    "dilution_filter_neg is missing or not defined as boolean! You need to specify whether you want to do dilution filtering or not. If you don't want, set dilution_filter_neg to false in the parameter file (conf/parameter.config))"
  }


  if(params.containsKey('cv_filter_neg') && params.cv_filter_neg instanceof Boolean){
    if(params.cv_filter_neg==true)
    {
      println("Information: CV filtering will be performed in negative data!")
    }else{
      println("Information: CV filtering will not be performed in negative data!")
    }
  }else{
    "cv_filter_neg is missing or not defined as boolean! You need to specify whether you want to do CV filtering or not. If you don't want, set cv_filter_neg to false in the parameter file (conf/parameter.config))"
  }
}




// Header log info
log.info nfcoreHeader()
def summary = [:]
if(workflow.revision) summary['Pipeline Release'] = workflow.revision
summary['Run Name']         = custom_runName ?: workflow.runName
// TODO nf-core: Report custom parameters here
summary['Type of ionization'] =  params.type_of_ionization
if(params.type_of_ionization in (["pos","both"]))
{
summary['Path to mzML quantification files (positive)'] = params.quant_mzml_files_pos
if(params.perform_identification == true)
{
  summary['Path to mzML identification files (positive)'] = params.id_mzml_files_pos
}

}

if(params.type_of_ionization in (["neg","both"]))
{
summary['Path to mzML quantification files (negative)'] = params.quant_mzml_files_neg
if(params.perform_identification == true)
{
  summary['Path to mzML identification files (negative)'] = params.id_mzml_files_neg
}

}

summary['Max Resources']    = "$params.max_memory memory, $params.max_cpus cpus, $params.max_time time per job"
if(workflow.containerEngine) summary['Container'] = "$workflow.containerEngine - $workflow.container"
summary['Output dir']       = params.outdir
summary['Launch dir']       = workflow.launchDir
summary['Working dir']      = workflow.workDir
summary['Script dir']       = workflow.projectDir
summary['User']             = workflow.userName
if(workflow.profile == 'awsbatch'){
   summary['AWS Region']    = params.awsregion
   summary['AWS Queue']     = params.awsqueue
}
summary['Config Profile'] = workflow.profile
if(params.config_profile_description) summary['Config Description'] = params.config_profile_description
if(params.config_profile_contact)     summary['Config Contact']     = params.config_profile_contact
if(params.config_profile_url)         summary['Config URL']         = params.config_profile_url
if(params.email) {
  summary['E-mail Address']  = params.email
  summary['MultiQC maxsize'] = params.maxMultiqcEmailFileSize
}
log.info summary.collect { k,v -> "${k.padRight(18)}: $v" }.join("\n")
log.info "\033[2m----------------------------------------------------\033[0m"

// Check the hostnames against configured profiles
checkHostname()

def create_workflow_summary(summary) {
    def yaml_file = workDir.resolve('workflow_summary_mqc.yaml')
    yaml_file.text  = """
    id: 'nf-core-metaboigniter-summary'
    description: " - this information is collected when the pipeline is started."
    section_name: 'nf-core/metaboigniter Workflow Summary'
    section_href: 'https://github.com/nf-core/metaboigniter'
    plot_type: 'html'
    data: |
        <dl class=\"dl-horizontal\">
${summary.collect { k,v -> "            <dt>$k</dt><dd><samp>${v ?: '<span style=\"color:#999999;\">N/A</a>'}</samp></dd>" }.join("\n")}
        </dl>
    """.stripIndent()

   return yaml_file
}


/*
 * Parse software version numbers
 */
process get_software_versions {
    publishDir "${params.outdir}/pipeline_info", mode: 'copy',
    saveAs: {filename ->
        if (filename.indexOf(".csv") > 0) filename
        else null
    }

    output:
    file 'software_versions_mqc.yaml' into software_versions_yaml
    file "software_versions.csv"

    script:
    // TODO nf-core: Get all tools to print their version number here fastqc --version > v_fastqc.txt
    """
    echo $workflow.manifest.version > v_pipeline.txt
    echo $workflow.nextflow.version > v_nextflow.txt
    scrape_software_versions.py &> software_versions_mqc.yaml
    """
}



/*
* for positive data if specified by the user
*/





if(params.type_of_ionization in (["pos","both"]))
{

  /*
   * STEP 1 - PeakPickerHiRes if selected by the user
   */
  if(params.need_centroiding==true)
  {
    process process_peak_picker_pos_openms{
        tag "$name"
        publishDir "${params.outdir}/process_peak_picker_pos_openms", mode: 'copy'
        stageInMode 'copy'
        // container '${computations.docker_peak_picker_pos_openms}'

        input:
        file mzMLFile from quant_mzml_files_pos
        each file(setting_file) from peakpicker_ini_file_pos_openms

        output:
        file "${mzMLFile}" into masstrace_detection_process_pos

        shell:
        '''
        PeakPickerHiRes -in !{mzMLFile} -out !{mzMLFile} -ini !{setting_file}
        '''
    }


      /*
       * STEP 2 - feature detection by openms if selected by the user
       */
   if(params.quantification_openms_xcms_pos=="openms")
   {
     process process_masstrace_detection_pos_openms {
         tag "$name"
         publishDir "${params.outdir}/process_masstrace_detection_pos_openms", mode: 'copy'
         stageInMode 'copy'
         // container '${computations.docker_masstrace_detection_pos_openms}'

         input:
         file mzMLFile from masstrace_detection_process_pos
         each file(setting_file) from featurefinder_ini_pos_openms

         output:
         file "${mzMLFile.baseName}.featureXML" into openms_to_xcms_conversion

         shell:
         '''
         FeatureFinderMetabo -in !{mzMLFile} -out !{mzMLFile.baseName}.featureXML -ini !{setting_file}
         '''
     }
     /*
      * STEP 2.5 - convert openms to xcms
      */
     process process_openms_to_xcms_conversion_pos {
         tag "$name"
         publishDir "${params.outdir}/process_masstrace_detection_pos_openms", mode: 'copy'
         stageInMode 'copy'
         // container '${computations.docker_openms_to_xcms_conversion}'

         input:
         file mzMLFile from openms_to_xcms_conversion
         each file(phenotype_file) from phenotype_design_pos

         output:
         file "${mzMLFile.baseName}.featureXML" into collect_rdata_pos_xcms

         shell:
         '''
          /usr/local/bin/featurexmlToCamera.r input=!{mzMLFile} realFileName=!{mzMLFile} polarity=positive output=!{mzMLFile.baseName}.rdata phenoFile=!{phenotype_file} phenoDataColumn=!{params.phenodatacolumn_quant_pos} sampleClass=!{params.sampleclass_quant_pos_xcms} changeNameTO=!{mzMLFile.baseName}.mzML

         '''
     }

   }else{
     /*
      * STEP 2 - feature detection by xcms
      */
     process process_masstrace_detection_pos_xcms_centroided{
       tag "$name"
       publishDir "${params.outdir}/process_masstrace_detection_pos_xcms", mode: 'copy'
       stageInMode 'copy'
       // container '${computations.docker_masstrace_detection_pos_xcms}'

       input:
       file mzMLFile from masstrace_detection_process_pos
       each file(phenotype_file) from phenotype_design_pos

       output:
       file "${mzMLFile.baseName}.rdata" into collect_rdata_pos_xcms

       shell:
       '''
	/usr/local/bin/findPeaks.r input=!{mzMLFile} output=!{mzMLFile.baseName}.rdata ppm=!{params.masstrace_ppm_pos_xcms} peakwidthLow=!{params.peakwidthlow_quant_pos_xcms} peakwidthHigh=!{params.peakwidthhigh_quant_pos_xcms} noise=!{params.noise_quant_pos_xcms} polarity=positive realFileName=!{mzMLFile} phenoFile=!{phenotype_file} phenoDataColumn=!{params.phenodatacolumn_quant_pos} sampleClass=!{params.sampleclass_quant_pos_xcms}
       '''
     }

   }


  }else{
    /*
     * STEP 1 - feature detection by xcms
     */
    process process_masstrace_detection_pos_xcms_noncentroided {
      tag "$name"
      publishDir "${params.outdir}/process_masstrace_detection_pos_xcms", mode: 'copy'
      stageInMode 'copy'
      // container '${computations.docker_masstrace_detection_pos_xcms}'

      input:
      file mzMLFile from quant_mzml_files_pos
      each file(phenotype_file) from phenotype_design_pos

      output:
      file "${mzMLFile.baseName}.rdata" into collect_rdata_pos_xcms

      shell:
      '''
      /usr/local/bin/findPeaks.r input=!{mzMLFile} output=!{mzMLFile.baseName}.rdata ppm=!{params.masstrace_ppm_pos_xcms} peakwidthLow=!{params.peakwidthlow_quant_pos_xcms} peakwidthHigh=!{params.peakwidthhigh_quant_pos_xcms} noise=!{params.noise_quant_pos_xcms} polarity=positive realFileName=!{mzMLFile} phenoFile=!{phenotype_file} phenoDataColumn=!{params.phenodatacolumn_quant_pos} sampleClass=!{params.sampleclass_quant_pos_xcms}


      '''
    }
  }

  /*
   * STEP 3 - collect xcms objects into a hyper object
   */
  process  process_collect_rdata_pos_xcms{
    tag "$name"
    publishDir "${params.outdir}/process_collect_rdata_pos_xcms", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_collect_rdata_pos_xcms}'

    input:
    file rdata_files from collect_rdata_pos_xcms.collect()

  output:
  file "collection_pos.rdata" into group_peaks_pos_N1_xcms

  script:
    def inputs_aggregated = rdata_files.collect{ "$it" }.join(",")
  shell:
     """
  	nextFlowDIR=\$PWD
  	/usr/local/bin/xcmsCollect.r input=$inputs_aggregated output=collection_pos.rdata
  	"""
  }

  /*
   * STEP 4 - link the mass traces across the samples
   */
  process  process_group_peaks_pos_N1_xcms{
    tag "$name"
    publishDir "${params.outdir}/process_group_peaks_pos_N1_xcms", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_group_peaks_pos_N1_xcms}'

    input:
    file rdata_files from group_peaks_pos_N1_xcms

  output:
  file "groupN1_pos.rdata" into align_rdata_pos_xcms

    shell:
      '''
  	/usr/local/bin/group.r input=!{rdata_files} output=groupN1_pos.rdata bandwidth=!{params.bandwidth_group_N1_pos_xcms} mzwid=!{params.mzwid_group_N1_pos_xcms}
  	'''
  }

  /*
   * STEP 5 - do RT correction
   */
  process  process_align_peaks_pos_xcms{
    tag "$name"
    publishDir "${params.outdir}/process_align_peaks_pos_xcms", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_align_peaks_pos_xcms}'


    input:
    file rdata_files from align_rdata_pos_xcms

  output:
  file "RTcorrected_pos.rdata" into group_peaks_pos_N2_xcms

    shell:
      '''
  	/usr/local/bin/retCor.r input=!{rdata_files} output=RTcorrected_pos.rdata method=!{params.method_align_N1_pos_xcms}

  	'''
  }


  /*
   * STEP 6 - do another round of grouping
   */
  process  process_group_peaks_pos_N2_xcms{
    tag "$name"
    publishDir "${params.outdir}/process_group_peaks_pos_N2_xcms", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_group_peaks_pos_N2_xcms}'

    input:
    file rdata_files from group_peaks_pos_N2_xcms

  output:
  file "groupN2_pos.rdata" into temp_unfiltered_channel_pos_1

    shell:
      '''
  	/usr/local/bin/group.r input=!{rdata_files} output=groupN2_pos.rdata bandwidth=!{params.bandwidth_group_N2_pos_xcms} mzwid=!{params.mzwid_group_N2_pos_xcms}
  	'''
  }

  /*
   * STEP 7 - noise filtering by using blank samples, if selected by the users
   */

if(params.blank_filter_pos)
{
  blankfilter_rdata_pos_xcms=temp_unfiltered_channel_pos_1

  process  process_blank_filter_pos_xcms{
    tag "$name"
    publishDir "${params.outdir}/process_blank_filter_pos_xcms", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_blank_filter_pos_xcms}'

    input:
    file rdata_files from blankfilter_rdata_pos_xcms

  output:
  file "blankFiltered_pos.rdata" into temp_unfiltered_channel_pos_2

    shell:
      '''
	/usr/local/bin/blankfilter.r input=!{rdata_files} output=blankFiltered_pos.rdata method=!{params.method_blankfilter_pos_xcms} blank=!{params.blank_blankfilter_pos_xcms} sample=!{params.sample_blankfilter_pos_xcms} rest=!{params.rest_blankfilter_pos_xcms}
      '''
  }
}else{
temp_unfiltered_channel_pos_2=temp_unfiltered_channel_pos_1
}

/*
 * STEP 8 - noise filtering by using dilution samples, if selected by the users
 */

if(params.dilution_filter_pos==true)
{
  dilutionfilter_rdata_pos_xcms=temp_unfiltered_channel_pos_2
  process  process_dilution_filter_pos_xcms{
    tag "$name"
    publishDir "${params.outdir}/process_dilution_filter_pos_xcms", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_dilution_filter_pos_xcms}'

    input:
    file rdata_files from dilutionfilter_rdata_pos_xcms

  output:
  file "dilutionFiltered_pos.rdata" into temp_unfiltered_channel_pos_3

    shell:
      '''
	/usr/local/bin/dilutionfilter.r input=!{rdata_files} output=dilutionFiltered_pos.rdata Corto=!{params.corto_dilutionfilter_pos_xcms} dilution=!{params.dilution_dilutionfilter_pos_xcms} pvalue=!{params.pvalue_dilutionfilter_pos_xcms} corcut=!{params.corcut_dilutionfilter_pos_xcms} abs=!{params.abs_dilutionfilter_pos_xcms}
      '''
  }
}else{

temp_unfiltered_channel_pos_3=temp_unfiltered_channel_pos_2
}
/*
 * STEP 9 - noise filtering by using QC samples, if selected by the users
 */

if(params.cv_filter_pos==true)
{
  cvfilter_rdata_pos_xcms=temp_unfiltered_channel_pos_3
  process  process_cv_filter_pos_xcms{
    tag "$name"
    publishDir "${params.outdir}/process_cv_filter_pos_xcms", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_cv_filter_pos_xcms}'

    input:
    file rdata_files from cvfilter_rdata_pos_xcms

  output:
  file "cvFiltered_pos.rdata" into temp_unfiltered_channel_pos_4

    shell:
      '''
    /usr/local/bin/cvfilter.r input=!{rdata_files} output=cvFiltered_pos.rdata qc=!{params.qc_cvfilter_pos_xcms} cvcut=!{params.cvcut_cvfilter_pos_xcms}
    '''
  }
}else{
temp_unfiltered_channel_pos_4=temp_unfiltered_channel_pos_3
}

annotation_rdata_pos_camera=temp_unfiltered_channel_pos_4

/*
 * STEP 11 - convert xcms object to CAMERA object
 */


process  process_annotate_peaks_pos_camera{
  tag "$name"
  publishDir "${params.outdir}/process_annotate_peaks_pos_camera", mode: 'copy'
  stageInMode 'copy'
  // container '${computations.docker_annotate_peaks_pos_camera}'

  input:
  file rdata_files from annotation_rdata_pos_camera

output:
file "CameraAnnotatePeaks_pos.rdata" into group_rdata_pos_camera

  shell:
    '''
	/usr/local/bin/xsAnnotate.r  input=!{rdata_files} output=CameraAnnotatePeaks_pos.rdata
	'''
}

/*
 * STEP 12 - cgroup the peaks based on their overlap FWHM
 */

process  process_group_peaks_pos_camera{
  tag "$name"
  publishDir "${params.outdir}/process_group_peaks_pos_camera", mode: 'copy'
  stageInMode 'copy'
  // container '${computations.docker_group_peaks_pos_camera}'

  input:
  file rdata_files from group_rdata_pos_camera

output:
file "CameraGroup_pos.rdata" into findaddcuts_rdata_pos_camera

  shell:
    '''
	/usr/local/bin/groupFWHM.r input=!{rdata_files} output=CameraGroup_pos.rdata sigma=!{params.sigma_group_pos_camera} perfwhm=!{params.perfwhm_group_pos_camera} intval=!{params.intval_group_pos_camera}
	'''
}

/*
 * STEP 13 - find adducts
 */

process  process_find_addcuts_pos_camera{
  tag "$name"
  publishDir "${params.outdir}/process_find_addcuts_pos_camera", mode: 'copy'
  stageInMode 'copy'
  // container '${computations.docker_find_addcuts_pos_camera}'

  input:
  file rdata_files from findaddcuts_rdata_pos_camera

output:
file "CameraFindAdducts_pos.rdata" into findisotopes_rdata_pos_camera

  shell:
    '''
	/usr/local/bin/findAdducts.r input=!{rdata_files} output=CameraFindAdducts_pos.rdata ppm=!{params.ppm_findaddcuts_pos_camera} polarity=!{params.polarity_findaddcuts_pos_camera}
	'''
}

/*
 * STEP 14 - find isotopes
 */

process  process_find_isotopes_pos_camera{
  tag "$name"
  publishDir "${params.outdir}/process_find_isotopes_pos_camera", mode: 'copy'
  stageInMode 'copy'
  // container '${computations.docker_find_isotopes_pos_camera}'

  input:
  file rdata_files from findisotopes_rdata_pos_camera

output:
file "CameraFindIsotopes_pos.rdata" into mapmsmstocamera_rdata_pos_camera,mapmsmstoparam_rdata_pos_camera,prepareoutput_rdata_pos_camera_csifingerid, prepareoutput_rdata_pos_camera_cfmid, prepareoutput_rdata_pos_camera_metfrag, prepareoutput_rdata_pos_camera_library, prepareoutput_rdata_pos_camera_noid

  shell:
    '''
	/usr/local/bin/findIsotopes.r input=!{rdata_files} output=CameraFindIsotopes_pos.rdata maxcharge=!{params.maxcharge_findisotopes_pos_camera}
	'''
}

/*
* Identification starts here
* We the MSMS data need to be read and convered to parameters
*/


if(params.perform_identification==true)
{


  /*
   * STEP 15 - read MSMS data
   */

  process  process_read_MS2_pos_msnbase{
    tag "$name"
    publishDir "${params.outdir}/process_read_MS2_pos_msnbase", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_read_MS2_pos_msnbase}'

    input:
    file mzMLFile from id_mzml_files_pos

  output:
  file "${mzMLFile.baseName}.rdata" into mapmsmstocamera_rdata_pos_msnbase

    shell:
    '''
  	/usr/local/bin/readMS2MSnBase.r input=!{mzMLFile} output=!{mzMLFile.baseName}.rdata inputname=!{mzMLFile.baseName}
  	'''
  }

  /*
   * STEP 16 - map MS2 ions to camera features
   */

  process  process_mapmsms_tocamera_pos_msnbase{
    tag "$name"
    publishDir "${params.outdir}/process_mapmsms_tocamera_pos_msnbase", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_mapmsms_tocamera_pos_msnbase}'

    input:
    file rdata_files_ms2 from mapmsmstocamera_rdata_pos_msnbase.collect()
    file rdata_files_ms1 from mapmsmstocamera_rdata_pos_camera

  output:
  file "MapMsms2Camera_pos.rdata" into mapmsmstoparam_rdata_pos_msnbase

    script:
    def input_args = rdata_files_ms2.collect{ "$it" }.join(",")
    shell:
    """
  	/usr/local/bin/mapMS2ToCamera.r inputCAMERA=!{rdata_files_ms1} inputMS2=$input_args output=MapMsms2Camera_pos.rdata ppm=!{params.ppm_mapmsmstocamera_pos_msnbase} rt=!{params.rt_mapmsmstocamera_pos_msnbase}
  	"""
  }

  /*
   * STEP 17 - convert MS2 ions to parameters for search
   */

  process  process_mapmsms_toparam_pos_msnbase{
    tag "$name"
    publishDir "${params.outdir}/process_mapmsms_toparam_pos_msnbase", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_mapmsms_toparam_pos_msnbase}'

    input:
    file rdata_files_ms2 from mapmsmstoparam_rdata_pos_msnbase
    file rdata_files_ms1 from mapmsmstoparam_rdata_pos_camera

  output:
  file "*.txt" into csifingerid_txt_pos_msnbase, addcutremove_txt_pos_msnbase, metfrag_txt_pos_msnbase, cfmidin_txt_pos_msnbase
    shell:
      '''
  	mkdir out
  	/usr/local/bin/MS2ToMetFrag.r inputCAMERA=!{rdata_files_ms1} inputMS2=!{rdata_files_ms2} output=out precursorppm=!{params.precursorppm_msmstoparam_pos_msnbase} fragmentppm=!{params.fragmentppm_msmstoparam_pos_msnbase} fragmentabs=!{params.fragmentabs_msmstoparam_pos_msnbase} database=!{params.database_msmstoparam_pos_msnbase} mode=!{params.mode_msmstoparam_pos_msnbase} adductRules=!{params.adductRules_msmstoparam_pos_msnbase} minPeaks=!{params.minPeaks_msmstoparam_pos_msnbase}
    zip -r res.zip out/
  	unzip -j res.zip
  	'''
  }

/*
* we need to decide which search engine to select
* each search engine will have its own path for quantification at this stage.
* todo: implement joint search engine score so that we will have only path to quantification.
*/

if(params.perform_identification_csifingerid==true)
{
csifingerid_txt_pos_msnbase_flatten=csifingerid_txt_pos_msnbase.flatten()

  /*
   * STEP 18 - do search using CSIFingerID
   */

process  process_ms2_identification_pos_csifingerid{
  tag "$name"
  publishDir "${params.outdir}/process_ms2_identification_pos_csifingerid", mode: 'copy'
  // container '${computations.docker_ms2_identification_pos_csifingerid}'

  input:
  file parameters from csifingerid_txt_pos_msnbase_flatten

   output:
  file "${parameters.baseName}.csv" into aggregateID_csv_pos_csifingerid

  shell:
    '''
	touch !{parameters.baseName}.csv
	/usr/local/bin/fingerID.r input=$PWD/!{parameters} database=!{params.database_csifingerid_pos_csifingerid} tryOffline=T output=$PWD/!{parameters.baseName}.csv

	'''
}
/*
 * STEP 19 - aggregate ids from CSI
 */

process  process_identification_aggregate_pos_csifingerid{
  tag "$name"
  publishDir "${params.outdir}/process_identification_aggregate_pos_csifingerid", mode: 'copy'
  // container '${computations.docker_identification_aggregate_pos_csifingerid}'

  input:
  file identification_result from aggregateID_csv_pos_csifingerid.collect()

output:
file "aggregated_identification_csifingerid_pos.csv" into csifingerid_tsv_pos_passatutto

  shell:
    '''
	zip -r Csifingerid_pos.zip .
	/usr/local/bin/aggregateMetfrag.r inputs=Csifingerid_pos.zip realNames=Csifingerid_pos.zip output=aggregated_identification_csifingerid_pos.csv filetype=zip outTable=T
sed -i '/^$/d' aggregated_identification_csifingerid_pos.csv
	'''
}
/*
 * STEP 20 - calculate pep from CSI results
 */

process process_pepcalculation_csifingerid_pos_passatutto{
  tag "$name"
  publishDir "${params.outdir}/process_pepcalculation_csifingerid_pos_passatutto", mode: 'copy'
  // container '${computations.docker_pepcalculation_csifingerid_pos_passatutto'

  input:
  file identification_result from csifingerid_tsv_pos_passatutto

output:
file "pep_identification_csifingerid_pos.csv" into csifingerid_tsv_pos_output

shell:
  '''
  if [ -s !{identification_result} ]
then
/usr/local/bin/metfragPEP.r input=!{identification_result} score=score output=pep_identification_csifingerid_pos.csv readTable=T
else
touch pep_identification_csifingerid_pos.csv

fi


'''

}
/*
 * STEP 21 - output the results
 */
process  process_output_quantid_pos_camera_csifingerid{
  tag "$name"
  publishDir "${params.outdir}/process_output_quantid_pos_camera_csifingerid", mode: 'copy'
  stageInMode 'copy'
  // container '${computations.docker_output_quantid_pos_camera_csifingerid}'

  input:
  file phenotype_file from phenotype_design_pos_csifingerid
  file camera_input_quant from prepareoutput_rdata_pos_camera_csifingerid
  file csifingerid_input_identification from csifingerid_tsv_pos_output

output:
file "*.txt" into csifingerid_pos_finished
  shell:
'''
if [ -s !{csifingerid_input_identification} ]
then

	/usr/local/bin/prepareOutput.r inputcamera=!{camera_input_quant} inputscores=!{csifingerid_input_identification} inputpheno=!{phenotype_file} ppm=!{params.ppm_output_pos_camera} rt=!{params.rt_output_pos_camera} higherTheBetter=true scoreColumn=score impute=!{params.impute_output_pos_camera} typeColumn=!{params.type_column_output_pos_camera} selectedType=!{params.selected_type_output_pos_camera} rename=!{params.rename_output_pos_camera} renameCol=!{params.rename_col_output_pos_camera} onlyReportWithID=!{params.only_report_with_id_output_pos_camera} combineReplicate=!{params.combine_replicate_output_pos_camera} combineReplicateColumn=!{params.combine_replicate_column_output_pos_camera} log=!{params.log_output_pos_camera} sampleCoverage=!{params.sample_coverage_output_pos_camera} outputPeakTable=peaktablePOSout_pos_csifingerid.txt outputVariables=varsPOSout_pos_csifingerid.txt outputMetaData=metadataPOSout_pos_csifingerid.txt Ifnormalize=!{params.normalize_output_pos_camera}

else

	/usr/local/bin/prepareOutput.r inputcamera=!{camera_input_quant} inputpheno=!{phenotype_file} ppm=!{params.ppm_output_pos_camera} rt=!{params.rt_output_pos_camera} higherTheBetter=true scoreColumn=score impute=!{params.impute_output_pos_camera} typeColumn=!{params.type_column_output_pos_camera} selectedType=!{params.selected_type_output_pos_camera} rename=!{params.rename_output_pos_camera} renameCol=!{params.rename_col_output_pos_camera} onlyReportWithID=!{params.only_report_with_id_output_pos_camera} combineReplicate=!{params.combine_replicate_output_pos_camera} combineReplicateColumn=!{params.combine_replicate_column_output_pos_camera} log=!{params.log_output_pos_camera} sampleCoverage=!{params.sample_coverage_output_pos_camera} outputPeakTable=peaktablePOSout_pos_csifingerid.txt outputVariables=varsPOSout_pos_csifingerid.txt outputMetaData=metadataPOSout_pos_csifingerid.txt Ifnormalize=!{params.normalize_output_pos_camera}

fi
	'''
}

}


/*
* This is for Metfrag search engine
*/

if(params.perform_identification_metfrag==true)
{

  /*
   * check whether the data base file has been provided
   */
if(params.database_msmstoparam_pos_msnbase=="LocalCSV")
{
  if(params.containsKey('database_csv_files_pos_metfrag') && params.database_csv_files_pos_metfrag instanceof String){
        Channel
              .fromPath(params.database_csv_files_pos_metfrag)
              .ifEmpty { exit 1, "params.database_csv_files_pos_metfrag was empty - no input files supplied" }
              .set {database_csv_files_pos_metfrag}
  } else{
    exit 1, "params.database_csv_files_pos_metfrag was not found or not defined as string! You need to set database_csv_files_pos_metfrag in conf/parameters.config to the path to a csv file containing your database"
  }
}


metfrag_txt_pos_msnbase_flatten=metfrag_txt_pos_msnbase.flatten()

/*
 * STEP 22 - do identification using metfrag
 */

process  process_ms2_identification_pos_metfrag{
  tag "$name"
  publishDir "${params.outdir}/process_ms2_identification_pos_metfrag", mode: 'copy'
  // container '${computations.docker_ms2_identification_pos_metfrag}'

  input:
  file parameters from metfrag_txt_pos_msnbase_flatten
  each file(metfrag_database) from database_csv_files_pos_metfrag


   output:
  file "${parameters.baseName}.csv" into aggregateID_csv_pos_metfrag

  shell:
    '''
    touch !{parameters.baseName}.csv

   bash /usr/local/bin/run_metfrag.sh -p $PWD/!{parameters} -f $PWD/!{parameters.baseName}.csv -l "$PWD/!{metfrag_database}" -s "OfflineMetFusionScore"

	'''
}

/*
 * STEP 23 - aggregate metfrag results
 */

process  process_identification_aggregate_pos_metfrag{
  tag "$name"
  publishDir "${params.outdir}/process_identification_aggregate_pos_metfrag", mode: 'copy'
  // container '${computations.docker_identification_aggregate_pos_metfrag'

  input:
  file identification_result from aggregateID_csv_pos_metfrag.collect()

output:
file "aggregated_identification_metfrag_pos.csv" into metfrag_tsv_pos_passatutto

  shell:
    '''
	zip -r metfrag_pos.zip .
	/usr/local/bin/aggregateMetfrag.r inputs=metfrag_pos.zip realNames=metfrag_pos.zip output=aggregated_identification_metfrag_pos.csv filetype=zip outTable=T
  sed -i '/^$/d' aggregated_identification_metfrag_pos.csv

	'''
}

/*
 * STEP 24 - calculate pep from metfrag results
 */
process process_pepcalculation_metfrag_pos_passatutto{
  tag "$name"
  publishDir "${params.outdir}/process_pepcalculation_metfrag_pos_passatutto", mode: 'copy'
  // container '${computations.docker_pepcalculation_metfrag_pos_passatutto'

  input:
  file identification_result from metfrag_tsv_pos_passatutto

output:
file "pep_identification_metfrag_pos.csv" into metfrag_tsv_pos_output

shell:
  '''

  if [ -s !{identification_result} ]
then
/usr/local/bin/metfragPEP.r input=!{identification_result} score=FragmenterScore output=pep_identification_metfrag_pos.csv readTable=T
else
touch pep_identification_metfrag_pos.csv

fi


'''

}


/*
 * STEP 25 - output metfrag results
 */

process  process_output_quantid_pos_camera_metfrag{
  tag "$name"
  publishDir "${params.outdir}/process_output_quantid_pos_camera_metfrag", mode: 'copy'
  stageInMode 'copy'
  // container '${computations.docker_output_quantid_pos_camera_metfrag}'

  input:
  file phenotype_file from phenotype_design_pos_metfrag
  file camera_input_quant from prepareoutput_rdata_pos_camera_metfrag
  file metfrag_input_identification from metfrag_tsv_pos_output

output:
file "*.txt" into metfrag_pos_finished
  shell:
'''
if [ -s !{metfrag_input_identification} ]
then
/usr/local/bin/prepareOutput.r inputcamera=!{camera_input_quant} inputscores=!{metfrag_input_identification} inputpheno=!{phenotype_file} ppm=!{params.ppm_output_pos_camera} rt=!{params.rt_output_pos_camera} higherTheBetter=true scoreColumn=FragmenterScore impute=!{params.impute_output_pos_camera} typeColumn=!{params.type_column_output_pos_camera} selectedType=!{params.selected_type_output_pos_camera} rename=!{params.rename_output_pos_camera} renameCol=!{params.rename_col_output_pos_camera} onlyReportWithID=!{params.only_report_with_id_output_pos_camera} combineReplicate=!{params.combine_replicate_output_pos_camera} combineReplicateColumn=!{params.combine_replicate_column_output_pos_camera} log=!{params.log_output_pos_camera} sampleCoverage=!{params.sample_coverage_output_pos_camera} outputPeakTable=peaktablePOSout_pos_metfrag.txt outputVariables=varsPOSout_pos_metfrag.txt outputMetaData=metadataPOSout_pos_metfrag.txt Ifnormalize=!{params.normalize_output_pos_camera}

else
/usr/local/bin/prepareOutput.r inputcamera=!{camera_input_quant} inputpheno=!{phenotype_file} ppm=!{params.ppm_output_pos_camera} rt=!{params.rt_output_pos_camera} higherTheBetter=true scoreColumn=FragmenterScore impute=!{params.impute_output_pos_camera} typeColumn=!{params.type_column_output_pos_camera} selectedType=!{params.selected_type_output_pos_camera} rename=!{params.rename_output_pos_camera} renameCol=!{params.rename_col_output_pos_camera} onlyReportWithID=!{params.only_report_with_id_output_pos_camera} combineReplicate=!{params.combine_replicate_output_pos_camera} combineReplicateColumn=!{params.combine_replicate_column_output_pos_camera} log=!{params.log_output_pos_camera} sampleCoverage=!{params.sample_coverage_output_pos_camera} outputPeakTable=peaktablePOSout_pos_metfrag.txt outputVariables=varsPOSout_pos_metfrag.txt outputMetaData=metadataPOSout_pos_metfrag.txt Ifnormalize=!{params.normalize_output_pos_camera}


fi
	'''

}

}

if(params.perform_identification_cfmid==true)
{
  /*
   * check whether the database has been provide for cfmid
   */



if(params.containsKey('database_csv_files_pos_cfmid') && params.database_csv_files_pos_cfmid instanceof String){
      Channel
            .fromPath(params.database_csv_files_pos_cfmid)
            .ifEmpty { exit 1, "params.database_csv_files_pos_cfmid was empty - no input files supplied" }
            .set {database_csv_files_pos_cfmid}
} else{
  exit 1, "params.database_csv_files_pos_cfmid was not found or not defined as string! You need to set database_csv_files_pos_cfmid in conf/parameters.config to the path to a csv file containing your database"
}

cfmid_txt_pos_msnbase_flatten=cfmidin_txt_pos_msnbase.flatten()
/*
 * STEP 26 - do search using cfmid
 */
process  process_ms2_identification_pos_cfmid{
  tag "$name"
  publishDir "${params.outdir}/process_ms2_identification_pos_cfmid", mode: 'copy'
  // container '${computations.docker_ms2_identification_pos_cfmid}'

  input:
  file parameters from cfmid_txt_pos_msnbase_flatten
  each file(cfmid_database) from database_csv_files_pos_cfmid

   output:
  file "${parameters.baseName}.csv" into aggregateID_csv_pos_cfmid


  shell:
    '''
    touch !{parameters.baseName}.csv

    /usr/local/bin/cfmid.r input=$PWD/!{parameters} realName=!{parameters} databaseFile=$PWD/!{cfmid_database}  output=$PWD/!{parameters.baseName}.csv candidate_id=!{params.candidate_id_identification_pos_cfmid} candidate_inchi_smiles=!{params.candidate_inchi_smiles_identification_pos_cfmid} candidate_mass=!{params.candidate_mass_identification_pos_cfmid} databaseNameColumn=!{params.database_name_column_identification_pos_cfmid} databaseInChIColumn=!{params.database_inchI_column_identification_pos_cfmid} scoreType=Jaccard

	'''
}

/*
 * STEP 27 - aggregate cfmid results
 */

process  process_identification_aggregate_pos_cfmid{
  tag "$name"
  publishDir "${params.outdir}/process_identification_aggregate_pos_cfmid", mode: 'copy'
  // container '${computations.docker_identification_aggregate_pos_cfmid'

  input:
  file identification_result from aggregateID_csv_pos_cfmid.collect()

output:
file "aggregated_identification_cfmid_pos.csv" into cfmid_tsv_pos_passatutto

  shell:
    '''
	zip -r cfmid_pos.zip .
	/usr/local/bin/aggregateMetfrag.r inputs=cfmid_pos.zip realNames=cfmid_pos.zip output=aggregated_identification_cfmid_pos.csv filetype=zip outTable=T
sed -i '/^$/d' aggregated_identification_cfmid_pos.csv
	'''
}

/*
 * STEP 28 - calculate pep based on cfmid
 */


process process_pepcalculation_cfmid_pos_passatutto{
  tag "$name"
  publishDir "${params.outdir}/process_pepcalculation_cfmid_pos_passatutto", mode: 'copy'
  // container '${computations.docker_pepcalculation_cfmid_pos_passatutto'

  input:
  file identification_result from cfmid_tsv_pos_passatutto

output:
file "pep_identification_cfmid_pos.csv" into cfmid_tsv_pos_output

shell:
  '''

if [ -s !{identification_result} ]
then
/usr/local/bin/metfragPEP.r input=!{identification_result} score=Jaccard_Score output=pep_identification_cfmid_pos.csv readTable=T
else
touch pep_identification_cfmid_pos.csv

fi
'''

}

/*
 * STEP 29 - output the results based on cfmid
 */


process  process_output_quantid_pos_camera_cfmid{
  tag "$name"
  publishDir "${params.outdir}/process_output_quantid_pos_camera_cfmid", mode: 'copy'
  stageInMode 'copy'
  // container '${computations.docker_output_quantid_pos_camera_cfmid}'

  input:
  file phenotype_file from phenotype_design_pos_cfmid
  file camera_input_quant from prepareoutput_rdata_pos_camera_cfmid
  file cfmid_input_identification from cfmid_tsv_pos_output

output:
file "*.txt" into cfmid_pos_finished
  shell:
'''

if [ -s !{cfmid_input_identification} ]
then
/usr/local/bin/prepareOutput.r inputcamera=!{camera_input_quant} inputscores=!{cfmid_input_identification} inputpheno=!{phenotype_file} ppm=!{params.ppm_output_pos_camera} rt=!{params.rt_output_pos_camera} higherTheBetter=true scoreColumn=Jaccard_Score impute=!{params.impute_output_pos_camera} typeColumn=!{params.type_column_output_pos_camera} selectedType=!{params.selected_type_output_pos_camera} rename=!{params.rename_output_pos_camera} renameCol=!{params.rename_col_output_pos_camera} onlyReportWithID=!{params.only_report_with_id_output_pos_camera} combineReplicate=!{params.combine_replicate_output_pos_camera} combineReplicateColumn=!{params.combine_replicate_column_output_pos_camera} log=!{params.log_output_pos_camera} sampleCoverage=!{params.sample_coverage_output_pos_camera} outputPeakTable=peaktablePOSout_pos_cfmid.txt outputVariables=varsPOSout_pos_cfmid.txt outputMetaData=metadataPOSout_pos_cfmid.txt Ifnormalize=!{params.normalize_output_pos_camera}

else
/usr/local/bin/prepareOutput.r inputcamera=!{camera_input_quant} inputpheno=!{phenotype_file} ppm=!{params.ppm_output_pos_camera} rt=!{params.rt_output_pos_camera} higherTheBetter=true scoreColumn=Jaccard_Score impute=!{params.impute_output_pos_camera} typeColumn=!{params.type_column_output_pos_camera} selectedType=!{params.selected_type_output_pos_camera} rename=!{params.rename_output_pos_camera} renameCol=!{params.rename_col_output_pos_camera} onlyReportWithID=!{params.only_report_with_id_output_pos_camera} combineReplicate=!{params.combine_replicate_output_pos_camera} combineReplicateColumn=!{params.combine_replicate_column_output_pos_camera} log=!{params.log_output_pos_camera} sampleCoverage=!{params.sample_coverage_output_pos_camera} outputPeakTable=peaktablePOSout_pos_cfmid.txt outputVariables=varsPOSout_pos_cfmid.txt outputMetaData=metadataPOSout_pos_cfmid.txt Ifnormalize=!{params.normalize_output_pos_camera}


fi
	'''
}

}



/*
* For internal library
*/





if(params.perform_identification_internal_library==true)
{
if(params.library_charactrized_pos==false){
  if(params.need_centroiding==true)
  {
    /*
     * STEP 30 - peakpicking for library
     */

    process process_peak_picker_library_pos_openms {
        tag "$name"
        publishDir "${params.outdir}/process_peak_picker_library_pos_openms", mode: 'copy'
        stageInMode 'copy'
        // container '${computations.docker_peak_picker_library_pos_openms}'

        input:
        file mzMLFile from quant_library_mzml_files_pos
        each file(setting_file) from peakpicker_ini_file_library_pos_openms

        output:
        file "${mzMLFile}" into masstrace_detection_process_library_pos

        shell:
        '''
        PeakPickerHiRes -in !{mzMLFile} -out !{mzMLFile} -ini !{setting_file}
        '''
    }

   if(params.quantification_openms_xcms_library_pos=="openms")
   {
     /*
      * STEP 31 - feature detection for the library by openms
      */
     process process_masstrace_detection_library_pos_openms {
         tag "$name"
         publishDir "${params.outdir}/process_masstrace_detection_library_pos_openms", mode: 'copy'
         stageInMode 'copy'
         // container '${computations.docker_masstrace_detection_library_pos_openms}'

         input:
         file mzMLFile from masstrace_detection_process_library_pos
         each file(setting_file) from featurefinder_ini_library_pos_openms

         output:
         file "${mzMLFile.baseName}.featureXML" into openms_to_xcms_conversion

         shell:
         '''
         FeatureFinderMetabo -in !{mzMLFile} -out !{mzMLFile.baseName}.featureXML -ini !{setting_file}
         '''
     }

     /*
      * STEP 32 - convert openms to xcms
      */

     process process_openms_to_xcms_conversion_library_pos_centroided {
         tag "$name"
         publishDir "${params.outdir}/process_masstrace_detection_library_pos_openms", mode: 'copy'
         stageInMode 'copy'
         // container '${computations.docker_openms_to_xcms_conversion}'

         input:
         file mzMLFile from openms_to_xcms_conversion
         //each file(phenotype_file) from phenotype_design_library_pos

         output:
         file "${mzMLFile.baseName}.featureXML" into annotation_rdata_library_pos_camera

         shell:
         '''
          /usr/local/bin/featurexmlToCamera.r input=!{mzMLFile} realFileName=!{mzMLFile} polarity=positive output=!{mzMLFile.baseName}.rdata sampleClass=library changeNameTO=!{mzMLFile.baseName}.mzML

         '''
     }

   }else{

     /*
      * STEP 33 - feature detection using xcms
      */

     process process_masstrace_detection_library_pos_xcms_centroided{
       tag "$name"
       publishDir "${params.outdir}/process_masstrace_detection_library_pos_xcms", mode: 'copy'
       stageInMode 'copy'
       // container '${computations.docker_masstrace_detection_library_pos_xcms}'

       input:
       file mzMLFile from masstrace_detection_process_library_pos
  //     each file(phenotype_file) from phenotype_design_library_pos

       output:
       file "${mzMLFile.baseName}.rdata" into annotation_rdata_library_pos_camera

       shell:
       '''
  /usr/local/bin/findPeaks.r input=!{mzMLFile} output=!{mzMLFile.baseName}.rdata ppm=!{params.masstrace_ppm_library_pos_xcms} peakwidthLow=!{params.peakwidthlow_quant_library_pos_xcms} peakwidthHigh=!{params.peakwidthhigh_quant_library_pos_xcms} noise=!{params.noise_quant_library_pos_xcms} polarity=positive realFileName=!{mzMLFile} sampleClass=library
       '''
     }

   }


  }else{


         /*
          * STEP 34 - feature detection using xcms without peak picking
          */


    process process_masstrace_detection_library_pos_xcms_noncentroided{
      tag "$name"
      publishDir "${params.outdir}/process_masstrace_detection_library_pos_xcms", mode: 'copy'
      stageInMode 'copy'
      // container '${computations.docker_masstrace_detection_library_pos_xcms}'

      input:
      file mzMLFile from quant_library_mzml_files_pos
//      each file(phenotype_file) from phenotype_design_library_pos

      output:
      file "${mzMLFile.baseName}.rdata" into annotation_rdata_library_pos_camera

      shell:
      '''
  /usr/local/bin/findPeaks.r input=!{mzMLFile} output=!{mzMLFile.baseName}.rdata ppm=!{params.masstrace_ppm_library_pos_xcms} peakwidthLow=!{params.peakwidthlow_quant_library_pos_xcms} peakwidthHigh=!{params.peakwidthhigh_quant_library_pos_xcms} noise=!{params.noise_quant_library_pos_xcms} polarity=positive realFileName=!{mzMLFile} sampleClass=library
      '''
    }
  }



       /*
        * STEP 34 - convert xcms to camera
        */


  process  process_annotate_peaks_library_pos_camera{
    tag "$name"
    publishDir "${params.outdir}/process_annotate_peaks_library_pos_camera", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_annotate_peaks_library_pos_camera}'

    input:
    file rdata_files from annotation_rdata_library_pos_camera

  output:
  file "${rdata_files.baseName}.rdata" into group_rdata_library_pos_camera

    shell:
      '''
  	/usr/local/bin/xsAnnotate.r  input=!{rdata_files} output=!{rdata_files.baseName}.rdata
  	'''
  }

  /*
   * STEP 35 - group peaks using FWHM
   */

  process  process_group_peaks_library_pos_camera{
    tag "$name"
    publishDir "${params.outdir}/process_group_peaks_library_pos_camera", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_group_peaks_library_pos_camera}'

    input:
    file rdata_files from group_rdata_library_pos_camera

  output:
  file "${rdata_files.baseName}.rdata" into findaddcuts_rdata_library_pos_camera

    shell:
      '''
  	/usr/local/bin/groupFWHM.r input=!{rdata_files} output=!{rdata_files.baseName}.rdata sigma=!{params.sigma_group_library_pos_camera} perfwhm=!{params.perfwhm_group_library_pos_camera} intval=!{params.intval_group_library_pos_camera}
  	'''
  }

  /*
   * STEP 36 - find addcuts for the library
   */

  process  process_find_addcuts_library_pos_camera{
    tag "$name"
    publishDir "${params.outdir}/process_find_addcuts_library_pos_camera", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_find_addcuts_library_pos_camera}'

    input:
    file rdata_files from findaddcuts_rdata_library_pos_camera

  output:
  file "${rdata_files.baseName}.rdata" into findisotopes_rdata_library_pos_camera

    shell:
      '''
  	/usr/local/bin/findAdducts.r input=!{rdata_files} output=!{rdata_files.baseName}.rdata ppm=!{params.ppm_findaddcuts_library_pos_camera} polarity=!{params.polarity_findaddcuts_library_pos_camera}
  	'''
  }

  /*
   * STEP 37 - find isotopes for the library
   */

  process  process_find_isotopes_library_pos_camera{
    tag "$name"
    publishDir "${params.outdir}/process_find_isotopes_library_pos_camera", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_find_isotopes_library_pos_camera}'

    input:
    file rdata_files from findisotopes_rdata_library_pos_camera

  output:
  file "${rdata_files.baseName}.rdata" into mapmsmstocamera_rdata_library_pos_camera,mapmsmstoparam_rdata_library_pos_camera_tmp, prepareoutput_rdata_library_pos_camera_cfmid

    shell:
      '''
  	/usr/local/bin/findIsotopes.r input=!{rdata_files} output=!{rdata_files.baseName}.rdata maxcharge=!{params.maxcharge_findisotopes_library_pos_camera}
  	'''
  }



  /*
   * STEP 38 - read ms2 data for the library
   */

  process  process_read_MS2_library_pos_msnbase{
    tag "$name"
    publishDir "${params.outdir}/process_read_MS2_library_pos_msnbase", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_read_MS2_library_pos_msnbase}'

    input:
    file mzMLFile from id_library_mzml_files_pos

  output:
  file "${mzMLFile.baseName}_ReadMsmsLibrary.rdata" into mapmsmstocamera_rdata_library_pos_msnbase

    shell:
    '''
    /usr/local/bin/readMS2MSnBase.r input=!{mzMLFile} output=!{mzMLFile.baseName}_ReadMsmsLibrary.rdata inputname=!{mzMLFile.baseName}
    '''
  }


    /*
     * STEP 39 - map ions to mass traces in the library
     */

     mapmsmstocamera_rdata_library_pos_camera.map { file -> tuple(file.baseName, file) }.set { ch1mapmsmsLibrary_pos }

        mapmsmstocamera_rdata_library_pos_msnbase.map { file -> tuple(file.baseName.replaceAll(/_ReadMsmsLibrary/,""), file) }.set { ch2mapmsmsLibrary_pos }

mapmsmstocamera_rdata_library_pos_camerams2=ch1mapmsmsLibrary_pos.join(ch2mapmsmsLibrary_pos,by:0)


  process  process_mapmsms_tocamera_library_pos_msnbase{
    tag "$name"
    publishDir "${params.outdir}/process_mapmsms_tocamera_library_pos_msnbase", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_mapmsms_tocamera_library_pos_msnbase}'

    input:
    set val(name), file(rdata_files_ms1), file(rdata_files_ms2) from mapmsmstocamera_rdata_library_pos_camerams2
    //file rdata_files_ms2 from mapmsmstocamera_rdata_library_pos_msnbase.collect()
    //file rdata_files_ms1 from mapmsmstocamera_rdata_library_pos_camera

  output:
  file "${rdata_files_ms1.baseName}_MapMsms2Camera_library_pos.rdata" into createlibrary_rdata_library_pos_msnbase_tmp

  //  script:
    //def input_args = rdata_files_ms2.collect{ "$it" }.join(",")
    shell:
    """
    /usr/local/bin/mapMS2ToCamera.r inputCAMERA=!{rdata_files_ms1} inputMS2=!{rdata_files_ms2} output=!{rdata_files_ms1.baseName}_MapMsms2Camera_library_pos.rdata ppm=!{params.ppm_mapmsmstocamera_library_pos_msnbase} rt=!{params.rt_mapmsmstocamera_library_pos_msnbase}
    """
  }

  mapmsmstoparam_rdata_library_pos_camera_tmp.map { file -> tuple(file.baseName, file) }.set { ch1CreateLibrary }
  createlibrary_rdata_library_pos_msnbase_tmp.map { file -> tuple(file.baseName.replaceAll(/_MapMsms2Camera_library_pos/,""), file) }.set { ch2CreateLibrary }

  msmsandquant_rdata_library_pos_camera=ch1CreateLibrary.join(ch2CreateLibrary,by:0)

  /*
   * STEP 40 - charaztrize the library
   */


  process  process_create_library_pos_msnbase{
    tag "$name"
    publishDir "${params.outdir}/process_create_library_pos_msnbase", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_create_library_pos_msnbase}'

    input:
  set val(name), file(rdata_camera), file(ms2_data) from msmsandquant_rdata_library_pos_camera
  each file(library_desc) from library_description_pos

  output:
  file "${rdata_camera.baseName}.csv" into collectlibrary_rdata_library_pos_msnbase

    shell:
      '''
  	mkdir out
  	/usr/local/bin/createLibrary.r inputCAMERA=!{rdata_camera} inputMS2=!{ms2_data} output=!{rdata_camera.baseName}.csv inputLibrary=!{library_desc}  rawFileName=!{params.raw_file_name_preparelibrary_pos_msnbase}   compundID=!{params.compund_id_preparelibrary_pos_msnbase}   compoundName=!{params.compound_name_preparelibrary_pos_msnbase}  mzCol=!{params.mz_col_preparelibrary_pos_msnbase} whichmz=!{params.which_mz_preparelibrary_pos_msnbase}

  	'''
  }

  /*
   * STEP 41 - collect the library files
   */


  process  process_collect_library_pos_msnbase{
    tag "$name"
    publishDir "${params.outdir}/process_collect_library_pos_msnbase", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_collect_library_pos_msnbase}'

    input:
  file rdata_files from collectlibrary_rdata_library_pos_msnbase.collect()

  output:
  file "library_pos.csv" into librarysearchengine_rdata_library_pos_msnbase

    script:
    def aggregatecdlibrary = rdata_files.collect{ "$it" }.join(",")

      """
  	/usr/local/bin/collectLibrary.r inputs=$aggregatecdlibrary realNames=$aggregatecdlibrary output=library_pos.csv
  	"""
  }

  /*
   * STEP 42 - clean the adducts from the library
   */

process process_remove_adducts_library_pos_msnbase{
  tag "$name"
  publishDir "${params.outdir}/process_remove_adducts_library_pos_msnbase", mode: 'copy'
  stageInMode 'copy'
  // container '${computations.docker_remove_adducts_library_pos_msnbase}'

  input:
file txt_files from addcutremove_txt_pos_msnbase.collect()

output:
file "*.zip" into librarysearchengine_txt_pos_msnbase_tmp

script:
  """
  #!/usr/bin/env Rscript

  Files<-list.files(,pattern = "txt",full.names=T)
  FilesTMP<-sapply(strsplit(split = "_",fixed = T,x = basename(Files)),function(x){paste(x[-1],collapse = "_")})
  FileDub<-Files[duplicated(FilesTMP)]
for(x in FileDub)
{
  file.remove(x)
}
zip::zip(zipfile="mappedtometfrag_pos.zip",files=list.files(pattern="txt"))
  """
}

  librarysearchengine_txt_pos_msnbase=librarysearchengine_txt_pos_msnbase_tmp.flatten()

  /*
   * STEP 43 - do the search using library
   */

  process  process_search_engine_library_pos_msnbase_nolibcharac{
    tag "$name"
    publishDir "${params.outdir}/process_search_engine_library_pos_msnbase", mode: 'copy'
    // container '${computations.docker_search_engine_library_pos_msnbase}'

    input:
    file parameters from librarysearchengine_txt_pos_msnbase
    each file(libraryFile) from librarysearchengine_rdata_library_pos_msnbase

  output:
  file "aggregated_identification_library_pos.csv" into library_tsv_pos_passatutto

    shell:
    '''
    /usr/local/bin/librarySearchEngine.r -l !{libraryFile} -i !{parameters} -out aggregated_identification_library_pos.csv -th "-1" -im pos -ts Scoredotproduct -rs 1000 -ncore !{params.ncore_searchengine_library_pos_msnbase}
sed -i '/^$/d' aggregated_identification_library_pos.csv

    '''
  }
}else{

  /*
   * STEP 44 - do the search using library
   */

  process  process_search_engine_library_pos_msnbase_libcharac{
    tag "$name"
    publishDir "${params.outdir}/process_search_engine_library_pos_msnbase", mode: 'copy'
    // container '${computations.docker_search_engine_library_pos_msnbase}'

    input:
    file parameters from librarysearchengine_txt_pos_msnbase
    each file(libraryFile) from library_charactrization_file_pos

  output:
  file "aggregated_identification_library_pos.csv" into library_tsv_pos_passatutto

    shell:
    '''
    /usr/local/bin/librarySearchEngine.r -l !{libraryFile} -i !{parameters} -out aggregated_identification_library_pos.csv -th "-1" -im pos -ts Scoredotproduct -rs 1000 -ncore !{params.ncore_searchengine_library_pos_msnbase}

    sed -i '/^$/d' aggregated_identification_library_pos.csv

    '''
  }

}

/*
 * STEP 45 - calculate pep for the library hits
 */

process process_pepcalculation_library_pos_passatutto{
  tag "$name"
  publishDir "${params.outdir}/process_pepcalculation_library_pos_passatutto", mode: 'copy'
  // container '${computations.library_pepcalculation_library_pos_passatutto'

  input:
  file identification_result from library_tsv_pos_passatutto

output:
file "pep_identification_library_pos.csv" into library_tsv_pos_output

shell:
  '''

if [ -s !{identification_result} ]
then
/usr/local/bin/metfragPEP.r input=!{identification_result} score=score output=pep_identification_library_pos.csv readTable=T
else
touch pep_identification_library_pos.csv
fi

'''

}


/*
 * STEP 46 - output the library results
 */


process  process_output_quantid_pos_camera_library{
  tag "$name"
  publishDir "${params.outdir}/process_output_quantid_pos_camera_library", mode: 'copy'
  stageInMode 'copy'
  // container '${computations.docker_output_quantid_pos_camera_library}'

  input:
  file phenotype_file from phenotype_design_pos_library
  file camera_input_quant from prepareoutput_rdata_pos_camera_library
  file library_input_identification from library_tsv_pos_output

output:
file "*.txt" into library_pos_finished
  shell:
'''
if [ -s !{library_input_identification} ]
then
	/usr/local/bin/prepareOutput.r inputcamera=!{camera_input_quant} inputscores=!{library_input_identification} inputpheno=!{phenotype_file} ppm=!{params.ppm_output_pos_camera} rt=!{params.rt_output_pos_camera} higherTheBetter=true scoreColumn=score impute=!{params.impute_output_pos_camera} typeColumn=!{params.type_column_output_pos_camera} selectedType=!{params.selected_type_output_pos_camera} rename=!{params.rename_output_pos_camera} renameCol=!{params.rename_col_output_pos_camera} onlyReportWithID=!{params.only_report_with_id_output_pos_camera} combineReplicate=!{params.combine_replicate_output_pos_camera} combineReplicateColumn=!{params.combine_replicate_column_output_pos_camera} log=!{params.log_output_pos_camera} sampleCoverage=!{params.sample_coverage_output_pos_camera} outputPeakTable=peaktablePOSout_pos_library.txt outputVariables=varsPOSout_pos_library.txt outputMetaData=metadataPOSout_pos_library.txt Ifnormalize=!{params.normalize_output_pos_camera}
  else
  /usr/local/bin/prepareOutput.r inputcamera=!{camera_input_quant} inputpheno=!{phenotype_file} ppm=!{params.ppm_output_pos_camera} rt=!{params.rt_output_pos_camera} higherTheBetter=true scoreColumn=score impute=!{params.impute_output_pos_camera} typeColumn=!{params.type_column_output_pos_camera} selectedType=!{params.selected_type_output_pos_camera} rename=!{params.rename_output_pos_camera} renameCol=!{params.rename_col_output_pos_camera} onlyReportWithID=!{params.only_report_with_id_output_pos_camera} combineReplicate=!{params.combine_replicate_output_pos_camera} combineReplicateColumn=!{params.combine_replicate_column_output_pos_camera} log=!{params.log_output_pos_camera} sampleCoverage=!{params.sample_coverage_output_pos_camera} outputPeakTable=peaktablePOSout_pos_library.txt outputVariables=varsPOSout_pos_library.txt outputMetaData=metadataPOSout_pos_library.txt Ifnormalize=!{params.normalize_output_pos_camera}

  fi


  '''
}

}

}else{

  /*
   * STEP 47 - output the results for no identification
   */
  process  process_output_quantid_pos_camera_noid{
    tag "$name"
    publishDir "${params.outdir}/process_output_quantid_pos_camera_noid", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_output_quantid_pos_camera_noid}'

    input:
    file phenotype_file from phenotype_design_pos_noid
    file camera_input_quant from prepareoutput_rdata_pos_camera_noid

  output:
  file "*.txt" into noid_pos_finished
    shell:
    '''
  	/usr/local/bin/prepareOutput.r inputcamera=!{camera_input_quant} inputpheno=!{phenotype_file} ppm=!{params.ppm_output_pos_camera} rt=!{params.rt_output_pos_camera} higherTheBetter=true scoreColumn=score impute=!{params.impute_output_pos_camera} typeColumn=!{params.type_column_output_pos_camera} selectedType=!{params.selected_type_output_pos_camera} rename=!{params.rename_output_pos_camera} renameCol=!{params.rename_col_output_pos_camera} onlyReportWithID=!{params.only_report_with_id_output_pos_camera} combineReplicate=!{params.combine_replicate_output_pos_camera} combineReplicateColumn=!{params.combine_replicate_column_output_pos_camera} log=!{params.log_output_pos_camera} sampleCoverage=!{params.sample_coverage_output_pos_camera} outputPeakTable=peaktablePOSout_POS_noid.txt outputVariables=varsPOSout_pos_noid.txt outputMetaData=metadataPOSout_pos_noid.txt Ifnormalize=!{params.normalize_output_pos_camera}
  	'''
  }

}

}



/*
* for negative data if specified by the user
*/





if(params.type_of_ionization in (["neg","both"]))
{

  /*
   * STEP 48 - PeakPickerHiRes
   */
  if(params.need_centroiding==true)
  {
    process process_peak_picker_neg_openms {
        tag "$name"
        publishDir "${params.outdir}/process_peak_picker_neg_openms", mode: 'copy'
        stageInMode 'copy'
        // container '${computations.docker_peak_picker_neg_openms}'

        input:
        file mzMLFile from quant_mzml_files_neg
        each file(setting_file) from peakpicker_ini_file_neg_openms

        output:
        file "${mzMLFile}" into masstrace_detection_process_neg

        shell:
        '''
        PeakPickerHiRes -in !{mzMLFile} -out !{mzMLFile} -ini !{setting_file}
        '''
    }

    /*
     * STEP 49 - output the results for no identification
     */
   if(params.quantification_openms_xcms_neg=="openms")
   {
     process process_masstrace_detection_neg_openms {
         tag "$name"
         publishDir "${params.outdir}/process_masstrace_detection_neg_openms", mode: 'copy'
         stageInMode 'copy'
         // container '${computations.docker_masstrace_detection_neg_openms}'

         input:
         file mzMLFile from masstrace_detection_process_neg
         each file(setting_file) from featurefinder_ini_neg_openms

         output:
         file "${mzMLFile.baseName}.featureXML" into openms_to_xcms_conversion

         shell:
         '''
         FeatureFinderMetabo -in !{mzMLFile} -out !{mzMLFile.baseName}.featureXML -ini !{setting_file}
         '''
     }
     /*
      * STEP 50 - convert openms to xcms
      */
     process process_openms_to_xcms_conversion_neg {
         tag "$name"
         publishDir "${params.outdir}/process_masstrace_detection_neg_openms", mode: 'copy'
         stageInMode 'copy'
         // container '${computations.docker_openms_to_xcms_conversion}'

         input:
         file mzMLFile from openms_to_xcms_conversion
         each file(phenotype_file) from phenotype_design_neg

         output:
         file "${mzMLFile.baseName}.featureXML" into collect_rdata_neg_xcms

         shell:
         '''
          /usr/local/bin/featurexmlToCamera.r input=!{mzMLFile} realFileName=!{mzMLFile} polarity=negative output=!{mzMLFile.baseName}.rdata phenoFile=!{phenotype_file} phenoDataColumn=!{params.phenodatacolumn_quant_neg} sampleClass=!{params.sampleclass_quant_neg_xcms} changeNameTO=!{mzMLFile.baseName}.mzML

         '''
     }

   }else{
     /*
      * STEP 51 - feature detection by xcms
      */
     process process_masstrace_detection_neg_xcms_centroided{
       tag "$name"
       publishDir "${params.outdir}/process_masstrace_detection_neg_xcms", mode: 'copy'
       stageInMode 'copy'
       // container '${computations.docker_masstrace_detection_neg_xcms}'

       input:
       file mzMLFile from masstrace_detection_process_neg
       each file(phenotype_file) from phenotype_design_neg

       output:
       file "${mzMLFile.baseName}.rdata" into collect_rdata_neg_xcms

       shell:
       '''
	/usr/local/bin/findPeaks.r input=!{mzMLFile} output=!{mzMLFile.baseName}.rdata ppm=!{params.masstrace_ppm_neg_xcms} peakwidthLow=!{params.peakwidthlow_quant_neg_xcms} peakwidthHigh=!{params.peakwidthhigh_quant_neg_xcms} noise=!{params.noise_quant_neg_xcms} polarity=negative realFileName=!{mzMLFile} phenoFile=!{phenotype_file} phenoDataColumn=!{params.phenodatacolumn_quant_neg} sampleClass=!{params.sampleclass_quant_neg_xcms}
       '''
     }

   }


  }else{
    /*
     * STEP 51 - feature detection by xcms
     */
    process process_masstrace_detection_neg_xcms_noncentroided{
      tag "$name"
      publishDir "${params.outdir}/process_masstrace_detection_neg_xcms", mode: 'copy'
      stageInMode 'copy'
      // container '${computations.docker_masstrace_detection_neg_xcms}'

      input:
      file mzMLFile from quant_mzml_files_neg
      each file(phenotype_file) from phenotype_design_neg

      output:
      file "${mzMLFile.baseName}.rdata" into collect_rdata_neg_xcms

      shell:
      '''
 /usr/local/bin/findPeaks.r input=!{mzMLFile} output=!{mzMLFile.baseName}.rdata ppm=!{params.masstrace_ppm_neg_xcms} peakwidthLow=!{params.peakwidthlow_quant_neg_xcms} peakwidthHigh=!{params.peakwidthhigh_quant_neg_xcms} noise=!{params.noise_quant_neg_xcms} polarity=negative realFileName=!{mzMLFile} phenoFile=!{phenotype_file} phenoDataColumn=!{params.phenodatacolumn_quant_neg} sampleClass=!{params.sampleclass_quant_neg_xcms}
      '''
    }
  }
  /*
   * STEP 52 - collect xcms objects into a hyper object
   */

  process  process_collect_rdata_neg_xcms{
    tag "$name"
    publishDir "${params.outdir}/process_collect_rdata_neg_xcms", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_collect_rdata_neg_xcms}'

    input:
    file rdata_files from collect_rdata_neg_xcms.collect()

  output:
  file "collection_neg.rdata" into group_peaks_neg_N1_xcms

  script:
    def inputs_aggregated = rdata_files.collect{ "$it" }.join(",")
  shell:
     """
  	nextFlowDIR=\$PWD
  	/usr/local/bin/xcmsCollect.r input=$inputs_aggregated output=collection_neg.rdata
  	"""
  }

  /*
   * STEP 53 - link the mass traces across the samples
   */
  process  process_group_peaks_neg_N1_xcms{
    tag "$name"
    publishDir "${params.outdir}/process_group_peaks_neg_N1_xcms", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_group_peaks_neg_N1_xcms}'

    input:
    file rdata_files from group_peaks_neg_N1_xcms

  output:
  file "groupN1_neg.rdata" into align_rdata_neg_xcms

    shell:
      '''
  	/usr/local/bin/group.r input=!{rdata_files} output=groupN1_neg.rdata bandwidth=!{params.bandwidth_group_N1_neg_xcms} mzwid=!{params.mzwid_group_N1_neg_xcms}
  	'''
  }




     /*
      * STEP 54 - do RT correction
      */
  process  process_align_peaks_neg_xcms{
    tag "$name"
    publishDir "${params.outdir}/process_align_peaks_neg_xcms", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_align_peaks_neg_xcms}'


    input:
    file rdata_files from align_rdata_neg_xcms

  output:
  file "RTcorrected_neg.rdata" into group_peaks_neg_N2_xcms

    shell:
      '''
  	/usr/local/bin/retCor.r input=!{rdata_files} output=RTcorrected_neg.rdata method=!{params.method_align_N1_neg_xcms}

  	'''
  }


   /*
    * STEP 55 - do another round of grouping
    */
  process  process_group_peaks_neg_N2_xcms{
    tag "$name"
    publishDir "${params.outdir}/process_group_peaks_neg_N2_xcms", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_group_peaks_neg_N2_xcms}'

    input:
    file rdata_files from group_peaks_neg_N2_xcms

  output:
  file "groupN2_neg.rdata" into temp_unfiltered_channel_neg_1

    shell:
      '''
  	/usr/local/bin/group.r input=!{rdata_files} output=groupN2_neg.rdata bandwidth=!{params.bandwidth_group_N2_neg_xcms} mzwid=!{params.mzwid_group_N2_neg_xcms}
  	'''
  }

  /*
   * STEP 56 - noise filtering by using blank samples, if selected by the users
   */


if(params.blank_filter_neg)
{
  blankfilter_rdata_neg_xcms=temp_unfiltered_channel_neg_1

  process  process_blank_filter_neg_xcms{
    tag "$name"
    publishDir "${params.outdir}/process_blank_filter_neg_xcms", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_blank_filter_neg_xcms}'

    input:
    file rdata_files from blankfilter_rdata_neg_xcms

  output:
  file "blankFiltered_neg.rdata" into temp_unfiltered_channel_neg_2

    shell:
      '''
	/usr/local/bin/blankfilter.r input=!{rdata_files} output=blankFiltered_neg.rdata method=!{params.method_blankfilter_neg_xcms} blank=!{params.blank_blankfilter_neg_xcms} sample=!{params.sample_blankfilter_neg_xcms} rest=!{params.rest_blankfilter_neg_xcms}
      '''
  }
}else{
temp_unfiltered_channel_neg_2=temp_unfiltered_channel_neg_1
}


/*
 * STEP 57 - noise filtering by using dilution samples, if selected by the users
 */

if(params.dilution_filter_neg==true)
{
  dilutionfilter_rdata_neg_xcms=temp_unfiltered_channel_neg_2
  process  process_dilution_filter_neg_xcms{
    tag "$name"
    publishDir "${params.outdir}/process_dilution_filter_neg_xcms", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_dilution_filter_neg_xcms}'

    input:
    file rdata_files from dilutionfilter_rdata_neg_xcms

  output:
  file "dilutionFiltered_neg.rdata" into temp_unfiltered_channel_neg_3

    shell:
      '''
	/usr/local/bin/dilutionfilter.r input=!{rdata_files} output=dilutionFiltered_neg.rdata Corto=!{params.corto_dilutionfilter_neg_xcms} dilution=!{params.dilution_dilutionfilter_neg_xcms} pvalue=!{params.pvalue_dilutionfilter_neg_xcms} corcut=!{params.corcut_dilutionfilter_neg_xcms} abs=!{params.abs_dilutionfilter_neg_xcms}
      '''
  }
}else{

temp_unfiltered_channel_neg_3=temp_unfiltered_channel_neg_2
}

/*
 * STEP 58 - noise filtering by using QC samples, if selected by the users
 */

if(params.cv_filter_neg==true)
{
  cvfilter_rdata_neg_xcms=temp_unfiltered_channel_neg_3
  process  process_cv_filter_neg_xcms{
    tag "$name"
    publishDir "${params.outdir}/process_cv_filter_neg_xcms", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_cv_filter_neg_xcms}'

    input:
    file rdata_files from cvfilter_rdata_neg_xcms

  output:
  file "cvFiltered_neg.rdata" into temp_unfiltered_channel_neg_4

    shell:
      '''
    /usr/local/bin/cvfilter.r input=!{rdata_files} output=cvFiltered_neg.rdata qc=!{params.qc_cvfilter_neg_xcms} cvcut=!{params.cvcut_cvfilter_neg_xcms}
    '''
  }
}else{
temp_unfiltered_channel_neg_4=temp_unfiltered_channel_neg_3
}

annotation_rdata_neg_camera=temp_unfiltered_channel_neg_4

/*
 * STEP 59 - convert xcms object to CAMERA object
 */

process  process_annotate_peaks_neg_camera{
  tag "$name"
  publishDir "${params.outdir}/process_annotate_peaks_neg_camera", mode: 'copy'
  stageInMode 'copy'
  // container '${computations.docker_annotate_peaks_neg_camera}'

  input:
  file rdata_files from annotation_rdata_neg_camera

output:
file "CameraAnnotatePeaks_neg.rdata" into group_rdata_neg_camera

  shell:
    '''
	/usr/local/bin/xsAnnotate.r input=!{rdata_files} output=CameraAnnotatePeaks_neg.rdata
	'''
}


/*
 * STEP 60 - cgroup the peaks based on their overlap FWHM
 */

process  process_group_peaks_neg_camera{
  tag "$name"
  publishDir "${params.outdir}/process_group_peaks_neg_camera", mode: 'copy'
  stageInMode 'copy'
  // container '${computations.docker_group_peaks_neg_camera}'

  input:
  file rdata_files from group_rdata_neg_camera

output:
file "CameraGroup_neg.rdata" into findaddcuts_rdata_neg_camera

  shell:
    '''
	/usr/local/bin/groupFWHM.r input=!{rdata_files} output=CameraGroup_neg.rdata sigma=!{params.sigma_group_neg_camera} perfwhm=!{params.perfwhm_group_neg_camera} intval=!{params.intval_group_neg_camera}
	'''
}
/*
 * STEP 61 - find adducts
 */

process  process_find_addcuts_neg_camera{
  tag "$name"
  publishDir "${params.outdir}/process_find_addcuts_neg_camera", mode: 'copy'
  stageInMode 'copy'
  // container '${computations.docker_find_addcuts_neg_camera}'

  input:
  file rdata_files from findaddcuts_rdata_neg_camera

output:
file "CameraFindAdducts_neg.rdata" into findisotopes_rdata_neg_camera

  shell:
    '''
	/usr/local/bin/findAdducts.r input=!{rdata_files} output=CameraFindAdducts_neg.rdata ppm=!{params.ppm_findaddcuts_neg_camera} polarity=!{params.polarity_findaddcuts_neg_camera}
	'''
}

/*
 * STEP 62 - find isotopes
 */

process  process_find_isotopes_neg_camera{
  tag "$name"
  publishDir "${params.outdir}/process_find_isotopes_neg_camera", mode: 'copy'
  stageInMode 'copy'
  // container '${computations.docker_find_isotopes_neg_camera}'

  input:
  file rdata_files from findisotopes_rdata_neg_camera

output:
file "CameraFindIsotopes_neg.rdata" into mapmsmstocamera_rdata_neg_camera,mapmsmstoparam_rdata_neg_camera,prepareoutput_rdata_neg_camera_csifingerid, prepareoutput_rdata_neg_camera_cfmid, prepareoutput_rdata_neg_camera_metfrag, prepareoutput_rdata_neg_camera_library, prepareoutput_rdata_neg_camera_noid

  shell:
    '''
	/usr/local/bin/findIsotopes.r input=!{rdata_files} output=CameraFindIsotopes_neg.rdata maxcharge=!{params.maxcharge_findisotopes_neg_camera}
	'''
}

/*
* Identification starts here
* We the MSMS data need to be read and convered to parameters
*/




if(params.perform_identification==true)
{

    /*
     * STEP 63 - read MSMS data
     */

  process  process_read_MS2_neg_msnbase{
    tag "$name"
    publishDir "${params.outdir}/process_read_MS2_neg_msnbase", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_read_MS2_neg_msnbase}'

    input:
    file mzMLFile from id_mzml_files_neg

  output:
  file "${mzMLFile.baseName}.rdata" into mapmsmstocamera_rdata_neg_msnbase

    shell:
    '''
  	/usr/local/bin/readMS2MSnBase.r input=!{mzMLFile} output=!{mzMLFile.baseName}.rdata inputname=!{mzMLFile.baseName}
  	'''
  }

  /*
   * STEP 64 - map MS2 ions to camera features
   */
  process  process_mapmsms_tocamera_neg_msnbase{
    tag "$name"
    publishDir "${params.outdir}/process_mapmsms_tocamera_neg_msnbase", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_mapmsms_tocamera_neg_msnbase}'

    input:
    file rdata_files_ms2 from mapmsmstocamera_rdata_neg_msnbase.collect()
    file rdata_files_ms1 from mapmsmstocamera_rdata_neg_camera

  output:
  file "MapMsms2Camera_neg.rdata" into mapmsmstoparam_rdata_neg_msnbase

  script:
    def input_args = rdata_files_ms2.collect{ "$it" }.join(",")

   shell:
    """
  	/usr/local/bin/mapMS2ToCamera.r inputCAMERA=!{rdata_files_ms1} inputMS2=$input_args output=MapMsms2Camera_neg.rdata ppm=!{params.ppm_mapmsmstocamera_neg_msnbase} rt=!{params.rt_mapmsmstocamera_neg_msnbase}

  	"""
  }


    /*
     * STEP 65 - convert MS2 ions to parameters for search
     */
  process  process_mapmsms_toparam_neg_msnbase{
    tag "$name"
    publishDir "${params.outdir}/process_mapmsms_toparam_neg_msnbase", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_mapmsms_toparam_neg_msnbase}'

    input:
    file rdata_files_ms2 from mapmsmstoparam_rdata_neg_msnbase
    file rdata_files_ms1 from mapmsmstoparam_rdata_neg_camera

  output:
  file "*.txt" into csifingerid_txt_neg_msnbase, addcutremove_txt_neg_msnbase, metfrag_txt_neg_msnbase, cfmidin_txt_neg_msnbase
    shell:
      '''
  	mkdir out
  	/usr/local/bin/MS2ToMetFrag.r inputCAMERA=!{rdata_files_ms1} inputMS2=!{rdata_files_ms2} output=out precursorppm=!{params.precursorppm_msmstoparam_neg_msnbase} fragmentppm=!{params.fragmentppm_msmstoparam_neg_msnbase} fragmentabs=!{params.fragmentabs_msmstoparam_neg_msnbase} database=!{params.database_msmstoparam_neg_msnbase} mode=!{params.mode_msmstoparam_neg_msnbase} adductRules=!{params.adductRules_msmstoparam_neg_msnbase} minPeaks=!{params.minPeaks_msmstoparam_neg_msnbase}
    zip -r res.zip out/
  	unzip -j res.zip
  	'''
  }

/*
* we need to decide which search engine to select
* each search engine will have its own path for quantification at this stage.
* todo: implement joint search engine score so that we will have only one path to quantification.
*/

if(params.perform_identification_csifingerid==true)
{

csifingerid_txt_neg_msnbase_flatten=csifingerid_txt_neg_msnbase.flatten()

/*
 * STEP 67 - do search using CSIFingerID
 */
process  process_ms2_identification_neg_csifingerid{
  tag "$name"
  publishDir "${params.outdir}/process_ms2_identification_neg_csifingerid", mode: 'copy'
  // container '${computations.docker_ms2_identification_neg_csifingerid}'

  input:
  file parameters from csifingerid_txt_neg_msnbase_flatten

   output:
  file "${parameters.baseName}.csv" into aggregateID_csv_neg_csifingerid

  shell:
    '''
     touch !{parameters.baseName}.csv

  	/usr/local/bin/fingerID.r input=$PWD/!{parameters} database=!{params.database_csifingerid_neg_csifingerid} tryOffline=T output=$PWD/!{parameters.baseName}.csv

	'''

}

/*
 * STEP 68 - aggregate ids from CSI
 */
process  process_identification_aggregate_neg_csifingerid{
  tag "$name"
  publishDir "${params.outdir}/process_identification_aggregate_neg_csifingerid", mode: 'copy'
  // container '${computations.docker_identification_aggregate_neg_csifingerid'

  input:
  file identification_result from aggregateID_csv_neg_csifingerid.collect()

output:
file "aggregated_identification_csifingerid_neg.csv" into csifingerid_tsv_neg_passatutto

  shell:
    '''
	zip -r Csifingerid_neg.zip .
	/usr/local/bin/aggregateMetfrag.r inputs=Csifingerid_neg.zip realNames=Csifingerid_neg.zip output=aggregated_identification_csifingerid_neg.csv filetype=zip outTable=T
  sed -i '/^$/d' aggregated_identification_csifingerid_neg.csv

	'''
}

/*
 * STEP 69 - calculate pep from CSI results
 */

process process_pepcalculation_csifingerid_neg_passatutto{
  tag "$name"
  publishDir "${params.outdir}/process_pepcalculation_csifingerid_neg_passatutto", mode: 'copy'
  // container '${computations.docker_pepcalculation_csifingerid_neg_passatutto'

  input:
  file identification_result from csifingerid_tsv_neg_passatutto

output:
file "pep_identification_csifingerid_neg.csv" into csifingerid_tsv_neg_output

shell:
  '''
  if [ -s !{identification_result} ]
then
/usr/local/bin/metfragPEP.r input=!{identification_result} score=score output=pep_identification_csifingerid_neg.csv readTable=T
else
touch pep_identification_csifingerid_neg.csv

fi


'''

}

/*
 * STEP 70 - output the results
 */

process  process_output_quantid_neg_camera_csifingerid{
  tag "$name"
  publishDir "${params.outdir}/process_output_quantid_neg_camera_csifingerid", mode: 'copy'
  stageInMode 'copy'
  // container '${computations.docker_output_quantid_neg_camera_csifingerid}'

  input:
  file phenotype_file from phenotype_design_neg_csifingerid
  file camera_input_quant from prepareoutput_rdata_neg_camera_csifingerid
  file csifingerid_input_identification from csifingerid_tsv_neg_output

output:
file "*.txt" into csifingerid_neg_finished
  shell:
'''
if [ -s !{csifingerid_input_identification} ]
then
/usr/local/bin/prepareOutput.r inputcamera=!{camera_input_quant} inputscores=!{csifingerid_input_identification} inputpheno=!{phenotype_file} ppm=!{params.ppm_output_neg_camera} rt=!{params.rt_output_neg_camera} higherTheBetter=true scoreColumn=score impute=!{params.impute_output_neg_camera} typeColumn=!{params.type_column_output_neg_camera} selectedType=!{params.selected_type_output_neg_camera} rename=!{params.rename_output_neg_camera} renameCol=!{params.rename_col_output_neg_camera} onlyReportWithID=!{params.only_report_with_id_output_neg_camera} combineReplicate=!{params.combine_replicate_output_neg_camera} combineReplicateColumn=!{params.combine_replicate_column_output_neg_camera} log=!{params.log_output_neg_camera} sampleCoverage=!{params.sample_coverage_output_neg_camera} outputPeakTable=peaktableNEGout_neg_csifingerid.txt outputVariables=varsNEGout_neg_csifingerid.txt outputMetaData=metadataNEGout_neg_csifingerid.txt Ifnormalize=!{params.normalize_output_neg_camera}

else
/usr/local/bin/prepareOutput.r inputcamera=!{camera_input_quant} inputpheno=!{phenotype_file} ppm=!{params.ppm_output_neg_camera} rt=!{params.rt_output_neg_camera} higherTheBetter=true scoreColumn=score impute=!{params.impute_output_neg_camera} typeColumn=!{params.type_column_output_neg_camera} selectedType=!{params.selected_type_output_neg_camera} rename=!{params.rename_output_neg_camera} renameCol=!{params.rename_col_output_neg_camera} onlyReportWithID=!{params.only_report_with_id_output_neg_camera} combineReplicate=!{params.combine_replicate_output_neg_camera} combineReplicateColumn=!{params.combine_replicate_column_output_neg_camera} log=!{params.log_output_neg_camera} sampleCoverage=!{params.sample_coverage_output_neg_camera} outputPeakTable=peaktableNEGout_neg_csifingerid.txt outputVariables=varsNEGout_neg_csifingerid.txt outputMetaData=metadataNEGout_neg_csifingerid.txt Ifnormalize=!{params.normalize_output_neg_camera}


fi

	'''
}

}


/*
* This is for Metfrag search engine
*/


if(params.perform_identification_metfrag==true)
{
  /*
   * check whether the data base file has been provided
   */
if(params.database_msmstoparam_neg_msnbase=="LocalCSV")
{
if(params.containsKey('database_csv_files_neg_metfrag') && params.database_csv_files_neg_metfrag instanceof String){
      Channel
            .fromPath(params.database_csv_files_neg_metfrag)
            .ifEmpty { exit 1, "params.database_csv_files_neg_metfrag was empty - no input files supplied" }
            .set {database_csv_files_neg_metfrag}
} else{
  exit 1, "params.database_csv_files_neg_metfrag was not found or not defined as string! You need to set database_csv_files_neg_metfrag in conf/parameters.config to the path to a csv file containing your database"
}
}

metfrag_txt_neg_msnbase_flatten=metfrag_txt_neg_msnbase.flatten()

/*
 * STEP 71 - do identification using metfrag
 */

process  process_ms2_identification_neg_metfrag{
  tag "$name"
  publishDir "${params.outdir}/process_ms2_identification_neg_metfrag", mode: 'copy'
  // container '${computations.docker_ms2_identification_neg_metfrag}'

  input:
  file parameters from metfrag_txt_neg_msnbase_flatten
  each file(metfrag_database) from database_csv_files_neg_metfrag


   output:
  file "${parameters.baseName}.csv" into aggregateID_csv_neg_metfrag

  shell:
    '''
    touch !{parameters.baseName}.csv

   bash /usr/local/bin/run_metfrag.sh -p $PWD/!{parameters} -f $PWD/!{parameters.baseName}.csv -l "$PWD/!{metfrag_database}" -s "OfflineMetFusionScore"

	'''
}
/*
 * STEP 72 - aggregate metfrag results
 */
process  process_identification_aggregate_neg_metfrag{
  tag "$name"
  publishDir "${params.outdir}/process_identification_aggregate_neg_metfrag", mode: 'copy'
  // container '${computations.docker_identification_aggregate_neg_metfrag'

  input:
  file identification_result from aggregateID_csv_neg_metfrag.collect()

output:
file "aggregated_identification_metfrag_neg.csv" into metfrag_tsv_neg_passatutto

  shell:
    '''
	zip -r metfrag_neg.zip .
	/usr/local/bin/aggregateMetfrag.r inputs=metfrag_neg.zip realNames=metfrag_neg.zip output=aggregated_identification_metfrag_neg.csv filetype=zip outTable=T

	'''
}

/*
 * STEP 73 - calculate pep from metfrag results
 */
process process_pepcalculation_metfrag_neg_passatutto{
  tag "$name"
  publishDir "${params.outdir}/process_pepcalculation_metfrag_neg_passatutto", mode: 'copy'
  // container '${computations.docker_pepcalculation_metfrag_neg_passatutto'

  input:
  file identification_result from metfrag_tsv_neg_passatutto

output:
file "pep_identification_metfrag_neg.csv" into metfrag_tsv_neg_output

shell:
  '''
  if [ -s !{identification_result} ]
then
/usr/local/bin/metfragPEP.r input=!{identification_result} score=FragmenterScore output=pep_identification_metfrag_neg.csv readTable=T

else
touch pep_identification_metfrag_neg.csv

fi

'''

}

/*
 * STEP 74 - output metfrag results
 */

process  process_output_quantid_neg_camera_metfrag{
  tag "$name"
  publishDir "${params.outdir}/process_output_quantid_neg_camera_metfrag", mode: 'copy'
  stageInMode 'copy'
  // container '${computations.docker_output_quantid_neg_camera_metfrag}'

  input:
  file phenotype_file from phenotype_design_neg_metfrag
  file camera_input_quant from prepareoutput_rdata_neg_camera_metfrag
  file metfrag_input_identification from metfrag_tsv_neg_output

output:
file "*.txt" into metfrag_neg_finished
  shell:
'''
if [ -s !{metfrag_input_identification} ]
then

/usr/local/bin/prepareOutput.r inputcamera=!{camera_input_quant} inputscores=!{metfrag_input_identification} inputpheno=!{phenotype_file} ppm=!{params.ppm_output_neg_camera} rt=!{params.rt_output_neg_camera} higherTheBetter=true scoreColumn=FragmenterScore impute=!{params.impute_output_neg_camera} typeColumn=!{params.type_column_output_neg_camera} selectedType=!{params.selected_type_output_neg_camera} rename=!{params.rename_output_neg_camera} renameCol=!{params.rename_col_output_neg_camera} onlyReportWithID=!{params.only_report_with_id_output_neg_camera} combineReplicate=!{params.combine_replicate_output_neg_camera} combineReplicateColumn=!{params.combine_replicate_column_output_neg_camera} log=!{params.log_output_neg_camera} sampleCoverage=!{params.sample_coverage_output_neg_camera} outputPeakTable=peaktableNEGout_neg_metfrag.txt outputVariables=varsNEGout_neg_metfrag.txt outputMetaData=metadataNEGout_neg_metfrag.txt Ifnormalize=!{params.normalize_output_neg_camera}

else
/usr/local/bin/prepareOutput.r inputcamera=!{camera_input_quant} inputpheno=!{phenotype_file} ppm=!{params.ppm_output_neg_camera} rt=!{params.rt_output_neg_camera} higherTheBetter=true scoreColumn=FragmenterScore impute=!{params.impute_output_neg_camera} typeColumn=!{params.type_column_output_neg_camera} selectedType=!{params.selected_type_output_neg_camera} rename=!{params.rename_output_neg_camera} renameCol=!{params.rename_col_output_neg_camera} onlyReportWithID=!{params.only_report_with_id_output_neg_camera} combineReplicate=!{params.combine_replicate_output_neg_camera} combineReplicateColumn=!{params.combine_replicate_column_output_neg_camera} log=!{params.log_output_neg_camera} sampleCoverage=!{params.sample_coverage_output_neg_camera} outputPeakTable=peaktableNEGout_neg_metfrag.txt outputVariables=varsNEGout_neg_metfrag.txt outputMetaData=metadataNEGout_neg_metfrag.txt Ifnormalize=!{params.normalize_output_neg_camera}

fi
	'''
}

}

if(params.perform_identification_cfmid==true)
{
  /*
   * check whether the database has been provide for cfmid
   */

if(params.containsKey('database_csv_files_neg_cfmid') && params.database_csv_files_neg_cfmid instanceof String){
      Channel
            .fromPath(params.database_csv_files_neg_cfmid)
            .ifEmpty { exit 1, "params.database_csv_files_neg_cfmid was empty - no input files supplied" }
            .set {database_csv_files_neg_cfmid}
} else{
  exit 1, "params.database_csv_files_neg_cfmid was not found or not defined as string! You need to set database_csv_files_neg_cfmid in conf/parameters.config to the path to a csv file containing your database"
}

cfmid_txt_neg_msnbase_flatten=cfmidin_txt_neg_msnbase.flatten()

/*
 * STEP 75 - do search using cfmid
 */

process  process_ms2_identification_neg_cfmid{
  tag "$name"
  publishDir "${params.outdir}/process_ms2_identification_neg_cfmid", mode: 'copy'
  // container '${computations.docker_ms2_identification_neg_cfmid}'

  input:
  file parameters from cfmid_txt_neg_msnbase_flatten
  each file(cfmid_database) from database_csv_files_neg_cfmid

   output:
  file "${parameters.baseName}.csv" into aggregateID_csv_neg_cfmid


  shell:
    '''
    touch !{parameters.baseName}.csv

    /usr/local/bin/cfmid.r input=$PWD/!{parameters} realName=!{parameters} databaseFile=$PWD/!{cfmid_database}  output=$PWD/!{parameters.baseName}.csv candidate_id=!{params.candidate_id_identification_neg_cfmid} candidate_inchi_smiles=!{params.candidate_inchi_smiles_identification_neg_cfmid} candidate_mass=!{params.candidate_mass_identification_neg_cfmid} databaseNameColumn=!{params.database_name_column_identification_neg_cfmid} databaseInChIColumn=!{params.database_inchI_column_identification_neg_cfmid} scoreType=Jaccard

	'''
}

/*
 * STEP 76 - aggregate cfmid results
 */

process  process_identification_aggregate_neg_cfmid{
  tag "$name"
  publishDir "${params.outdir}/process_identification_aggregate_neg_cfmid", mode: 'copy'
  // container '${computations.docker_identification_aggregate_neg_cfmid'

  input:
  file identification_result from aggregateID_csv_neg_cfmid.collect()

output:
file "aggregated_identification_cfmid_neg.csv" into cfmid_tsv_neg_passatutto

  shell:
    '''
	zip -r cfmid_neg.zip .
	/usr/local/bin/aggregateMetfrag.r inputs=cfmid_neg.zip realNames=cfmid_neg.zip output=aggregated_identification_cfmid_neg.csv filetype=zip outTable=T

	'''
}


/*
 * STEP 77 - calculate pep based on cfmid
 */


process process_pepcalculation_cfmid_neg_passatutto{
  tag "$name"
  publishDir "${params.outdir}/process_pepcalculation_cfmid_neg_passatutto", mode: 'copy'
  // container '${computations.docker_pepcalculation_cfmid_neg_passatutto'

  input:
  file identification_result from cfmid_tsv_neg_passatutto

output:
file "pep_identification_cfmid_neg.csv" into cfmid_tsv_neg_output

shell:
  '''
  if [ -s !{identification_result} ]
then
/usr/local/bin/metfragPEP.r input=!{identification_result} score=Jaccard_Score output=pep_identification_cfmid_neg.csv readTable=T

else
touch pep_identification_cfmid_neg.csv
fi



'''

}

/*
 * STEP 78 - output the results based on cfmid
 */

process  process_output_quantid_neg_camera_cfmid{
  tag "$name"
  publishDir "${params.outdir}/process_output_quantid_neg_camera_cfmid", mode: 'copy'
  stageInMode 'copy'
  // container '${computations.docker_output_quantid_neg_camera_cfmid}'

  input:
  file phenotype_file from phenotype_design_neg_cfmid
  file camera_input_quant from prepareoutput_rdata_neg_camera_cfmid
  file cfmid_input_identification from cfmid_tsv_neg_output

output:
file "*.txt" into cfmid_neg_finished
  shell:
'''
if [ -s !{cfmid_input_identification} ]
then
/usr/local/bin/prepareOutput.r inputcamera=!{camera_input_quant} inputscores=!{cfmid_input_identification} inputpheno=!{phenotype_file} ppm=!{params.ppm_output_neg_camera} rt=!{params.rt_output_neg_camera} higherTheBetter=true scoreColumn=Jaccard_Score impute=!{params.impute_output_neg_camera} typeColumn=!{params.type_column_output_neg_camera} selectedType=!{params.selected_type_output_neg_camera} rename=!{params.rename_output_neg_camera} renameCol=!{params.rename_col_output_neg_camera} onlyReportWithID=!{params.only_report_with_id_output_neg_camera} combineReplicate=!{params.combine_replicate_output_neg_camera} combineReplicateColumn=!{params.combine_replicate_column_output_neg_camera} log=!{params.log_output_neg_camera} sampleCoverage=!{params.sample_coverage_output_neg_camera} outputPeakTable=peaktableNEGout_neg_cfmid.txt outputVariables=varsNEGout_neg_cfmid.txt outputMetaData=metadataNEGout_neg_cfmid.txt Ifnormalize=!{params.normalize_output_neg_camera}

else
/usr/local/bin/prepareOutput.r inputcamera=!{camera_input_quant} inputpheno=!{phenotype_file} ppm=!{params.ppm_output_neg_camera} rt=!{params.rt_output_neg_camera} higherTheBetter=true scoreColumn=Jaccard_Score impute=!{params.impute_output_neg_camera} typeColumn=!{params.type_column_output_neg_camera} selectedType=!{params.selected_type_output_neg_camera} rename=!{params.rename_output_neg_camera} renameCol=!{params.rename_col_output_neg_camera} onlyReportWithID=!{params.only_report_with_id_output_neg_camera} combineReplicate=!{params.combine_replicate_output_neg_camera} combineReplicateColumn=!{params.combine_replicate_column_output_neg_camera} log=!{params.log_output_neg_camera} sampleCoverage=!{params.sample_coverage_output_neg_camera} outputPeakTable=peaktableNEGout_neg_cfmid.txt outputVariables=varsNEGout_neg_cfmid.txt outputMetaData=metadataNEGout_neg_cfmid.txt Ifnormalize=!{params.normalize_output_neg_camera}


fi
	'''
}

}



/*
* For internal library
*/





if(params.perform_identification_internal_library==true)
{
if(params.library_charactrized_neg==false){
  if(params.need_centroiding==true)
  {
    /*
     * STEP 79 - peakpicking for library
     */
    process process_peak_picker_library_neg_openms {
        tag "$name"
        publishDir "${params.outdir}/process_peak_picker_library_neg_openms", mode: 'copy'
        stageInMode 'copy'
        // container '${computations.docker_peak_picker_library_neg_openms}'

        input:
        file mzMLFile from quant_library_mzml_files_neg
        each file(setting_file) from peakpicker_ini_file_library_neg_openms

        output:
        file "${mzMLFile}" into masstrace_detection_process_library_neg

        shell:
        '''
        PeakPickerHiRes -in !{mzMLFile} -out !{mzMLFile} -ini !{setting_file}
        '''
    }


   if(params.quantification_openms_xcms_library_neg=="openms")
   {
     /*
      * STEP 80 - feature detection for the library by openms
      */
     process process_masstrace_detection_library_neg_openms {
         tag "$name"
         publishDir "${params.outdir}/process_masstrace_detection_library_neg_openms", mode: 'copy'
         stageInMode 'copy'
         // container '${computations.docker_masstrace_detection_library_neg_openms}'

         input:
         file mzMLFile from masstrace_detection_process_library_neg
         each file(setting_file) from featurefinder_ini_library_neg_openms

         output:
         file "${mzMLFile.baseName}.featureXML" into openms_to_xcms_conversion

         shell:
         '''
         FeatureFinderMetabo -in !{mzMLFile} -out !{mzMLFile.baseName}.featureXML -ini !{setting_file}
         '''
     }

     /*
      * STEP 81 - convert openms to xcms
      */
     process process_openms_to_xcms_conversion_centroided {
         tag "$name"
         publishDir "${params.outdir}/process_masstrace_detection_library_neg_openms", mode: 'copy'
         stageInMode 'copy'
         // container '${computations.docker_openms_to_xcms_conversion}'

         input:
         file mzMLFile from openms_to_xcms_conversion
      //   each file(phenotype_file) from phenotype_design_library_neg

         output:
         file "${mzMLFile.baseName}.featureXML" into annotation_rdata_library_neg_camera

         shell:
         '''
          /usr/local/bin/featurexmlToCamera.r input=!{mzMLFile} realFileName=!{mzMLFile} polarity=negative output=!{mzMLFile.baseName}.rdata sampleClass=library changeNameTO=!{mzMLFile.baseName}.mzML

         '''
     }

   }else{

     /*
      * STEP 82 - feature detection using xcms
      */
     process process_masstrace_detection_library_neg_xcms_noncentroided{
       tag "$name"
       publishDir "${params.outdir}/process_masstrace_detection_library_neg_xcms", mode: 'copy'
       stageInMode 'copy'
       // container '${computations.docker_masstrace_detection_library_neg_xcms}'

       input:
       file mzMLFile from masstrace_detection_process_library_neg
    //   each file(phenotype_file) from phenotype_design_library_neg

       output:
       file "${mzMLFile.baseName}.rdata" into annotation_rdata_library_neg_camera

       shell:
       '''
  /usr/local/bin/findPeaks.r input=!{mzMLFile} output=!{mzMLFile.baseName}.rdata ppm=!{params.masstrace_ppm_library_neg_xcms} peakwidthLow=!{params.peakwidthlow_quant_library_neg_xcms} peakwidthHigh=!{params.peakwidthhigh_quant_library_neg_xcms} noise=!{params.noise_quant_library_neg_xcms} polarity=negative realFileName=!{mzMLFile} sampleClass=library
       '''
     }

   }


  }else{


             /*
              * STEP 83 - feature detection using xcms without peak picking
              */

    process process_masstrace_detection_library_neg_xcms{
      tag "$name"
      publishDir "${params.outdir}/process_masstrace_detection_library_neg_xcms", mode: 'copy'
      stageInMode 'copy'
      // container '${computations.docker_masstrace_detection_library_neg_xcms}'

      input:
      file mzMLFile from quant_library_mzml_files_neg
    //  each file(phenotype_file) from phenotype_design_library_neg

      output:
      file "${mzMLFile.baseName}.rdata" into annotation_rdata_library_neg_camera

      shell:
      '''
  /usr/local/bin/findPeaks.r input=!{mzMLFile} output=!{mzMLFile.baseName}.rdata ppm=!{params.masstrace_ppm_library_neg_xcms} peakwidthLow=!{params.peakwidthlow_quant_library_neg_xcms} peakwidthHigh=!{params.peakwidthhigh_quant_library_neg_xcms} noise=!{params.noise_quant_library_neg_xcms} polarity=negative realFileName=!{mzMLFile} sampleClass=library
      '''
    }
  }

  /*
   * STEP 84 - convert xcms to camera
   */


  process  process_annotate_peaks_library_neg_camera{
    tag "$name"
    publishDir "${params.outdir}/process_annotate_peaks_library_neg_camera", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_annotate_peaks_library_neg_camera}'

    input:
    file rdata_files from annotation_rdata_library_neg_camera

  output:
  file "${rdata_files.baseName}.rdata" into group_rdata_library_neg_camera

    shell:
      '''
  	/usr/local/bin/xsAnnotate.r input=!{rdata_files} output=!{rdata_files.baseName}.rdata
  	'''
  }
  /*
   * STEP 85 - group peaks using FWHM
   */


  process  process_group_peaks_library_neg_camera{
    tag "$name"
    publishDir "${params.outdir}/process_group_peaks_library_neg_camera", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_group_peaks_library_neg_camera}'

    input:
    file rdata_files from group_rdata_library_neg_camera

  output:
  file "${rdata_files.baseName}.rdata" into findaddcuts_rdata_library_neg_camera

    shell:
      '''
  	/usr/local/bin/groupFWHM.r input=!{rdata_files} output=!{rdata_files.baseName}.rdata sigma=!{params.sigma_group_library_neg_camera} perfwhm=!{params.perfwhm_group_library_neg_camera} intval=!{params.intval_group_library_neg_camera}
  	'''
  }


    /*
     * STEP 86 - find addcuts for the library
     */


  process  process_find_addcuts_library_neg_camera{
    tag "$name"
    publishDir "${params.outdir}/process_find_addcuts_library_neg_camera", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_find_addcuts_library_neg_camera}'

    input:
    file rdata_files from findaddcuts_rdata_library_neg_camera

  output:
  file "${rdata_files.baseName}.rdata" into findisotopes_rdata_library_neg_camera

    shell:
      '''
  	/usr/local/bin/findAdducts.r input=!{rdata_files} output=!{rdata_files.baseName}.rdata ppm=!{params.ppm_findaddcuts_library_neg_camera} polarity=!{params.polarity_findaddcuts_library_neg_camera}
  	'''
  }
  /*
   * STEP 87 - find isotopes for the library
   */
  process  process_find_isotopes_library_neg_camera{
    tag "$name"
    publishDir "${params.outdir}/process_find_isotopes_library_neg_camera", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_find_isotopes_library_neg_camera}'

    input:
    file rdata_files from findisotopes_rdata_library_neg_camera

  output:
  file "${rdata_files.baseName}.rdata" into mapmsmstocamera_rdata_library_neg_camera,mapmsmstoparam_rdata_library_neg_camera_tmp, prepareoutput_rdata_library_neg_camera_cfmid

    shell:
      '''
  	/usr/local/bin/findIsotopes.r input=!{rdata_files} output=!{rdata_files.baseName}.rdata maxcharge=!{params.maxcharge_findisotopes_library_neg_camera}
  	'''
  }



  /*
   * STEP 88 - read ms2 data for the library
   */

  process  process_read_MS2_library_neg_msnbase{
    tag "$name"
    publishDir "${params.outdir}/process_read_MS2_library_neg_msnbase", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_read_MS2_library_neg_msnbase}'

    input:
    file mzMLFile from id_library_mzml_files_neg

  output:
  file "${mzMLFile.baseName}_ReadMsmsLibrary.rdata" into mapmsmstocamera_rdata_library_neg_msnbase

    shell:
    '''
    /usr/local/bin/readMS2MSnBase.r input=!{mzMLFile} output=!{mzMLFile.baseName}_ReadMsmsLibrary.rdata inputname=!{mzMLFile.baseName}
    '''
  }

  /*
   * STEP 89 - map ions to mass traces in the library
   */

   mapmsmstocamera_rdata_library_neg_camera.map { file -> tuple(file.baseName, file) }.set { ch1mapmsmsLibrary_neg }

   mapmsmstocamera_rdata_library_neg_msnbase.map { file -> tuple(file.baseName.replaceAll(/_ReadMsmsLibrary/,""), file) }.set { ch2mapmsmsLibrary_neg }

   mapmsmstocamera_rdata_library_neg_camerams2=ch1mapmsmsLibrary_neg.join(ch2mapmsmsLibrary_neg,by:0)
  process  process_mapmsms_tocamera_library_neg_msnbase{
    tag "$name"
    publishDir "${params.outdir}/process_mapmsms_tocamera_library_neg_msnbase", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_mapmsms_tocamera_library_neg_msnbase}'

    input:
    set val(name), file(rdata_files_ms1), file(rdata_files_ms2) from mapmsmstocamera_rdata_library_neg_camerams2
//    file rdata_files_ms2 from mapmsmstocamera_rdata_library_neg_msnbase.collect()
//    file rdata_files_ms1 from mapmsmstocamera_rdata_library_neg_camera

  output:
  file "${rdata_files_ms1.baseName}_MapMsms2Camera_library_neg.rdata" into createlibrary_rdata_library_neg_msnbase_tmp
//  file "MapMsms2Camera_library_neg.rdata" into createlibrary_rdata_library_neg_msnbase_tmp

//    script:
//    def input_args = rdata_files_ms2.collect{ "$it" }.join(",")
    shell:
    """
    /usr/local/bin/mapMS2ToCamera.r inputCAMERA=!{rdata_files_ms1} inputMS2=!{rdata_files_ms2} output=!{rdata_files_ms1.baseName}_MapMsms2Camera_library_neg.rdata ppm=!{params.ppm_mapmsmstocamera_library_neg_msnbase} rt=!{params.rt_mapmsmstocamera_library_neg_msnbase}
    """
  }


  /*
   * STEP 90 - charaztrize the library
   */

// join the MS2 and quantification channels
     mapmsmstoparam_rdata_library_neg_camera_tmp.map { file -> tuple(file.baseName, file) }.set { ch1CreateLibrary }
     createlibrary_rdata_library_neg_msnbase_tmp.map { file -> tuple(file.baseName.replaceAll(/_MapMsms2Camera_library_neg/,""), file) }.set { ch2CreateLibrary }

     msmsandquant_rdata_library_neg_camera=ch1CreateLibrary.join(ch2CreateLibrary,by:0)
  process  process_create_library_neg_msnbase {
    tag "$name"
    publishDir "${params.outdir}/process_create_library_neg_msnbase", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_create_library_neg_msnbase}'

    input:
  set val(name), file(rdata_camera), file(ms2_data) from msmsandquant_rdata_library_neg_camera
  each file(library_desc) from library_description_neg

  output:
  file "${rdata_camera.baseName}.csv" into collectlibrary_rdata_library_neg_msnbase

    shell:
      '''

  	mkdir out
  	/usr/local/bin/createLibrary.r inputCAMERA=!{rdata_camera} inputMS2=!{ms2_data} output=!{rdata_camera.baseName}.csv inputLibrary=!{library_desc}  rawFileName=!{params.raw_file_name_preparelibrary_neg_msnbase}   compundID=!{params.compund_id_preparelibrary_neg_msnbase}   compoundName=!{params.compound_name_preparelibrary_neg_msnbase}  mzCol=!{params.mz_col_preparelibrary_neg_msnbase} whichmz=!{params.which_mz_preparelibrary_neg_msnbase}

  	'''
  }

  /*
   * STEP 91 - collect the library files
   */
  process  process_collect_library_neg_msnbase{
    tag "$name"
    publishDir "${params.outdir}/process_collect_library_neg_msnbase", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_collect_library_neg_msnbase}'

    input:
  file rdata_files from collectlibrary_rdata_library_neg_msnbase.collect()

  output:
  file "library_neg.csv" into librarysearchengine_rdata_library_neg_msnbase

    script:
    def aggregatecdlibrary = rdata_files.collect{ "$it" }.join(",")

      """
  	/usr/local/bin/collectLibrary.r inputs=$aggregatecdlibrary realNames=$aggregatecdlibrary output=library_neg.csv
  	"""
  }
  /*
   * STEP 92 - clean the adducts from the library
   */


process process_remove_adducts_library_neg_msnbase{
  tag "$name"
  publishDir "${params.outdir}/process_remove_adducts_library_neg_msnbase", mode: 'copy'
  stageInMode 'copy'
  // container '${computations.docker_remove_adducts_library_neg_msnbase}'

  input:
file txt_files from addcutremove_txt_neg_msnbase.collect()

output:
file "*.zip" into librarysearchengine_txt_neg_msnbase_tmp

script:
  """
  #!/usr/bin/env Rscript

  Files<-list.files(,pattern = "txt",full.names=T)
  FilesTMP<-sapply(strsplit(split = "_",fixed = T,x = basename(Files)),function(x){paste(x[-1],collapse = "_")})
  FileDub<-Files[duplicated(FilesTMP)]
for(x in FileDub)
{
  file.remove(x)
}
zip::zip(zipfile="mappedtometfrag_neg.zip",files=list.files(pattern="txt"))
  """
}

  librarysearchengine_txt_neg_msnbase=librarysearchengine_txt_neg_msnbase_tmp.flatten()

  /*
   * STEP 93 - do the search using library
   */


  process  process_search_engine_library_neg_msnbase_nonlibcharac{
    tag "$name"
    publishDir "${params.outdir}/process_search_engine_library_neg_msnbase", mode: 'copy'
    // container '${computations.docker_search_engine_library_neg_msnbase}'

    input:
    file parameters from librarysearchengine_txt_neg_msnbase
    each file(libraryFile) from librarysearchengine_rdata_library_neg_msnbase

  output:
  file "aggregated_identification_library_neg.csv" into library_tsv_neg_passatutto

    shell:
    '''
    /usr/local/bin/librarySearchEngine.r -l !{libraryFile} -i !{parameters} -out aggregated_identification_library_neg.csv -th "-1" -im neg -ts Scoredotproduct -rs 1000 -ncore !{params.ncore_searchengine_library_neg_msnbase}
sed -i '/^$/d' aggregated_identification_library_neg.csv
    '''
  }
}else{

  /*
   * STEP 93 - do the search using library
   */

  process  process_search_engine_library_neg_msnbase{
    tag "$name"
    publishDir "${params.outdir}/process_search_engine_library_neg_msnbase", mode: 'copy'
    // container '${computations.docker_search_engine_library_neg_msnbase}'

    input:
    file parameters from librarysearchengine_txt_neg_msnbase
    each file(libraryFile) from library_charactrization_file_neg

  output:
  file "aggregated_identification_library_neg.csv" into library_tsv_neg_passatutto

    shell:
    '''

  /usr/local/bin/librarySearchEngine.r -l !{libraryFile} -i !{parameters} -out aggregated_identification_library_neg.csv -th "-1" -im neg -ts Scoredotproduct -rs 1000 -ncore !{params.ncore_searchengine_library_neg_msnbase}

  sed -i '/^$/d' aggregated_identification_library_neg.csv

    '''
  }

}
/*
 * STEP 94 - calculate pep for the library hits
 */

process process_pepcalculation_library_neg_passatutto{
  tag "$name"
  publishDir "${params.outdir}/process_pepcalculation_library_neg_passatutto", mode: 'copy'
  // container '${computations.library_pepcalculation_library_neg_passatutto'

  input:
  file identification_result from library_tsv_neg_passatutto

output:
file "pep_identification_library_neg.csv" into library_tsv_neg_output

shell:
  '''
  if [ -s !{identification_result} ]
  then
/usr/local/bin/metfragPEP.r input=!{identification_result} score=score output=pep_identification_library_neg.csv readTable=T
else
touch pep_identification_library_neg.csv
fi
'''

}

/*
 * STEP 95 - output the library results
 */


process  process_output_quantid_neg_camera_library{
  tag "$name"
  publishDir "${params.outdir}/process_output_quantid_neg_camera_library", mode: 'copy'
  stageInMode 'copy'
  // container '${computations.docker_output_quantid_neg_camera_library}'

  input:
  file phenotype_file from phenotype_design_neg_library
  file camera_input_quant from prepareoutput_rdata_neg_camera_library
  file library_input_identification from library_tsv_neg_output

output:
file "*.txt" into library_neg_finished
  shell:
'''
if [ -s !{library_input_identification} ]
then
	/usr/local/bin/prepareOutput.r inputcamera=!{camera_input_quant} inputscores=!{library_input_identification} inputpheno=!{phenotype_file} ppm=!{params.ppm_output_neg_camera} rt=!{params.rt_output_neg_camera} higherTheBetter=true scoreColumn=score impute=!{params.impute_output_neg_camera} typeColumn=!{params.type_column_output_neg_camera} selectedType=!{params.selected_type_output_neg_camera} rename=!{params.rename_output_neg_camera} renameCol=!{params.rename_col_output_neg_camera} onlyReportWithID=!{params.only_report_with_id_output_neg_camera} combineReplicate=!{params.combine_replicate_output_neg_camera} combineReplicateColumn=!{params.combine_replicate_column_output_neg_camera} log=!{params.log_output_neg_camera} sampleCoverage=!{params.sample_coverage_output_neg_camera} outputPeakTable=peaktableNEGout_neg_library.txt outputVariables=varsNEGout_neg_library.txt outputMetaData=metadataNEGout_neg_library.txt Ifnormalize=!{params.normalize_output_neg_camera}
  else

  /usr/local/bin/prepareOutput.r inputcamera=!{camera_input_quant} inputpheno=!{phenotype_file} ppm=!{params.ppm_output_neg_camera} rt=!{params.rt_output_neg_camera} higherTheBetter=true scoreColumn=score impute=!{params.impute_output_neg_camera} typeColumn=!{params.type_column_output_neg_camera} selectedType=!{params.selected_type_output_neg_camera} rename=!{params.rename_output_neg_camera} renameCol=!{params.rename_col_output_neg_camera} onlyReportWithID=!{params.only_report_with_id_output_neg_camera} combineReplicate=!{params.combine_replicate_output_neg_camera} combineReplicateColumn=!{params.combine_replicate_column_output_neg_camera} log=!{params.log_output_neg_camera} sampleCoverage=!{params.sample_coverage_output_neg_camera} outputPeakTable=peaktableNEGout_neg_library.txt outputVariables=varsNEGout_neg_library.txt outputMetaData=metadataNEGout_neg_library.txt Ifnormalize=!{params.normalize_output_neg_camera}

  fi
  '''
}

}

}else{

  /*
   * STEP 96 - output the results for no identification
   */

  process  process_output_quantid_neg_camera_noid{
    tag "$name"
    publishDir "${params.outdir}/process_output_quantid_neg_camera_noid", mode: 'copy'
    stageInMode 'copy'
    // container '${computations.docker_output_quantid_neg_camera_noid}'

    input:
    file phenotype_file from phenotype_design_neg_noid
    file camera_input_quant from prepareoutput_rdata_neg_camera_noid

  output:
  file "*.txt" into noid_neg_finished
    shell:
    '''
  	/usr/local/bin/prepareOutput.r inputcamera=!{camera_input_quant} inputpheno=!{phenotype_file} ppm=!{params.ppm_output_neg_camera} rt=!{params.rt_output_neg_camera} higherTheBetter=true scoreColumn=score impute=!{params.impute_output_neg_camera} typeColumn=!{params.type_column_output_neg_camera} selectedType=!{params.selected_type_output_neg_camera} rename=!{params.rename_output_neg_camera} renameCol=!{params.rename_col_output_neg_camera} onlyReportWithID=!{params.only_report_with_id_output_neg_camera} combineReplicate=!{params.combine_replicate_output_neg_camera} combineReplicateColumn=!{params.combine_replicate_column_output_neg_camera} log=!{params.log_output_neg_camera} sampleCoverage=!{params.sample_coverage_output_neg_camera} outputPeakTable=peaktableNEGout_neg_noid.txt outputVariables=varsNEGout_neg_noid.txt outputMetaData=metadataNEGout_neg_noid.txt Ifnormalize=!{params.normalize_output_neg_camera}
  	'''
  }

}
}

/*
 * Completion e-mail notification
 */
workflow.onComplete {

    // Set up the e-mail variables
    def subject = "[nf-core/metaboigniter] Successful: $workflow.runName"
    if(!workflow.success){
      subject = "[nf-core/metaboigniter] FAILED: $workflow.runName"
    }
    def email_fields = [:]
    email_fields['version'] = workflow.manifest.version
    email_fields['runName'] = custom_runName ?: workflow.runName
    email_fields['success'] = workflow.success
    email_fields['dateComplete'] = workflow.complete
    email_fields['duration'] = workflow.duration
    email_fields['exitStatus'] = workflow.exitStatus
    email_fields['errorMessage'] = (workflow.errorMessage ?: 'None')
    email_fields['errorReport'] = (workflow.errorReport ?: 'None')
    email_fields['commandLine'] = workflow.commandLine
    email_fields['projectDir'] = workflow.projectDir
    email_fields['summary'] = summary
    email_fields['summary']['Date Started'] = workflow.start
    email_fields['summary']['Date Completed'] = workflow.complete
    email_fields['summary']['Pipeline script file path'] = workflow.scriptFile
    email_fields['summary']['Pipeline script hash ID'] = workflow.scriptId
    if(workflow.repository) email_fields['summary']['Pipeline repository Git URL'] = workflow.repository
    if(workflow.commitId) email_fields['summary']['Pipeline repository Git Commit'] = workflow.commitId
    if(workflow.revision) email_fields['summary']['Pipeline Git branch/tag'] = workflow.revision
    if(workflow.container) email_fields['summary']['Docker image'] = workflow.container
    email_fields['summary']['Nextflow Version'] = workflow.nextflow.version
    email_fields['summary']['Nextflow Build'] = workflow.nextflow.build
    email_fields['summary']['Nextflow Compile Timestamp'] = workflow.nextflow.timestamp



    // Render the TXT template
    def engine = new groovy.text.GStringTemplateEngine()
    def tf = new File("$baseDir/assets/email_template.txt")
    def txt_template = engine.createTemplate(tf).make(email_fields)
    def email_txt = txt_template.toString()

    // Render the HTML template
    def hf = new File("$baseDir/assets/email_template.html")
    def html_template = engine.createTemplate(hf).make(email_fields)
    def email_html = html_template.toString()

    // Render the sendmail template
    def smail_fields = [ email: params.email, subject: subject, email_txt: email_txt, email_html: email_html, baseDir: "$baseDir" ]
    def sf = new File("$baseDir/assets/sendmail_template.txt")
    def sendmail_template = engine.createTemplate(sf).make(smail_fields)
    def sendmail_html = sendmail_template.toString()

    // Send the HTML e-mail
    if (params.email) {
        try {
          if( params.plaintext_email ){ throw GroovyException('Send plaintext e-mail, not HTML') }
          // Try to send HTML e-mail using sendmail
          [ 'sendmail', '-t' ].execute() << sendmail_html
          log.info "[nf-core/metaboigniter] Sent summary e-mail to $params.email (sendmail)"
        } catch (all) {
          // Catch failures and try with plaintext
          [ 'mail', '-s', subject, params.email ].execute() << email_txt
          log.info "[nf-core/metaboigniter] Sent summary e-mail to $params.email (mail)"
        }
    }

    // Write summary e-mail HTML to a file
    def output_d = new File( "${params.outdir}/pipeline_info/" )
    if( !output_d.exists() ) {
      output_d.mkdirs()
    }
    def output_hf = new File( output_d, "pipeline_report.html" )
    output_hf.withWriter { w -> w << email_html }
    def output_tf = new File( output_d, "pipeline_report.txt" )
    output_tf.withWriter { w -> w << email_txt }

    c_reset = params.monochrome_logs ? '' : "\033[0m";
    c_purple = params.monochrome_logs ? '' : "\033[0;35m";
    c_green = params.monochrome_logs ? '' : "\033[0;32m";
    c_red = params.monochrome_logs ? '' : "\033[0;31m";

    if (workflow.stats.ignoredCountFmt > 0 && workflow.success) {
      log.info "${c_purple}Warning, pipeline completed, but with errored process(es) ${c_reset}"
      log.info "${c_red}Number of ignored errored process(es) : ${workflow.stats.ignoredCountFmt} ${c_reset}"
      log.info "${c_green}Number of successfully ran process(es) : ${workflow.stats.succeedCountFmt} ${c_reset}"
    }

    if(workflow.success){
        log.info "${c_purple}[nf-core/metaboigniter]${c_green} Pipeline completed successfully${c_reset}"
    } else {
        checkHostname()
        log.info "${c_purple}[nf-core/metaboigniter]${c_red} Pipeline completed with errors${c_reset}"
    }

}


def nfcoreHeader(){
    // Log colors ANSI codes
    c_reset = params.monochrome_logs ? '' : "\033[0m";
    c_dim = params.monochrome_logs ? '' : "\033[2m";
    c_black = params.monochrome_logs ? '' : "\033[0;30m";
    c_green = params.monochrome_logs ? '' : "\033[0;32m";
    c_yellow = params.monochrome_logs ? '' : "\033[0;33m";
    c_blue = params.monochrome_logs ? '' : "\033[0;34m";
    c_purple = params.monochrome_logs ? '' : "\033[0;35m";
    c_cyan = params.monochrome_logs ? '' : "\033[0;36m";
    c_white = params.monochrome_logs ? '' : "\033[0;37m";

    return """    ${c_dim}----------------------------------------------------${c_reset}
                                            ${c_green},--.${c_black}/${c_green},-.${c_reset}
    ${c_blue}        ___     __   __   __   ___     ${c_green}/,-._.--~\'${c_reset}
    ${c_blue}  |\\ | |__  __ /  ` /  \\ |__) |__         ${c_yellow}}  {${c_reset}
    ${c_blue}  | \\| |       \\__, \\__/ |  \\ |___     ${c_green}\\`-._,-`-,${c_reset}
                                            ${c_green}`._,._,\'${c_reset}
    ${c_purple}  nf-core/metaboigniter v${workflow.manifest.version}${c_reset}
    ${c_dim}----------------------------------------------------${c_reset}
    """.stripIndent()
}

def checkHostname(){
    def c_reset = params.monochrome_logs ? '' : "\033[0m"
    def c_white = params.monochrome_logs ? '' : "\033[0;37m"
    def c_red = params.monochrome_logs ? '' : "\033[1;91m"
    def c_yellow_bold = params.monochrome_logs ? '' : "\033[1;93m"
    if(params.hostnames){
        def hostname = "hostname".execute().text.trim()
        params.hostnames.each { prof, hnames ->
            hnames.each { hname ->
                if(hostname.contains(hname) && !workflow.profile.contains(prof)){
                    log.error "====================================================\n" +
                            "  ${c_red}WARNING!${c_reset} You are running with `-profile $workflow.profile`\n" +
                            "  but your machine hostname is ${c_white}'$hostname'${c_reset}\n" +
                            "  ${c_yellow_bold}It's highly recommended that you use `-profile $prof${c_reset}`\n" +
                            "============================================================"
                }
            }
        }
    }
}
