#!/usr/bin/env Rscript

# this is a helper function to create a library charactrization file
require(intervals)
ppmCal<-function(run,ppm)
{
  return((run*ppm)/1000000)
}
IntervalMerge<-function(cameraObject,MSMSdata,libraryInfo,ppm,listOfMS2Mapped=list(),listOfUnMapped=list(),whichmz=NA,requiredHeader=NA){

  if(whichmz=="c")
  {

listofPrecursorsmz<-libraryInfo[,requiredHeader["mzCol"]]



CameramzColumnIndex<-which(colnames(cameraObject@groupInfo)=="mz")

MassRun1<-Intervals_full(cbind(listofPrecursorsmz,listofPrecursorsmz))

MassRun2<-Intervals_full(cbind(cameraObject@groupInfo[,CameramzColumnIndex]-
                                 ppmCal(cameraObject@groupInfo[,CameramzColumnIndex],ppm),
                               cameraObject@groupInfo[,CameramzColumnIndex]+
                                 ppmCal(cameraObject@groupInfo[,CameramzColumnIndex],ppm)))

imatch <- interval_overlap(MassRun1,MassRun2)
returnData<-c()
for (i in 1:length(imatch)) {
  for(j in imatch[[i]])
  {
    startRT<-cameraObject@groupInfo[c(j),"rtmin"]
    endRT<-cameraObject@groupInfo[c(j),"rtmax"]
    startMZ<-cameraObject@groupInfo[c(j),"mzmin"]
    endMZ<-cameraObject@groupInfo[c(j),"mzmax"]
    centermz<-cameraObject@groupInfo[c(j),"mz"]
    centerrt<-cameraObject@groupInfo[c(j),"rt"]
    intensity<-cameraObject@groupInfo[c(j),"into"]
    fileName<-paste(sapply(MSMSdata$mapped[[as.character(j)]],function(x){attr(x,"fileName")}),collapse = ";")

    ID<-libraryInfo[i,requiredHeader["compundID"]]
    Name<-libraryInfo[i,requiredHeader["compoundName"]]
    nmass<-libraryInfo[i,requiredHeader["mzCol"]]


    parentmzs<-paste(sapply(MSMSdata$mapped[[as.character(j)]],function(x){x@precursorMz}),collapse=";")
    parentrts<-paste(sapply(MSMSdata$mapped[[as.character(j)]],function(x){x@rt}),collapse=";")
    parentInts<-paste(sapply(MSMSdata$mapped[[as.character(j)]],function(x){x@precursorIntensity}),collapse=";")
    MS2s<-paste(sapply(MSMSdata$mapped[[as.character(j)]],function(x){paste(paste(x@mz,x@intensity,sep="_"),collapse=":")}),collapse=";")

    TMP<-data.frame(startRT=startRT,endRT=endRT,
                    startMZ=startMZ,endMZ=endMZ,
                    centermz=centermz,
                    centerrt=centerrt,
                    intensity=intensity,
                    fileName=fileName,
                    ID=ID,
                    Name=Name,
                    nmass=nmass,
                    parentmzs=parentmzs,
                    parentrts=parentrts,
                    parentInts=parentInts,
                    MS2s=MS2s,stringsAsFactors = F)

    if(is.null(returnData))
    {
      returnData<-(TMP)

    }else
      {

      returnData<-rbind.data.frame(returnData,TMP,stringsAsFactors = F)

    }
	}
	}
  return(returnData)
  }


  if(whichmz=="f")
  {

listofPrecursorsmz<-libraryInfo[,requiredHeader["mzCol"]]





CameramzColumnIndexmin<-which(colnames(cameraObject@groupInfo)=="mzmin")
CameramzColumnIndexmax<-which(colnames(cameraObject@groupInfo)=="mzmax")

MassRun1<-Intervals_full(cbind(listofPrecursorsmz,listofPrecursorsmz))

MassRun2<-Intervals_full(cbind(cameraObject@groupInfo[,CameramzColumnIndexmin]-
                                 ppmCal(cameraObject@groupInfo[,CameramzColumnIndexmin],ppm),
                               cameraObject@groupInfo[,CameramzColumnIndexmax]+
                                 ppmCal(cameraObject@groupInfo[,CameramzColumnIndexmax],ppm)))

imatch <- interval_overlap(MassRun1,MassRun2)
returnData<-c()
for (i in 1:length(imatch)) {
  for(j in imatch[[i]])
  {
    startRT<-cameraObject@groupInfo[c(j),"rtmin"]
    endRT<-cameraObject@groupInfo[c(j),"rtmax"]
    startMZ<-cameraObject@groupInfo[c(j),"mzmin"]
    endMZ<-cameraObject@groupInfo[c(j),"mzmax"]
    centermz<-cameraObject@groupInfo[c(j),"mz"]
    centerrt<-cameraObject@groupInfo[c(j),"rt"]
    intensity<-cameraObject@groupInfo[c(j),"into"]
    fileName<-paste(sapply(MSMSdata$mapped[[as.character(j)]],function(x){attr(x,"fileName")}),collapse = ";")

    ID<-libraryInfo[i,requiredHeader["compundID"]]
    Name<-libraryInfo[i,requiredHeader["compoundName"]]
    nmass<-libraryInfo[i,requiredHeader["mzCol"]]


    parentmzs<-paste(sapply(MSMSdata$mapped[[as.character(j)]],function(x){x@precursorMz}),collapse=";")
    parentrts<-paste(sapply(MSMSdata$mapped[[as.character(j)]],function(x){x@rt}),collapse=";")
    parentInts<-paste(sapply(MSMSdata$mapped[[as.character(j)]],function(x){x@precursorIntensity}),collapse=";")
    MS2s<-paste(sapply(MSMSdata$mapped[[as.character(j)]],function(x){paste(paste(x@mz,x@intensity,sep="_"),collapse=":")}),collapse=";")

    TMP<-data.frame(startRT=startRT,endRT=endRT,
                    startMZ=startMZ,endMZ=endMZ,
                    centermz=centermz,
                    centerrt=centerrt,
                    intensity=intensity,
                    fileName=fileName,
                    ID=ID,
                    Name=Name,
                    nmass=nmass,
                    parentmzs=parentmzs,
                    parentrts=parentrts,
                    parentInts=parentInts,
                    MS2s=MS2s,stringsAsFactors = F)

    if(is.null(returnData))
    {
      returnData<-(TMP)

    }else
      {

      returnData<-rbind.data.frame(returnData,TMP,stringsAsFactors = F)

    }
	}
	}
  return(returnData)
  }
}


