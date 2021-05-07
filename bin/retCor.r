#!/usr/bin/env Rscript
options(stringAsfactors = FALSE, useFancyQuotes = FALSE)
# This script is used to correct the RT drift using xcms. It can also do IPO for RT correction parameter estimatation
# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No file has been specified! Please select a file for performing RT correction!\n")
require(xcms)
previousEnv<-NA
output<-NA
method="obiwarp"
ncores<-1
profStep<-1
center<-NULL
response_l<-1
response_h<-1
factorDiag_l<-2
factorDiag_h<-2
factorGap_l<-1
factorGap_h<-1
response<-1
distFunc<-"cor_opt"
gapInit<-NULL
gapExtend<-NULL
factorDiag<-2
factorGap<-1
localAlignment<-0
ipo_in<-NA
ipo_inv<-FALSE
ipo_gapInit_l<-0.0
ipo_gapInit_h<-0.4
ipo_gapExtend_l<-2.1
ipo_gapExtend_h<-2.7
ipo_profStep_l<-0.7
ipo_profStep_h<-1.0

bw_l<-22
bw_h<-38
minfrac_l<-0.3
minfrac_h<-0.7
mzwid_l<-0.015
mzwid_h<-0.035
minsamp<-1
max<-50
minsamp_l<-1
minsamp_h<-1
max_l<-50
max_h<-50
inputraw<-NA
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]
  if(argCase=="input")
  {
    previousEnv=as.character(value)
  }
  if(argCase=="inputraw")
  {
    input=as.character(value)
    if(file.info(input)$isdir & !is.na(file.info(input)$isdir))
    {
      inputraw<-list.files(input,full.names = T)

    }else
    {

      inputraw<-sapply(strsplit(x = input,split = "\\;|,| |\\||\\t"),function(x){x})

    }
  }
  if(argCase=="method")
  {
    method=as.character(value)
  }
  if(argCase=="output")
  {
    output=as.character(value)
  }
  if(argCase=="ipo_in")
  {
    ipo_in=as.character(value)
  }

  if(argCase=="profStep")
  {
    profStep=as.numeric(value)
  }
  if(argCase=="center")
  {
    if(as.character(value)!="NULL")
    {
      center=as.numeric(value)
    }
  }
  if(argCase=="response")
  {
    response=as.numeric(value)
  }
  if(argCase=="distFunc")
  {
    distFunc=as.character(value)
  }
  if(argCase=="gapInit")
  {
    if(as.character(value)!="NULL")
    {
      gapInit=as.numeric(value)
    }
  }
  if(argCase=="gapExtend")
  {
    if(as.character(value)!="NULL")
    {
      gapExtend=as.numeric(value)
    }
  }
  if(argCase=="factorDiag")
  {
    factorDiag=as.numeric(value)
  }
  if(argCase=="factorGap")
  {
    factorGap=as.numeric(value)
  }
  if(argCase=="localAlignment")
  {
    localAlignment=as.numeric(value)
  }

  if(argCase=="ipo_inv")
  {
    ipo_inv=as.logical(value)
  }

  if(argCase=="ipo_gapInit_l")
  {
    ipo_gapInit_l=as.numeric(value)
  }

  if(argCase=="ipo_gapInit_h")
  {
    ipo_gapInit_h=as.numeric(value)
  }
  if(argCase=="ipo_gapExtend_l")
  {
    ipo_gapExtend_l=as.numeric(value)
  }
  if(argCase=="ipo_gapExtend_h")
  {
    ipo_gapExtend_h=as.numeric(value)
  }
  if(argCase=="ipo_profStep_l")
  {
    ipo_profStep_l=as.numeric(value)
  }
  if(argCase=="ipo_profStep_h")
  {
    ipo_profStep_h=as.numeric(value)
  }

  if(argCase=="bw_l")
  {
    bw_l=as.numeric(value)
  }

  if(argCase=="bw_h")
  {
    bw_h=as.numeric(value)
  }

  if(argCase=="minfrac_l")
  {
    minfrac_l=as.numeric(value)
  }

  if(argCase=="minfrac_h")
  {
    minfrac_h=as.numeric(value)
  }

  if(argCase=="mzwid_l")
  {
    mzwid_l=as.numeric(value)
  }

  if(argCase=="mzwid_h")
  {
    mzwid_h=as.numeric(value)
  }
  if(argCase=="minsamp_l")
  {
    minsamp_l=as.numeric(value)
  }
  if(argCase=="minsamp_h")
  {
    minsamp_h=as.numeric(value)
  }
  if(argCase=="max_l")
  {
    max_l=as.numeric(value)
  }
  if(argCase=="max_h")
  {
    max_h=as.numeric(value)
  }
  if(argCase=="minsamp")
  {
    minsamp=as.numeric(value)
  }

  if(argCase=="max")
  {
    max=as.numeric(value)
  }
  if(argCase=="response_l")
  {
    response_l=as.numeric(value)
  }
  if(argCase=="response_h")
  {
    response_h=as.numeric(value)
  }
  if(argCase=="factorDiag_l")
  {
    factorDiag_l=as.numeric(value)
  }
  if(argCase=="factorDiag_h")
  {
    factorDiag_l=as.numeric(value)
  }
  if(argCase=="factorGap_l")
  {
    factorGap_l=as.numeric(value)
  }
  if(argCase=="factorGap_h")
  {
    factorGap_h=as.numeric(value)
  }
  if(argCase=="ncores")
  {
    ncores=as.numeric(value)
  }
}
if(is.na(previousEnv) | is.na(output)) stop("Input/inputraw and output need to be specified!\n")
load(file = previousEnv)

