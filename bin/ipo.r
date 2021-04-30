#!/usr/bin/env Rscript
options(stringAsfactors = FALSE, useFancyQuotes = FALSE)
# This script implements IPO for parameter selection
# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)


if(length(args)==0)stop("No file has been specified! Please select a file for performing IPORaw!\n")

library(IPO)

## overall
allSamples<-T
columnToSelect<-NA
valueToSelect<-NA
phenoFile<-NA
## Xset
RawFiles<-NA
output<-NA
ppm=10
peakwidthLow=4
peakwidthHigh=30
noise_l=0
noise_h=0

mzdiff<-0.001
snthresh_l<-10
snthresh_h<-10
prefilter_l_l<-3
prefilter_l_h<-3
prefilter_h_l<-100
prefilter_h_h<-100
mzCenterFun<-"wMean"
polarity<-"pos"
integrate<-1
fitgauss<-FALSE


sampleClass<-NA
realFileName<-NA
phenoFile<-NA
phenoDataColumn<-NA
ipo_in<-NA
ipo_inv<-F
ipo_min_peakwidth_l<-12
ipo_min_peakwidth_h<-28
ipo_max_peakwidth_l<-35
ipo_max_peakwidth_h<-65
ipo_ppm_l<-17
ipo_ppm_h<-32
ipo_mzdiff_l<--0.001
ipo_mzdiff_h<-0.010
ipo_charge_camera<-1
ipo_max_ppm_camera<-10
### recor
center<-NULL
response_l<-1
response_h<-1
distFunc<-"cor_opt"
factorDiag_l<-2
factorDiag_h<-2
factorGap_l<-1
factorGap_h<-1
localAlignment<-0
ipo_in<-NA
ipo_inv<-FALSE
ipo_gapInit_l<-0.0
ipo_gapInit_h<-0.4
ipo_gapExtend_l<-2.1
ipo_gapExtend_h<-2.7
ipo_profStep_l<-0.7
ipo_profStep_h<-1.0
### Group

bw_l<-22
bw_h<-38
minfrac_l<-0.3
minfrac_h<-0.7
mzwid_l<-0.015
mzwid_h<-0.035
minsamp_l<-1
minsamp_h<-1
max_l<-50
max_h<-50
methodXset<-"centWave"
methodRT<-"obiwarp"
##
outputxset<-NA
outputrt<-NA
ncores<-1
quantOnly<-F
### read params

