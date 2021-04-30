#!/usr/bin/env Rscript

options(stringAsfactors = FALSE, useFancyQuotes = FALSE)

# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No file has been specified!")

output<-NA
appendTo<-NA
appendToName<-"realNames"
cleanFileName=T
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]
  
  if(argCase=="galaxyNames")
  {
    galaxyNames=as.character(value)
  }
  if(argCase=="realNames")
  {
    realNames=as.character(value)
  }
  if(argCase=="cleanFileName")
  {
    cleanFileName=as.logical(value)
  }
  if(argCase=="appendTo")
  {
    appendTo=as.character(value)
  }
  if(argCase=="appendToName")
  {
    appendToName=as.character(value)
  }
  if(argCase=="output")
  {
    output=as.character(value)
  }
  
}


galaxyNamesTMP<-gsub(pattern = " ",replacement = "",strsplit(x = galaxyNames,split = ",",fixed=T)[[1]],fixed=T)
realNamesTMP<-gsub(pattern = " ",replacement = "",strsplit(x = realNames,split = ",",fixed=T)[[1]],fixed=T)

galaxyNamesTMP[galaxyNamesTMP!=""]
realNamesTMP[realNamesTMP!=""]


if(cleanFileName)
  realNamesTMP<-gsub(pattern = "Galaxy.*-\\[|\\].*",replacement = "",x = realNamesTMP)

# can we have different length ?
if(length(galaxyNamesTMP)!=length(realNamesTMP))
{
  stop("galaxy names and real file names have different length!")
}

# create a dataframe in which galaxynames have their realnames infront of them
baseNames<-basename(galaxyNamesTMP)
mappedNames<-data.frame(realNames=realNamesTMP,galaxyNames=baseNames,stringsAsFactors = F)
mappedNames<-mappedNames[mappedNames[,1]!="",]
if(!is.na(appendTo))
{
  tmpCSVFile<-read.csv(appendTo,stringsAsFactors = F)
  sortedGalaxyNames<-mappedNames[match(mappedNames[,"realNames"],tmpCSVFile[,appendToName]),"galaxyNames"]
  sortedGalaxyNamesID<-paste("step_",ncol(tmpCSVFile)+1,sep = "")
  outCSVFile<-cbind(tmpCSVFile,tmp=sortedGalaxyNames)
  colnames(outCSVFile)<-c(colnames(tmpCSVFile),sortedGalaxyNamesID)
  mappedNames<-outCSVFile
}else
{
  colnames(mappedNames)<-c(appendToName,"step_1")
}

# write the results
write.csv(x = mappedNames,file = output,row.names = F)
