#!/usr/bin/env Rscript
options(stringAsfactors = FALSE, useFancyQuotes = FALSE)

# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No file has been specified! Please select a file for performing groupCorr!\n")
require(xcms)
require(CAMERA)
previousEnv<-NA
output<-NA
cor_eic_th<-0.8
pval<-0.05
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]
  if(argCase=="input")
  {
    previousEnv=as.character(value)
  }
  if(argCase=="correlation")
  {
    cor_eic_th=as.numeric(value)
  }
  if(argCase=="pvalue")
  {
    pval=as.numeric(value)
  }
  if(argCase=="output")
  {
    output=as.character(value)
  }
  
}
if(is.na(previousEnv) | is.na(output)) stop("Both input and output need to be specified!\n")

load(file = previousEnv)

toBeGroupedCorr<-get(varNameForNextStep)

xcmsSetGroupedCorr<-groupCorr(toBeGroupedCorr,cor_eic_th = cor_eic_th,pval = pval)

preprocessingSteps<-c(preprocessingSteps,"GroupedCorr")

varNameForNextStep<-as.character("xcmsSetGroupedCorr")

save(list = c("xcmsSetGroupedCorr","preprocessingSteps","varNameForNextStep"),file = output)

