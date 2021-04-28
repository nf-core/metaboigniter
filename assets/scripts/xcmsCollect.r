#!/usr/bin/env Rscript
options(stringAsfactors = FALSE, useFancyQuotes = FALSE)

# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No file has been specified! Please select more that one files for performing aggregation!\n")
rDataFiles<-NA
hyperXcmsSet<-NA
output<-NA
for(arg in args)
{
argCase<-strsplit(x = arg,split = "=")[[1]][1]
value<-strsplit(x = arg,split = "=")[[1]][2]

if(argCase=="input")
{
  input=as.character(value)
  if(file.info(input)$isdir & !is.na(file.info(input)$isdir))
  {
    rDataFiles<-list.files(input,full.names = T)
    
  }else
  {
   
     rDataFiles<-sapply(strsplit(x = input,split = "\\;|,| |\\||\\t"),function(x){x})
    
  }
}
if(argCase=="output")
{
  output=as.character(value)
}

}
if(is.na(output)) stop("Both input and output need to be specified!\n")
for(rDataFile in rDataFiles)
{
  load(file = rDataFile)
  if(is.na(hyperXcmsSet))
  {
    hyperXcmsSet<-get(varNameForNextStep)
  }else
  {
    hyperXcmsSet<-c(hyperXcmsSet,get(varNameForNextStep))
    
  }
}


preprocessingSteps<-c(preprocessingSteps,"xcmsCollect")

varNameForNextStep<-as.character("hyperXcmsSet")

save(list = c("hyperXcmsSet","preprocessingSteps","varNameForNextStep"),file = output)
