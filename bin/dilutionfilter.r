#!/usr/bin/env Rscript

options(stringAsfactors = FALSE, useFancyQuotes = FALSE)
# This script is used to do dilution filtering based on mzMatch
# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No file has been specified! Please select a file for dilution filtering!\n")
require(xcms)
inputPeakML<-NA
output<-NA
dilutionTrend<-NA
pvalueCutoff<-1
corCutoff<-0
absolute<-T
Corto<-NA
phenoFile<-NA
phenoDataColumn<-NA
cormethod<-"spearman"
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]
  if(argCase=="input")
  {
    previousEnv=as.character(value)
  }
  if(argCase=="dilution")
  {
    dilutionTrend=strsplit(split = ",",x = as.character(value),fixed = T)[[1]]
  }
  if(argCase=="Corto")
  {
    Corto=strsplit(split = ",",x = as.character(value),fixed = T)[[1]]
    Corto<-as.numeric(Corto)
  }
  if(argCase=="pvalue")
  {
    pvalueCutoff=as.numeric(value)
  }
  if(argCase=="corcut")
  {
    corCutoff=as.numeric(value)
  }
  if(argCase=="abs")
  {
    absolute=as.logical(value)
  }
  if(argCase=="phenoFile")
  {
    phenoFile=as.character(value)
  }
  if(argCase=="phenoDataColumn")
  {
    phenoDataColumn=as.character(value)
  }
  if(argCase=="CorMethod")
  {
    cormethod=as.character(value)
  }
  if(argCase=="output")
  {
    output=as.character(value)
  }
}

if(is.na(previousEnv) | is.na(output) | any(is.na(dilutionTrend))) stop("All input, output and dilution need to be specified!\n")

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
  if(length(na.omit(x))<=1)return(data.frame(pvalue=1,cor=as.numeric(-1.1)))
  if(sd(x,na.rm = T)==0)return(data.frame(pvalue=1.1,cor=as.numeric(-1.1)))
  y<-d
  tmpToCor<-cbind(x,y)
  tmpToCor<-na.omit(tmpToCor)
  tmp<-cor.test(tmpToCor[,1],tmpToCor[,2],method = cormethod)
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
  }else if (class(peak_select)=="matrix")
  {
	peaks[peak_select[,"sample"]]<-peak_select[,"into"]
  }
  names(peaks)<-c(as.character(xset@phenoData[,1]))
  co<-SpecificCorrelation(peaks[dilutionTrend],Corto)
  if(absolute)
    co$cor<-abs(co$cor)
  if(!co$cor<corCutoff & co$pvalue<pvalueCutoff)
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


preprocessingSteps<-c(preprocessingSteps,"dilutionFilter")

varNameForNextStep<-as.character("xset")

save(list = c("xset","preprocessingSteps","varNameForNextStep"),file = output)
