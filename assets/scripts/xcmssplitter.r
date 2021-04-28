#!/usr/bin/env Rscript

options(stringAsfactors = FALSE, useFancyQuotes = FALSE)

# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No file has been specified! Please select more that one files for performing split!\n")

output<-NA
previousEnv<-NA
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]
  
  if(argCase=="input")
  {
    previousEnv=as.character(value)
  }
  if(argCase=="output")
  {
    output=as.character(value)
  }
  
}


if(is.na(previousEnv) | is.na(output)) stop("Both input and output need to be specified!\n")
load(file = previousEnv)
toBeSplit<-get(varNameForNextStep)
if(class(toBeSplit)!="xcmsSet")stop("This tool only accepts xcmsSet object!")


xcmsSetSplit<-split(toBeSplit,c(1:length(toBeSplit@filepaths)))
preprocessingStepsTMP<-preprocessingSteps
for(xs in xcmsSetSplit)
{
  preprocessingSteps<-preprocessingStepsTMP
  filename<-paste(output,"/",rownames(xs@phenoData),".rdata",sep="")
  xcmsSetObject<-xs
  varNameForNextStep<-as.character("xcmsSetObject")
  preprocessingSteps<-c(preprocessingSteps,"Split")
  save(list = c("xcmsSetObject","preprocessingSteps","varNameForNextStep"),file = filename)
}
