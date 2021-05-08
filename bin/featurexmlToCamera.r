#!/usr/bin/env Rscript
# This is used to convert featureXML to CAMERA and XCMS
# how to run
# ./featurexmlToCamera.r input=filename.featureXML mzMLfiles=filename.mzML sampleClass=test realFileName=filename.featureXML polarity=[positive or negative] output=output.rdata phenoFile=phenotype.csv phenoDataColumn=Class changeNameTO=filename.mzML

options(stringAsfactors = FALSE, useFancyQuotes = FALSE)

# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No file has been specified! Please select a file for conversion!\n")
require(xcms)
require(CAMERA)
require(stringr)

mzMLfiles<-NA
featureXMLFile<-NA
realFileName<-NA
output<-NA
polarity<-NA
phenoFile<-NA
phenoDataColumn<-NA
changeNameTO<-NA # this is to convert real file name to mzML
scriptPath="/usr/bin/featurexmltotable.py"

if(!file.exists(scriptPath))
{
  stop("Convertor script not found!")
}


for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]
  if(argCase=="input")
  {
    featureXMLFile=as.character(value)

  }
  if(argCase=="sampleClass")
  {
    sampleClass=as.character(value)
  }
  if(argCase=="mzMLfiles")
  {
    mzMLfiles=as.character(value)
  }
  if(argCase=="realFileName")
  {
    realFileName=as.character(value)
  }
  if(argCase=="polarity")
  {
    polarity=as.character(value)
  }
  if(argCase=="phenoFile")
  {
    phenoFile=as.character(value)
  }
  if(argCase=="phenoDataColumn")
  {
    phenoDataColumn=as.character(value)
  }
  if(argCase=="changeNameTO")
  {
    changeNameTO=as.character(value)
  }

  if(argCase=="output")
  {
    output=as.character(value)
  }


}
chargeStr<-NA

if(polarity%in%c("p","pos","positive","+"))
{
  chargeStr<-"+"
  polarity<-"positive"
} else if(polarity%in%c("n","neg","negative","-"))
{
  chargeStr<-"-"
  polarity="negative"
}else{
  stop("polarity has to be either pos or neg!")
}


if(!file.exists(featureXMLFile))
{
  stop("The input file does not exist!")
}

if(!file.exists(mzMLfiles))
{
  stop("The input mzMLfiles file does not exist!")
}


if(!is.na(realFileName))
{
  realFileName<-gsub(pattern = "Galaxy.*-\\[|\\].*",replacement = "",x = realFileName)
  sampleName<-realFileName
}else{
  sampleName<-tools::file_path_sans_ext(basename(featureXMLFile)) # do our best to get the real name of the file!
  sampleName<-gsub(pattern = "Galaxy.*-\\[|\\].*",replacement = "",x = sampleName)
}


if(!is.na(changeNameTO))
{
  sampleName<-changeNameTO
  realFileName<-changeNameTO
}

if(is.na(sampleClass))
{
  cat("sampleClass was not found! Setting to sample")
  sampleClass<-"sample"

}


## Set conversion command
# Get current path
cpath<-tempfile()
CMD<-paste(scriptPath," ", featureXMLFile," ",cpath, " ", chargeStr,sep="")
sysout<-system(CMD)

if(sysout!=0) stop("Conversion faild")

isotopeData<-read.csv(cpath)


allMassTraces<- isotopeData[,c("mz",
                 "mzmin",
                 "mzmax",
                 "rt",
                 "rtmin",
                 "rtmax",
                 "npeaks",
                 "into",
                 "intb",
                 "maxo",
                 "sn",
                 "sample",
                 "isotopes") ]


rawMzData<-xcms::xcmsRaw(mzMLfiles)
rawRT<-rawMzData@scantime

cameraIsotops<-list()
for(i in 1:nrow(allMassTraces)){
  tmp<-isotopeData[i,c("y","iso","charge","val")]
  if(sum(is.na(tmp))==3 & tmp["charge"]==0)
  {
    cameraIsotops[i]<-list(NULL)
  }else if(!any(is.na(tmp))){
    cameraIsotops[[i]]<-list(y=tmp["y"],iso=tmp["iso"],charge=as.numeric(tmp["charge"]),val=0)

  }

}

cameraObject<-new("xsAnnotate")
cameraObject@isotopes<-cameraIsotops
cameraObject@derivativeIons<-list()
cameraObject@formula<-list()
cameraObject@sample<-1
cameraObject@pspectra[[1]]<-rownames(allMassTraces)
#cameraObject@ruleset<-NULL
tmpMatrix<-matrix(nrow = 0,ncol=4)
colnames(tmpMatrix)<-c("id" ,"grpID" ,"ruleID" ,"parentID")
cameraObject@annoID<-tmpMatrix

