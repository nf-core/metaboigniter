#!/usr/bin/env Rscript
options(stringAsfactors = FALSE, useFancyQuotes = FALSE)

# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No parameters are given!\n")
require(MSnbase)
RawFiles<-NA
output<-NA
originalFileName<-""
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]
  if(argCase=="input")
  {
    RawFiles=as.character(value)
  }
  if(argCase=="inputname")
  {
    originalFileName=as.character(value)
  }
  if(argCase=="output")
  {
    output=as.character(value)
  }
  
}
if(is.na(RawFiles) | is.na(output)) stop("Both input and output need to be specified!\n")
MS2RawFile<-readMSData(RawFiles, msLevel = 2, verbose = FALSE)
originalFileName<-gsub(pattern = "Galaxy.*-\\[|\\].*",replacement = "",x = originalFileName)
attributes(MS2RawFile)$fileName<-originalFileName

preprocessingStepsMS2<-c("MS2RawFile")
varNameForNextStep<-as.character("MS2RawFile")
save(list = c("MS2RawFile","preprocessingStepsMS2","varNameForNextStep"),file = output)