require(CAMERA)
require(stringr)


createLibrary<-function(MSMSdata=NA,
                           cameraObject=NA,
						   libraryInfo=NA,requiredHeader=NA,whichmz="f",
                           includeUnmapped=T,includeMapped=T,
                           preprocess=NA,savePath="",minPeaks=0,maxSpectra=NA,
			   maxPrecursorMass = NA, minPrecursorMass = NA,ppm)
{




data<-IntervalMerge(cameraObject=cameraObject,
MSMSdata=MSMSdata,libraryInfo=libraryInfo,ppm=ppm,listOfMS2Mapped=list(),listOfUnMapped=list(),whichmz=whichmz,requiredHeader=requiredHeader)


MSlibrary<-data
MSlibrary<-MSlibrary[MSlibrary[,"MS2s"]!="",]
newLib<-c()
for(k in 1:nrow(MSlibrary))
{
  hitTMP<-MSlibrary[k,]
  parentmzs<-strsplit(x = hitTMP[,"parentmzs"],split = ";",fixed = T)[[1]]
  parentrts<-strsplit(x = hitTMP[,"parentrts"],split = ";",fixed = T)[[1]]
  parentInts<-strsplit(x = hitTMP[,"parentInts"],split = ";",fixed = T)[[1]]
  parentMS2s<-strsplit(x = hitTMP[,"MS2s"],split = ";",fixed = T)[[1]]
  fileNames<-strsplit(x = hitTMP[,"fileName"],split = ";",fixed = T)[[1]]
  for(p in 1:length(parentmzs))
  {
    MS2sTMPLib<-parentMS2s[[p]]
    TempLib<-data.frame(MSlibrary[k,!colnames(MSlibrary)%in%c("parentmzs","parentrts","fileName","parentInts","MS2s")])


       temp<-t(sapply(X=(strsplit(x = strsplit(x = MS2sTMPLib,split = ":",fixed = T)[[1]],split = "_",fixed = T)),FUN = function(x){c(mz=as.numeric(x[1]),
                                                                                                                                         int=as.numeric(x[2]))}))
       temp<-data.frame(temp)
	   temp<-temp[temp$int!=0,]
       mzs<-  paste(temp$mz,collapse = ";")
       ints<-paste(temp$int,collapse = ";")

       TempLib$MS2mz<-parentmzs[[p]]
       TempLib$MS2rt<-parentrts[[p]]
       TempLib$MS2intensity<-parentInts[[p]]

       TempLib$MS2fileName<-fileNames[[p]]


       TempLib$MS2mzs<-mzs
       TempLib$MS2intensities<-ints
       TempLib$featureGroup<-k
	   if(length(temp$mz)>=minPeaks)
       newLib<-rbind(newLib,TempLib)

  }
}

write.csv(x=newLib,file=savePath)

}