for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]


  if(argCase=="input")
  {
    input=as.character(value)
    if(file.info(input)$isdir & !is.na(file.info(input)$isdir))
    {
      RawFiles<-list.files(input,full.names = T)
      RawFiles<-as.vector(RawFiles)
    }else
    {

      RawFiles<-sapply(strsplit(x = input,split = "\\;|,| |\\||\\t"),function(x){x})
      RawFiles<-as.vector(RawFiles)

    }
  }
  if(argCase=="quantOnly")
  {
    quantOnly=as.logical(value)
  }
  if(argCase=="allSamples")
  {
    allSamples=as.logical(value)
  }
  if(argCase=="columnToSelect")
  {
    columnToSelect=as.character(value)
  }
  if(argCase=="valueToSelect")
  {
    valueToSelect=as.character(value)
  }
  if(argCase=="phenoFile")
  {
    phenoFile=as.character(value)
  }
  if(argCase=="methodXset")
  {
    methodXset=as.character(value)
  }
  if(argCase=="methodRT")
  {
    methodRT=as.character(value)
  }


  if(argCase=="noise_l")
  {
    noise_l=as.numeric(value)
  }
  if(argCase=="noise_h")
  {
    noise_h=as.numeric(value)
  }
  if(argCase=="prefilter_l_l")
  {
    prefilter_l_l=as.numeric(value)
  }
  if(argCase=="prefilter_l_h")
  {
    prefilter_l_h=as.numeric(value)
  }
  if(argCase=="prefilter_h_l")
  {
    prefilter_h_l=as.numeric(value)
  }
  if(argCase=="prefilter_h_h")
  {
    prefilter_h_h=as.numeric(value)
  }

  if(argCase=="snthresh_l")
  {
    snthresh_l=as.numeric(value)
  }
  if(argCase=="snthresh_h")
  {
    snthresh_h=as.numeric(value)
  }
  if(argCase=="mzCenterFun")
  {
    mzCenterFun=as.character(value)
  }
  if(argCase=="integrate")
  {
    integrate=as.numeric(value)
  }
  if(argCase=="fitgauss")
  {
    fitgauss=as.logical(value)
  }

  if(argCase=="ipo_min_peakwidth_l")
  {
    ipo_min_peakwidth_l=as.numeric(value)
  }
  if(argCase=="ipo_min_peakwidth_h")
  {
    ipo_min_peakwidth_h=as.numeric(value)
  }
  if(argCase=="ipo_max_peakwidth_l")
  {
    ipo_max_peakwidth_l=as.numeric(value)
  }
  if(argCase=="ipo_max_peakwidth_h")
  {
    ipo_max_peakwidth_h=as.numeric(value)
  }
  if(argCase=="ipo_ppm_l")
  {
    ipo_ppm_l=as.numeric(value)
  }
  if(argCase=="ipo_ppm_h")
  {
    ipo_ppm_h=as.numeric(value)
  }
  if(argCase=="ipo_mzdiff_l")
  {
    ipo_mzdiff_l=as.numeric(value)
  }
  if(argCase=="ipo_mzdiff_h")
  {
    ipo_mzdiff_h=as.numeric(value)
  }
  if(argCase=="ipo_charge_camera")
  {
    ipo_charge_camera=as.numeric(value)
  }
  if(argCase=="ipo_max_ppm_camera")
  {
    ipo_max_ppm_camera=as.numeric(value)
  }

  #########
  if(argCase=="response_l")
  {
    response_l=as.numeric(value)
  }
  if(argCase=="response_h")
  {
    response_h=as.numeric(value)
  }
  if(argCase=="distFunc")
  {
    distFunc=as.character(value)
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
  if(argCase=="localAlignment")
  {
    localAlignment=as.numeric(value)
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
  ########
  if(argCase=="ncores")
  {
    ncores=as.numeric(value)
  }
  if(argCase=="outputxset")
  {
    outputxset=as.character(value)
  }
  if(argCase=="outputrt")
  {
    outputrt=as.character(value)
  }

}

######## check inputs


####
if(!allSamples)
{
  if(is.na(phenoFile))
  {
    stop("You need to provide the phenotype file! Otherwise set allSamples to TRUE")
  }else{

    fileNameMap<-read.csv(phenoFile,stringsAsFactors = F,header = T)
    fileNameMap_l<-fileNameMap[fileNameMap[,columnToSelect]==valueToSelect,]
    RawFiles<-RawFiles[basename(RawFiles)%in% fileNameMap_l[,1]]
  }
}



ipo_params<-getDefaultXcmsSetStartingParams(methodXset)
ipo_params$min_peakwidth<-unique(c(ipo_min_peakwidth_l,ipo_min_peakwidth_h))
ipo_params$max_peakwidth<-unique(c(ipo_max_peakwidth_l,ipo_max_peakwidth_h))
ipo_params$ppm<-unique(c(ipo_ppm_l,ipo_ppm_h))
ipo_params$mzdiff<-unique(c(ipo_mzdiff_l,ipo_mzdiff_h))
ipo_params$snthresh<-unique(c(snthresh_l,snthresh_h))
ipo_params$noise<-unique(c(noise_l,noise_h))
ipo_params$prefilter<-unique(c(prefilter_l_l,prefilter_l_h))
ipo_params$value_of_prefilter<-unique(c(prefilter_h_l,prefilter_h_h))
ipo_params$mzCenterFun<-mzCenterFun
ipo_params$integrate<-integrate
ipo_params$fitgauss<-fitgauss
result_ipo <- optimizeXcmsSet(RawFiles, ipo_params,nSlaves=ncores)
xsetSettings<-result_ipo$best_settings$parameters
toBeRTCorrected<-result_ipo$best_settings$xset
if(!quantOnly)
{
  ipo_params<-getDefaultRetGroupStartingParams(methodRT)
  ipo_params$factorDiag<-unique(c(factorDiag_l,factorDiag_h))
  ipo_params$factorGap<-unique(c(factorGap_l,factorGap_h))
  ipo_params$distFunc<-distFunc
  ipo_params$gapInit<-unique(c(ipo_gapInit_l,ipo_gapInit_h))
  ipo_params$gapExtend<-unique(c(ipo_gapExtend_l,ipo_gapExtend_h))
  ipo_params$profStep<-unique(c(ipo_profStep_l,ipo_profStep_h))
  ipo_params$localAlignment<-localAlignment
  ipo_params$response<-unique(c(response_l,response_h))
  ipo_params$retcorMethod<-methodRT
  ipo_params$bw<-unique(c(bw_l,bw_h))
  ipo_params$minfrac<-unique(c(minfrac_l,minfrac_h))
  ipo_params$mzwid<-unique(c(mzwid_l,mzwid_h))
  ipo_params$minsamp<-unique(c(minsamp_l,minsamp_h))
  ipo_params$max<-unique(c(max_l,max_h))
  result_ipo <- optimizeRetGroup(toBeRTCorrected, ipo_params,nSlaves=ncores)
  result_ipo$best_settings$centerName<-rownames(toBeRTCorrected@phenoData)[result_ipo$best_settings$center]
}

library(jsonlite)
xsetJ<-jsonlite:::toJSON(xsetSettings)
write_json(xsetJ,path = outputxset)
if(!quantOnly)
{
  RTJ<-jsonlite:::toJSON(result_ipo$best_settings)
  write_json(RTJ,path = outputrt)
}