allIsoIds<-str_extract(allMassTraces[,"isotopes"], "\\[\\d*\\]")
isotopesIDs<-na.omit(unique(str_extract(allMassTraces[,"isotopes"], "\\[\\d*\\]")))
isoID<-c()

for(isotopeID in isotopesIDs)
{
  isotopeBool<-!is.na(allIsoIds) & allIsoIds==isotopeID
  tmp<-allMassTraces[isotopeBool,]
  isotopeIDLocal<-str_extract(str_extract(tmp[,"isotopes"], "\\[M\\+\\d*\\]"),
                              "\\d+")

  isotopeIDLocal[is.na(isotopeIDLocal)]<-"0"
  isotopeIDLocal<-isotopeIDLocal[order(isotopeIDLocal)]
  tmp<-tmp[order(isotopeIDLocal),]
  isoTMP<-gsub("\\[.*\\]","",tmp[1,"isotopes"])
  charges<-str_extract(isoTMP,"\\d+")
  if(is.na(charges))charges<-1
  for(i in 2:length(isotopeIDLocal))
  {
    isoID<- rbind(isoID,data.frame(mpeak=as.numeric(rownames(tmp)[1]),
                                   isopeak=as.numeric(rownames(tmp)[i]),iso=i-1,charge=as.numeric(charges)))
  }
}

if(!is.null(isoID))
  cameraObject@isoID<-as.matrix(isoID)
tmpMatrix<-matrix(nrow = 0,ncol=4)
colnames(tmpMatrix)<-c("id" ,"mass" ,"ips" ,"psgrp")
cameraObject@runParallel$enable<-0
cameraObject@annoGrp<-tmpMatrix
#cameraObject@runParallel<-(data.frame(enable=0))
########################## now make XCMS set
tmpXCMSSet<-new("xcmsSet")
conversionTmp<-allMassTraces[,c("mz","mzmin","mzmax","rt","rtmin","rtmax","into","intb","maxo","sn","sample")]

tmpXCMSSet@peaks<-as.matrix(sapply(conversionTmp, as.numeric))
rownames(tmpXCMSSet@peaks)<-1:nrow(tmpXCMSSet@peaks)
tmpXCMSSet@groups<-matrix(nrow = 0,ncol = 0)
tmpXCMSSet@groupidx<-list()
tmpXCMSSet@filled<-integer(0)
tmpXCMSSet@rt$raw<-list()
tmpXCMSSet@rt$raw[[1]]<-rawRT
tmpXCMSSet@rt$corrected<-list()
tmpXCMSSet@rt$corrected[[1]]<-rawRT
tmpXCMSSet@polarity=polarity
tmpXCMSSet@mslevel=1
tmpPheno<-data.frame(class=sampleClass)
rownames(tmpPheno)<-sampleName
tmpXCMSSet@phenoData<-tmpPheno
tmpXCMSSet@filepaths<-as.character(sampleName)
cameraObject@xcmsSet<-tmpXCMSSet

cameraObject@groupInfo<-as.matrix(sapply(conversionTmp, as.numeric))
cameraObject@polarity=polarity
rownames(cameraObject@groupInfo)<-1:nrow(cameraObject@groupInfo)
#tmpXCMSSet@phenoData<-data.frame(class="featureXMLXCMS")
massTracesXCMSSet<-cameraObject@xcmsSet

prHistory<-new("ProcessHistory")
prHistory@type<-"Peak detection"
prHistory@date<-date()
prHistory@info=paste("Peak detection in \'",rownames(massTracesXCMSSet@phenoData),"\': ",nrow(massTracesXCMSSet@peaks)," peaks identified.",sep = "")
prHistory@fileIndex=as.integer(1)
prHistory@error<-NULL
attributes(massTracesXCMSSet)[[".processHistory"]]<-list(prHistory)
attributes(attributes(massTracesXCMSSet)[[".processHistory"]][[1]])$origin <- rownames(massTracesXCMSSet@phenoData)



# set phenotype if demanded
if(!is.na(phenoDataColumn) && !is.na(phenoFile))
{
  fileNameMap<-read.csv(phenoFile,stringsAsFactors = F,header = T)
  if(!any(fileNameMap[,1]==rownames(massTracesXCMSSet@phenoData)))
  {
    stop("Phenotype was not find!")
  }else{
  massTracesXCMSSet@phenoData[1]<-fileNameMap[fileNameMap[,1]==rownames(massTracesXCMSSet@phenoData),phenoDataColumn]
  }
}


preprocessingSteps<-c("FindPeaksOpenMS")
varNameForNextStep<-as.character("massTracesXCMSSet")
save(list = c("massTracesXCMSSet","preprocessingSteps","varNameForNextStep"),file = output)
