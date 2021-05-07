#!/usr/bin/env Rscript
options(stringAsfactors = FALSE, useFancyQuotes = FALSE)
# This script is used to perform mass trace detection using XCMS
# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No file has been specified! Please select a file for performing peak picking!\n")
require(xcms)
RawFiles<-NA
output<-NA
ppm=10
peakwidthLow=4
peakwidthHigh=30
noise=1000
mzdiff<-0.001
snthresh<-10
prefilter_l<-3
prefilter_h<-100
mzCenterFun<-"wMean"
polarity<-"pos"
integrate<-1
fitgauss<-FALSE
methodXset<-"centWave"

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
snthresh_l<-10
snthresh_h<-10
prefilter_l_l<-3
prefilter_l_h<-3
prefilter_h_l<-100
prefilter_h_h<-100
noise_l=0
noise_h=0
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]
  if(argCase=="input")
  {
    RawFiles=as.character(value)
  }
  if(argCase=="ipo_in")
  {
    ipo_in=as.character(value)
  }
  if(argCase=="realFileName")
  {
    realFileName=as.character(value)
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
  if(argCase=="ppm")
  {
    ppm=as.numeric(value)
  }
  if(argCase=="peakwidthLow")
  {
    peakwidthLow=as.numeric(value)
  }
  if(argCase=="peakwidthHigh")
  {
    peakwidthHigh=as.numeric(value)
  }
  if(argCase=="noise")
  {
    noise=as.numeric(value)
  }
  if(argCase=="mzdiff")
  {
    mzdiff=as.numeric(value)
  }
  if(argCase=="snthresh")
  {
    snthresh=as.numeric(value)
  }
  if(argCase=="prefilter_l")
  {
    prefilter_l=as.numeric(value)
  }
  if(argCase=="prefilter_h")
  {
    prefilter_h=as.numeric(value)
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
  if(argCase=="ipo_inv")
  {
    ipo_inv=as.logical(value)
  }

  if(argCase=="polarity")
  {
    polarity=as.character(value)
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

  if(argCase=="sampleClass")
  {
    sampleClass=as.character(value)
  }
  if(argCase=="phenoFile")
  {
    phenoFile=as.character(value)
  }
  if(argCase=="phenoDataColumn")
  {
    phenoDataColumn=as.character(value)
  }
  if(argCase=="output")
  {
    output=as.character(value)
  }
  if(argCase=="methodXset")
  {
    methodXset=as.character(value)
  }

}
if(is.na(RawFiles) | is.na(output)) stop("Both input and output need to be specified!\n")
require(xcms)
if(!is.na(ipo_in) & !ipo_inv)
{
  ## Read IPO params
  ## This will overwrite the parameters that have been supplies by the user
  library(jsonlite)
  ipo_json<-read_json(ipo_in,simplifyVector = T)
  ipo_params<-fromJSON(ipo_json)
  ppm<-ipo_params$ppm
  peakwidthLow<-ipo_params$min_peakwidth
  peakwidthHigh<-ipo_params$max_peakwidth
  noise<-ipo_params$noise
  prefilter_l<-ipo_params$prefilter
  prefilter_h<-ipo_params$value_of_prefilter
  snthresh<-ipo_params$snthresh
  mzCenterFun<-ipo_params$mzCenterFun
  integrate<-ipo_params$integrate
  mzdiff<-ipo_params$mzdiff
  fitgauss<-ipo_params$fitgauss
}
if(ipo_inv==TRUE)
{
  library(IPO)



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

  result_ipo <- optimizeXcmsSet(RawFiles, ipo_params, isotopeIdentification="CAMERA",ppm=ipo_max_ppm_camera,maxcharge=ipo_charge_camera)

  ipo_params<- result_ipo$best_settings$parameters
  ppm<-ipo_params$ppm
  peakwidthLow<-ipo_params$min_peakwidth
  peakwidthHigh<-ipo_params$max_peakwidth
  noise<-ipo_params$noise
  prefilter_l<-ipo_params$prefilter
  prefilter_h<-ipo_params$value_of_prefilter
  snthresh<-ipo_params$snthresh
  mzCenterFun<-ipo_params$mzCenterFun
  integrate<-ipo_params$integrate
  mzdiff<-ipo_params$mzdiff
  fitgauss<-ipo_params$fitgauss
}
massTracesXCMSSet<-NA
if(is.na(sampleClass))
{
massTracesXCMSSet<-xcmsSet(RawFiles,polarity = polarity,
        method = "centWave",
        ppm=ppm,
        peakwidth=c(peakwidthLow,peakwidthHigh),
        noise=noise,prefilter=c(prefilter_l,prefilter_h),snthresh=snthresh,mzCenterFun=mzCenterFun,integrate=integrate,mzdiff=mzdiff,fitgauss=fitgauss)
}else{
massTracesXCMSSet<-xcmsSet(RawFiles,polarity = polarity,
        method = "centWave",
        ppm=ppm,
        peakwidth=c(peakwidthLow,peakwidthHigh),
        noise=noise,sclass = sampleClass,prefilter=c(prefilter_l,prefilter_h),snthresh=snthresh,mzCenterFun=mzCenterFun,integrate=integrate,mzdiff=mzdiff,fitgauss=fitgauss)
}
# get original name of mz file
name.parts <- unlist(strsplit(gsub(".*name=\"", "", grep('<sourceFile ', readLines(RawFiles), value=T)[1]), c("\\.")))
attributes(attributes(massTracesXCMSSet)[[".processHistory"]][[1]])$origin <- paste(name.parts[-length(name.parts)], collapse=".")

# set the original file name
if(!is.na(realFileName))
{
realFileName<-gsub(pattern = "Galaxy.*-\\[|\\].*",replacement = "",x = realFileName)
rownames(massTracesXCMSSet@phenoData)<-realFileName
}

# set phenotype if demanded
if(!is.na(phenoDataColumn) && !is.na(phenoFile))
{
fileNameMap<-read.csv(phenoFile,stringsAsFactors = F,header = T)
massTracesXCMSSet@phenoData[1]<-fileNameMap[fileNameMap[,1]==rownames(massTracesXCMSSet@phenoData),phenoDataColumn]
}





preprocessingSteps<-c("FindPeaks")
varNameForNextStep<-as.character("massTracesXCMSSet")
save(list = c("massTracesXCMSSet","preprocessingSteps","varNameForNextStep"),file = output)
