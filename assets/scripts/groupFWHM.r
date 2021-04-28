#!/usr/bin/env Rscript
options(stringAsfactors = FALSE, useFancyQuotes = FALSE)

# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No file has been specified! Please select a file for performing groupFWHM!\n")
require(xcms)
require(CAMERA)
previousEnv<-NA
output<-NA
sigma<-8
perfwhm<-0.6
intval<-"maxo"
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]
  if(argCase=="input")
  {
    previousEnv=as.character(value)
  }
  if(argCase=="sigma")
  {
    sigma=as.numeric(value)
  }
  if(argCase=="perfwhm")
  {
    perfwhm=as.numeric(value)
  }
  if(argCase=="intval")
  {
    intval=as.character(value)
  }
  if(argCase=="output")
  {
    output=as.character(value)
  }
  
}
if(is.na(previousEnv) | is.na(output)) stop("Both input and output need to be specified!\n")

load(file = previousEnv)

toBeGroupedFWHM<-get(varNameForNextStep)

xcmsSetGroupedFWHM<-groupFWHM(toBeGroupedFWHM,sigma = sigma,perfwhm = perfwhm,intval = intval)

preprocessingSteps<-c(preprocessingSteps,"GroupedFWHM")

varNameForNextStep<-as.character("xcmsSetGroupedFWHM")

save(list = c("xcmsSetGroupedFWHM","preprocessingSteps","varNameForNextStep"),file = output)

