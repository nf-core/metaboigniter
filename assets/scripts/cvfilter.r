#!/usr/bin/env Rscript

options(stringAsfactors = FALSE, useFancyQuotes = FALSE)

# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No file has been specified! Please select a file for blank filtering!\n")

require(xcms)
inputPeakML<-NA
output<-NA
blank<-"blank"
sample<-"sample"
method<-"max"
rest<-F
previousEnv<-NA
phenoFile<-NA
phenoDataColumn<-NA
cvcut<-0.3
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]
  if(argCase=="input")
  {
    previousEnv=as.character(value)
  }
  if(argCase=="qc")
  {
    qc=as.character(value)
  }
  if(argCase=="sample")
  {
    sample=as.character(value)
  }
  if(argCase=="rest")
  {
    rest=as.logical(value)
  }
  if(argCase=="phenoFile")
  {
    phenoFile=as.character(value)
  }
  if(argCase=="phenoDataColumn")
  {
    phenoDataColumn=as.character(value)
  }
  if(argCase=="output")
  {
    output=as.character(value)
  }
    if(argCase=="cvcut")
  {
    cvcut=as.numeric(value)
  }
}

if(is.na(previousEnv) | is.na(output) | any(is.na(qc))) stop("All input, output and blank need to be specified!\n")

load(file = previousEnv)
inputXCMS<-get(varNameForNextStep)
if(!is.na(phenoDataColumn) && !is.na(phenoFile))
{
fileNameMap<-read.csv(phenoFile,stringsAsFactors = F,header = T)

for(i in 1:nrow(inputXCMS@phenoData))
{
massTracesXCMSSet@phenoData[i]<-fileNameMap[fileNameMap[,1]==rownames(massTracesXCMSSet@phenoData)[i],phenoDataColumn]
}
}

        CV<-function(x)
        {
		if(length(na.omit(x))<=2)return(100000)
          sd(x,na.rm = T)/mean(x,na.rm = T)
        }
xset<-inputXCMS
idx <- xcms:::groupidx(xset)
removeGR<-c()
removePk<-c()

for( i in seq_along(idx)){
  peak_select <- xcms::peaks(xset)[idx[[i]], ]
  peaks<-rep(NA,nrow(xset@phenoData))
if(class(peak_select)=="numeric")
{
 peaks[peak_select["sample"]]<-peak_select["into"]
}else
{
peaks[peak_select[,"sample"]]<-peak_select[,"into"]
}
 
  names(peaks)<-c(as.character(xset@phenoData[,1]))

  QCSamples<-peaks[names(peaks)==qc]
  realSamples<-NA
  if(rest)
  {
    realSamples<-peaks[names(peaks)!=qc]
  }else{
    realSamples<-peaks[names(peaks)==sample]
  }
  
  
  controlRemove<-F
  
  controlRemove<-CV(QCSamples)>=cvcut
 
  
  
  if(controlRemove)
  {
    
    removeGR<-c(removeGR,i)
    removePk<-c(removePk,idx[[i]])
  }
}

for(i in removeGR)
{
  xset@groupidx[[i]]<-NULL
  xset@groups<-xset@groups[-i,]
}


preprocessingSteps<-c(preprocessingSteps,"cvfilter")

varNameForNextStep<-as.character("xset")

save(list = c("xset","preprocessingSteps","varNameForNextStep"),file = output)
