#!/usr/bin/env Rscript
options(stringAsfactors = FALSE, useFancyQuotes = FALSE)
# This script is used to create a library characterization file
# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No parameters are given!\n")

inputMS2<-NA
inputCamera<-NA
inputLibrary<-NA
  rawFileName<-"rawFile"
  compundID<-"HMDB.YMDB.ID"
  compoundName<-"PRIMARY_NAME"
  mzCol<-"mz"
  copyRest<-F
  whichmz<-"f"

output<-NA
maxSpectra<-NA
minPeaks<-0
minPrecursorMass<-NA
maxPrecursorMass<-NA
precursortppm<-10

filetype<-"txt"
outputMerge=F
outputname=""
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]

  if(argCase=="inputMS2")
  {
    inputMS2=as.character(value)

  }
  if(argCase=="inputCAMERA")
  {

    inputCamera=as.character(value)

  }
  if(argCase=="inputLibrary")
  {

    inputLibrary=as.character(value)

  }
  if(argCase=="whichmz")
  {
    # f == feature
    # p=parent
    # c= centroid

    whichmz=as.character(value)

  }
  if(argCase=="maxPrecursorMass")
  {

    maxPrecursorMass=as.numeric(value)

  }
  if(argCase=="minPrecursorMass")
  {

    minPrecursorMass=as.numeric(value)

  }
  if(argCase=="precursorppm")
  {

    precursortppm=as.numeric(value)

  }
  if(argCase=="fragmentppm")
  {

    fragmentppm=as.numeric(value)

  }

  if(argCase=="fragmentabs")
  {

    fragmentabs=as.numeric(value)

  }
  if(argCase=="database")
  {

    database=as.character(value)

  }
  if(argCase=="minPeaks")
  {

    minPeaks=as.numeric(value)

  }
  if(argCase=="maxSpectra")
  {

    maxSpectra=as.numeric(value)

  }
  if(argCase=="output")
  {
    output=as.character(value)
  }
  if(argCase=="mode")
  {
    mode=as.character(value)
  }
  if(argCase=="adductRules")
  {
    adductRules=as.character(value)
  }
  if(argCase=="filetype")
  {
    filetype=as.character(value)
  }
  if(argCase=="outputmerge")
  {
    outputMerge=as.logical(value)
  }
  if(argCase=="outputname")
  {
    outputname=as.character(value)
  }
}

if(is.na(inputMS2) | is.na(inputCamera) | is.na(output) | is.na(inputLibrary)) stop("All inputs (Library, CAMERA and MS2) and output need to be specified!\n")

# read the library
libraryInfo<-read.csv(file = inputLibrary,stringsAsFactors = F)

requiredHeader<-c(rawFileName=rawFileName,compundID=compundID,compoundName=compoundName,mzCol=mzCol)




load(inputMS2)
MappedMS2s<-get(varNameForNextStep)
load(inputCamera)
cameraObject<-get(varNameForNextStep)


source("/usr/bin/createLibraryFun.r")

library(stringr)


createLibrary(MSMSdata = MappedMS2s,libraryInfo,requiredHeader,whichmz=whichmz,
                   cameraObject = cameraObject,includeUnmapped = F,savePath=output,
                   includeMapped = T,preprocess = F, minPeaks=minPeaks,
                   maxSpectra=maxSpectra, maxPrecursorMass = maxPrecursorMass, minPrecursorMass = minPrecursorMass,ppm=precursortppm)
