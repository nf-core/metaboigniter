#!/usr/bin/env Rscript

options(stringAsfactors = FALSE, useFancyQuotes = FALSE)

# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No parameters are given!\n")
rDataFilesMS2<-NA
inputCamera<-NA
output<-NA
ppm<-10
rt<-10
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]
  
  if(argCase=="inputMS2")
  {
    input=as.character(value)
    if(file.info(input)$isdir & !is.na(file.info(input)$isdir))
    {
      rDataFilesMS2<-list.files(input,full.names = T)
      
    }else
    {
      
      rDataFilesMS2<-sapply(strsplit(x = input,split = "\\;|,| |\\||\\t"),function(x){x})
      
    }
  }
  if(argCase=="inputCAMERA")
  {
   
    inputCamera=as.character(value)
    
  }
  if(argCase=="ppm")
  {
    
    ppm=as.numeric(value)
    
  }
  if(argCase=="rt")
  {
    
    rt=as.numeric(value)
    
  }
  
  if(argCase=="output")
  {
    output=as.character(value)
  }
}

if(is.na(rDataFilesMS2) | is.na(inputCamera) | is.na(output)) stop("Both input (CAMERA and MS2 ) and output need to be specified!\n")

require(intervals)
ppmCal<-function(run,ppm)
{
  return((run*ppm)/1000000)
}
IntervalMerge<-function(cameraObject,MSMSdata, PlusTime,MinusTime,ppm,listOfMS2Mapped=list(),listOfUnMapped=list()){
  
  listofPrecursorsmz<-c()
  for(i in seq(1,length(MSMSdata)))
  {
    listofPrecursorsmz<-c(listofPrecursorsmz,MSMSdata[[i]]@precursorMz)
  }
  
  listofPrecursorsrt<-c()
  for(i in seq(1,length(MSMSdata)))
  {
    listofPrecursorsrt<-c(listofPrecursorsrt,MSMSdata[[i]]@rt)
  }
  
  CameramzColumnIndex<-which(colnames(cameraObject@groupInfo)=="mz")
  
  MassRun1<-Intervals_full(cbind(listofPrecursorsmz,listofPrecursorsmz))
  
  MassRun2<-Intervals_full(cbind(cameraObject@groupInfo[,CameramzColumnIndex]-
                                   ppmCal(cameraObject@groupInfo[,CameramzColumnIndex],ppm),
                                 cameraObject@groupInfo[,CameramzColumnIndex]+
                                   ppmCal(cameraObject@groupInfo[,CameramzColumnIndex],ppm)))
  
  Mass_iii <- interval_overlap(MassRun1,MassRun2)
  
  CamerartLowColumnIndex<-which(colnames(cameraObject@groupInfo)=="rtmin")
  CamerartHighColumnIndex<-which(colnames(cameraObject@groupInfo)=="rtmax")
  
  TimeRun1<-Intervals_full(cbind(listofPrecursorsrt,listofPrecursorsrt))
  
  TimeRun2<-Intervals_full(cbind(cameraObject@groupInfo[,CamerartLowColumnIndex]-MinusTime,
                                 cameraObject@groupInfo[,CamerartHighColumnIndex]+PlusTime))
  Time_ii <- interval_overlap(TimeRun1,TimeRun2)
  
  imatch = mapply(intersect,Time_ii,Mass_iii)
  
  for (i in 1:length(imatch)) {
    for(j in imatch[[i]])
    {
      MSMStmpObject<-MSMSdata[[i]]
      attributes(MSMStmpObject)$fileName<-attributes(MSMSdata)$fileName
      listOfMS2Mapped[[as.character(j)]]<-
        c(listOfMS2Mapped[[as.character(j)]],MSMStmpObject)
    }
  }
  for (i in 1:length(imatch)) {
    
    if(length(imatch[[i]])==0)
    {
      MSMStmpObject<-MSMSdata[[i]]
      attributes(MSMStmpObject)$fileName<-attributes(MSMSdata)$fileName
      listOfUnMapped<-c(listOfUnMapped,MSMStmpObject)
    }
  }
  return(list(mapped=listOfMS2Mapped,unmapped=listOfUnMapped))
}

load(file = inputCamera)

CameraObject<-get(varNameForNextStep)
preprocessingStepsTMP<-preprocessingSteps
mappingResult<-list(mapped=list(),unmapped=list())
for(MS2 in rDataFilesMS2)
{
  load(file = MS2)
  MSMSdata<-get(varNameForNextStep)
  mappingResult<-IntervalMerge(cameraObject = CameraObject,MSMSdata = MSMSdata,PlusTime = rt,
                     MinusTime = rt,ppm = ppm,listOfMS2Mapped = mappingResult$mapped,
                     listOfUnMapped = mappingResult$unmapped)
}

preprocessingSteps<-preprocessingStepsTMP
preprocessingSteps<-c(preprocessingSteps,"mappedMS2")

varNameForNextStep<-as.character("mappingResult")

save(list = c("mappingResult","preprocessingSteps","varNameForNextStep"),file = output)


