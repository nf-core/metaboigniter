#!/usr/bin/env Rscript
options(stringAsfactors = FALSE, useFancyQuotes = FALSE)

# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No file has been specified! Please select a file for performing xsAnnotate!\n")
require(xcms)
require(CAMERA)
previousEnv<-NA
output<-NA
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

toBeAnnotated<-get(varNameForNextStep)

xcmsSetAnnotated<-xsAnnotate(toBeAnnotated,sample = 1)

preprocessingSteps<-c(preprocessingSteps,"CAMERAAnnotated")

varNameForNextStep<-as.character("xcmsSetAnnotated")

save(list = c("xcmsSetAnnotated","preprocessingSteps","varNameForNextStep"),file = output)

