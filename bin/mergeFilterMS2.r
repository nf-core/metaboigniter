#!/usr/bin/env Rscript

options(stringAsfactors = FALSE, useFancyQuotes = FALSE)
# this script can be used to merge MS2 spectra and do smoothing and grouping
# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No parameters are given!\n")
msnbaserdata<-NA
output<-NA
output.pdf<-NA
mzppm<-10
mzabs<-0.01
rtabs<-2 # in seconds
max.rt.range<-.Machine$double.xmax
max.mz.range<-.Machine$double.xmax
min.rt<-0
max.rt<-.Machine$double.xmax
min.mz<-0
max.mz<-.Machine$double.xmax
msms.intensity.threshold<-0
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]
  if(argCase=="msnbaserdata")
  {
    msnbaserdata=as.character(value)
  }
  if(argCase=="mzppm")
  {
    mzppm=as.numeric(value)
  }
  if(argCase=="mzabs")
  {
    mzabs=as.numeric(value)
  }
  if(argCase=="rtabs")
  {
    rtabs=as.numeric(value)
  }
  if(argCase=="max_rt_range")
  {
    max.rt.range=as.numeric(value)
  }
  if(argCase=="max_mz_range")
  {
    max.mz.range=as.numeric(value)
  }
  if(argCase=="min_rt")
  {
    min.rt=as.numeric(value)
  }
  if(argCase=="max_rt")
  {
    max.rt=as.numeric(value)
  }
  if(argCase=="min_mz")
  {
    min.mz=as.numeric(value)
  }
  if(argCase=="max_mz")
  {
    max.mz=as.numeric(value)
  }
  if(argCase=="msms_intensity_threshold")
  {
    msms.intensity.threshold=as.numeric(value)
  }
  if(argCase=="output")
  {
    output=as.character(value)
  }
  if(argCase=="output.pdf")
  {
    output.pdf=as.character(value)
  }
}
if(is.na(msnbaserdata) | is.na(output)) stop("Both input and output need to be specified!\n")
library(xcms)
library(MSnbase)
source("/usr/bin/functionsMergeFilterMS2.r")
load(file = msnbaserdata)
MSMSdata<-get(varNameForNextStep)
originalFileName<-attributes(MSMSdata)$fileName
# merge and filter spectra
MS2RawFile <- merge.spectra(MSMSdata, mzabs, mzppm, rtabs, max.rt.range, max.mz.range, min.rt, max.rt, min.mz, max.mz, output.pdf=output.pdf, msms.intensity.threshold)
attributes(MS2RawFile)$fileName <- originalFileName

preprocessingStepsMS2<-c("MS2RawFile")
varNameForNextStep<-as.character("MS2RawFile")
save(list = c("MS2RawFile","preprocessingStepsMS2","varNameForNextStep"),file = output)
