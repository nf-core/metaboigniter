#!/usr/bin/env Rscript

options(stringAsfactors = FALSE, useFancyQuotes = FALSE)
# This script is used to perform blank filtering based on mzMatch
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
scale_factor<-1
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]
  if(argCase=="input")
  {
    previousEnv=as.character(value)
  }
  if(argCase=="blank")
  {
    blank=as.character(value)
  }
  if(argCase=="sample")
  {
    sample=as.character(value)
  }
  if(argCase=="method")
  {
    method=as.character(value)
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
  if(argCase=="scale_factor")
  {
    scale_factor=as.numeric(value)
  }

}

if(is.na(previousEnv) | is.na(output) | any(is.na(blank))) stop("All input, output and blank need to be specified!\n")

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

SpecificCorrelation<-function(x,d=c(1:length(x)))
{
  if(length(na.omit(x))<=2)return(data.frame(pvalue=1,cor=as.numeric(0)))
  y<-d
  tmpToCor<-cbind(x,y)
  tmpToCor<-na.omit(tmpToCor)
  tmp<-cor.test(tmpToCor[,1],tmpToCor[,2])
  return(data.frame(pvalue=tmp$p.value,cor=as.numeric(tmp$estimate)))
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

  blankSamples<-peaks[names(peaks)==blank]
  realSamples<-NA
  if(rest)
  {
    realSamples<-peaks[names(peaks)!=blank]
  }else{
    realSamples<-peaks[names(peaks)==sample]
  }


  blankSamples[is.na(blankSamples)]<-0
  realSamples[is.na(realSamples)]<-0

  controlRemove<-F
  if(method=="median")
    controlRemove<-median(blankSamples)>=median(realSamples)
  if(method=="mean")
    controlRemove<-mean(blankSamples)>=mean(realSamples)
  if(method=="max")
    controlRemove<-max(blankSamples)>=max(realSamples)



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


preprocessingSteps<-c(preprocessingSteps,"blankFilter")

varNameForNextStep<-as.character("xset")

save(list = c("xset","preprocessingSteps","varNameForNextStep"),file = output)
