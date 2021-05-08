#!/usr/bin/env Rscript
options(stringAsfactors = FALSE, useFancyQuotes = FALSE)
# This script is used to group or link different mass traces across samples
# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No file has been specified! Please select a file for performing grouping!\n")
require(xcms)
previousEnv<-NA
output<-NA
bw<-15
mzwid=0.005
minfrac<-0.3
minsamp<-1
max<-50
ipo_in<-NA

for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]
  if(argCase=="input")
  {
    previousEnv=as.character(value)
  }
  if(argCase=="ipo_in")
  {
    ipo_in=as.character(value)
  }
  if(argCase=="bandwidth")
  {
    bw=as.numeric(value)
  }
  if(argCase=="minfrac")
  {
    minfrac=as.numeric(value)
  }
  if(argCase=="minsamp")
  {
    minsamp=as.numeric(value)
  }
  if(argCase=="max")
  {
    max=as.numeric(value)
  }

  if(argCase=="mzwid")
  {
    mzwid=as.numeric(value)
  }
  if(argCase=="output")
  {
    output=as.character(value)
  }

}
if(is.na(previousEnv) | is.na(output)) stop("Both input and output need to be specified!\n")

load(file = previousEnv)

toBeGrouped<-get(varNameForNextStep)

if(!is.na(ipo_in))
{
  ## Read IPO params
  ## This will overwrite the parameters that have been supplies by the user
  library(jsonlite)
  ipo_json<-read_json(ipo_in,simplifyVector = T)
  ipo_params<-fromJSON(ipo_json)
  bw<-ipo_params$bw
  minfrac<-ipo_params$minfrac
  mzwid<-ipo_params$mzwid
  minsamp<-ipo_params$minsamp
  max<-ipo_params$max
}

ipo_inv<-get("ipo_inv")
if(ipo_inv==TRUE & is.na(ipo_in))
{
  ipo_params<-get("ipo_params_set")
  ipo_params<-ipo_params
  bw<-ipo_params$bw
  minfrac<-ipo_params$minfrac
  mzwid<-ipo_params$mzwid
  minsamp<-ipo_params$minsamp
  max<-ipo_params$max
}

xcmsSetGrouped<-  group(toBeGrouped,bw=bw,mzwid=mzwid,max=max,minsamp=minsamp,minfrac=minfrac,method="density")

preprocessingSteps<-c(preprocessingSteps,"Group")

varNameForNextStep<-as.character("xcmsSetGrouped")

save(list = c("xcmsSetGrouped","preprocessingSteps","varNameForNextStep"),file = output)