toBeRTCorrected<-get(varNameForNextStep)
ipo_params_set<-NA
if(!is.na(ipo_in) & !ipo_inv)
{
  ## Read IPO params
  ## This will overwrite the parameters that have been supplies by the user
  library(jsonlite)
  ipo_json<-read_json(ipo_in,simplifyVector = T)
  ipo_params<-fromJSON(ipo_json)
  profStep<-ipo_params$profStep
  ## Fix center
  #center<-ipo_params$center

  center<-which(tools::file_path_sans_ext(rownames(toBeRTCorrected@phenoData))==tools::file_path_sans_ext(ipo_params$centerName))
  ##
  response<-ipo_params$response
  distFunc<-ipo_params$distFunc
  gapInit<-ipo_params$gapInit
  gapExtend<-ipo_params$gapExtend
  factorDiag<-ipo_params$factorDiag
  factorGap<-ipo_params$factorGap
  localAlignment<-ipo_params$localAlignment
  ipo_params_set<-ipo_params
}




if(ipo_inv==TRUE)
{
  library(IPO)
  ipo_params<-getDefaultRetGroupStartingParams(method)
  ipo_params$factorDiag<-unique(c(factorDiag_l,factorDiag_h))
  ipo_params$factorGap<-unique(c(factorGap_l,factorGap_h))
  ipo_params$distFunc<-distFunc
  ipo_params$gapInit<-unique(c(ipo_gapInit_l,ipo_gapInit_h))
  ipo_params$gapExtend<-unique(c(ipo_gapExtend_l,ipo_gapExtend_h))
  ipo_params$profStep<-unique(c(ipo_profStep_l,ipo_profStep_h))
  ipo_params$localAlignment<-localAlignment
  ipo_params$response<-unique(c(response_l,response_h))
  ipo_params$retcorMethod<-method
  ipo_params$bw<-unique(c(bw_l,bw_h))
  ipo_params$minfrac<-unique(c(minfrac_l,minfrac_h))
  ipo_params$mzwid<-unique(c(mzwid_l,mzwid_h))
  ipo_params$minsamp<-unique(c(minsamp_l,minsamp_h))
  ipo_params$max<-unique(c(max_l,max_h))
  result_ipo <- optimizeRetGroup(toBeRTCorrected, ipo_params,nSlaves = ncores)
  ipo_params_set<-result_ipo$best_settings
  ipo_params<- result_ipo$best_settings
  profStep<-ipo_params$profStep
  center<-ipo_params$center
  response<-ipo_params$response
  distFunc<-ipo_params$distFunc
  gapInit<-ipo_params$gapInit
  gapExtend<-ipo_params$gapExtend
  factorDiag<-ipo_params$factorDiag
  factorGap<-ipo_params$factorGap
  localAlignment<-ipo_params$localAlignment
}
if(ipo_inv | !is.na(ipo_in))
{
  ipo_inv<-TRUE
}
if(!any(is.na(inputraw)))
{
  toBeRTCorrected@filepaths<-inputraw[match(basename(toBeRTCorrected@filepaths),basename(inputraw))]
}

params_list<-list(object=toBeRTCorrected,method=method,
                  profStep=profStep,center=center,response=response,distFunc=distFunc,
                  gapInit=gapInit,gapExtend=gapExtend,
                  factorDiag=as.numeric(factorDiag),factorGap=as.numeric(factorGap),localAlignment=localAlignment)

xcmsSetRTcorrected<-do.call(retcor,params_list[!sapply(params_list,is.null)],quote = T )

preprocessingSteps<-c(preprocessingSteps,"RTCorrection")

varNameForNextStep<-as.character("xcmsSetRTcorrected")

save(list = c("xcmsSetRTcorrected","preprocessingSteps","varNameForNextStep","ipo_inv","ipo_params_set"),file = output)
