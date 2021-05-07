#!/usr/bin/env Rscript
options(stringAsfactors = FALSE, useFancyQuotes = FALSE)
# This script ouput metabolite abundance to Workflow4Metabolomics format. It can also do imputation, normalization etc
# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No file has been specified!\n")
require(xcms)
require(CAMERA)
require(intervals)


ppmCal<-function(run,ppm)
{
  return((run*ppm)/1000000)
}
metFragToCamera<-function(metFragSearchResult=NA,cameraObject=NA,ppm=5,MinusTime=5,PlusTime=5,method="fast")
{
  #metFragSearchResult<-bb
  IDResults<-metFragSearchResult
  #cameraObject<-an
  listofPrecursorsmz<-c()
  listofPrecursorsmz<-IDResults[,"parentMZ"]
  listofPrecursorsrt<-IDResults[,"parentRT"]
  CamerartLowColumnIndex<-which(colnames(cameraObject@groupInfo)=="rtmin")
  CamerartHighColumnIndex<-which(colnames(cameraObject@groupInfo)=="rtmax")
  CameramzColumnIndex<-which(colnames(cameraObject@groupInfo)=="mz")
    imatch=NA
  if(method=="regular")
      {
  MassRun1<-Intervals_full(cbind(listofPrecursorsmz,listofPrecursorsmz))

  MassRun2<-Intervals_full(cbind(cameraObject@groupInfo[,CameramzColumnIndex]-
                                   ppmCal(cameraObject@groupInfo[,CameramzColumnIndex],ppm),
                                 cameraObject@groupInfo[,CameramzColumnIndex]+
                                   ppmCal(cameraObject@groupInfo[,CameramzColumnIndex],ppm)))

  Mass_iii <- interval_overlap(MassRun1,MassRun2)



  TimeRun1<-Intervals_full(cbind(listofPrecursorsrt,listofPrecursorsrt))

  TimeRun2<-Intervals_full(cbind(cameraObject@groupInfo[,CamerartLowColumnIndex]-MinusTime,
                                 cameraObject@groupInfo[,CamerartHighColumnIndex]+PlusTime))
  Time_ii <- interval_overlap(TimeRun1,TimeRun2)

  imatch = mapply(intersect,Time_ii,Mass_iii)
   }else if(method=="fast")
      {
      featureMzs<-cbind(cameraObject@groupInfo[,CameramzColumnIndex]-
                    ppmCal(cameraObject@groupInfo[,CameramzColumnIndex],ppm),
                  cameraObject@groupInfo[,CameramzColumnIndex]+
                    ppmCal(cameraObject@groupInfo[,CameramzColumnIndex],ppm))

featureRTs<-cbind(cameraObject@groupInfo[,CamerartLowColumnIndex]-MinusTime,
                  cameraObject@groupInfo[,CamerartHighColumnIndex]+PlusTime)

imatch<-list()
for(i in 1:length(listofPrecursorsmz))
{
  mz<-listofPrecursorsmz[i]
  rt<-listofPrecursorsrt[i]

  imatch[[i]]<-which(featureMzs[,1]<mz & featureMzs[,2]>mz & featureRTs[,1]<rt & featureRTs[,2]>rt)


}
 }else if (method=="par"){
      featureMzs<-cbind(cameraObject@groupInfo[,CameramzColumnIndex]-
                    ppmCal(cameraObject@groupInfo[,CameramzColumnIndex],ppm),
                  cameraObject@groupInfo[,CameramzColumnIndex]+
                    ppmCal(cameraObject@groupInfo[,CameramzColumnIndex],ppm))

featureRTs<-cbind(cameraObject@groupInfo[,CamerartLowColumnIndex]-MinusTime,
                  cameraObject@groupInfo[,CamerartHighColumnIndex]+PlusTime)
     imatch <-mclapply(c(1:length(listofPrecursorsmz)),FUN =function(x) { which(featureMzs[,1]<listofPrecursorsmz[x] & featureMzs[,2]>listofPrecursorsmz[x] & featureRTs[,1]<listofPrecursorsrt[x] & featureRTs[,2]>listofPrecursorsrt[x])},mc.cores=ncore)

      }else{stop("Method should be either fast,par and regular")}

  listOfMS2Mapped<-list()
  for (i in 1:length(imatch)) {
    for(j in imatch[[i]])
    {
      if(is.null(listOfMS2Mapped[[as.character(j)]]))
      {
        listOfMS2Mapped[[as.character(j)]]<-data.frame(IDResults[i,],stringsAsFactors = F)
      }else
      {
        listOfMS2Mapped[[as.character(j)]]<-
          rbind(listOfMS2Mapped[[as.character(j)]],data.frame(IDResults[i,],stringsAsFactors = F))
      }

    }
  }
  return(list(mapped=listOfMS2Mapped))
}


ppmTol<-5
rtTol = 10
higherTheBetter<-T
scoreColumn<-"q.value"
impute<-T
typeColumn<-"type"
selectedType<-"p"
renameCol<-"rename"
rename<-T
onlyReportWithID<-T
combineReplicate<-F
combineReplicateColumn<-"rep"
iflog<-F
sampleCoverage<-0
sampleCoverageMethod<-"global"
ncore=1
Ifnormalize<-NA
scoreInput<-NA
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]

  if(argCase=="inputcamera")
  {
    inputCamera=as.character(value)
  }
  if(argCase=="inputscores")
  {
    scoreInput=as.character(value)
  }
  if(argCase=="inputpheno")
  {
    phenotypeInfoFile=as.character(value)
  }
  if(argCase=="ppm")
  {
    ppmTol=as.numeric(value)
  }
  if(argCase=="rt")
  {
    rtTol=as.numeric(value)
  }
  if(argCase=="higherTheBetter")
  {
    higherTheBetter=as.logical(value)
  }
  if(argCase=="scoreColumn")
  {
    scoreColumn=as.character(value)
  }
  if(argCase=="impute")
  {
    impute=as.logical(value)
  }
  if(argCase=="typeColumn")
  {
    typeColumn=as.character(value)
  }
  if(argCase=="selectedType")
  {
    selectedType=as.character(value)
  }
  if(argCase=="rename")
  {
    rename=as.logical(value)
  }
  if(argCase=="renameCol")
  {
    renameCol=as.character(value)
  }
  if(argCase=="onlyReportWithID")
  {
    onlyReportWithID=as.logical(value)
  }
  if(argCase=="combineReplicate")
  {
    combineReplicate=as.logical(value)
  }
  if(argCase=="combineReplicateColumn")
  {
    combineReplicateColumn=as.character(value)
  }
   if(argCase=="log")
  {
    iflog=as.logical(value)
  }
  if(argCase=="sampleCoverage")
  {
    sampleCoverage=as.numeric(value)
  }
  if(argCase=="sampleCoverageMethod")
  {
    sampleCoverageMethod=as.character(value)
  }
  if(argCase=="outputPeakTable")
  {
    outputPeakTable=as.character(value)
  }
  if(argCase=="outputVariables")
  {
    outputVariables=as.character(value)
  }
  if(argCase=="outputMetaData")
  {
    outputMetaData=as.character(value)
  }
  if(argCase=="ncore")
  {
    ncore=as.numeric(value)
  }
    if(argCase=="normalize")
  {
    Ifnormalize=as.numeric(value)
  }

}



load(inputCamera)
cameraObject<-get(varNameForNextStep)
cameraPeakList<-getPeaklist(cameraObject)
cameraInformation<-NA
if(grep(pattern = "adduct",x = names(cameraPeakList),fixed = T))
	{
	cameraInformation<-cameraPeakList[,c("mz","mzmin","mzmax","rt","rtmin","rtmax","npeaks","isotopes","adduct","pcgroup")]
	}else{
	cameraInformation<-cameraPeakList[,c("mz","mzmin","mzmax","rt","rtmin","rtmax","npeaks")]
	}

colnames(cameraInformation)<-paste("xcmsCamera_",colnames(cameraInformation),sep = "")

phenotypeInfo<-read.csv(file = phenotypeInfoFile,stringsAsFactors = F)
#sepScore<-","
#if(scoreColumn=="q.value")
  sepScore="\t"

if(!is.na(scoreInput))
{
metfragRes<-read.table(file = scoreInput,header = T,sep = sepScore,quote="",stringsAsFactors = F,comment.char = "")

mappedToCamera<-metFragToCamera(metFragSearchResult = metfragRes,
                                cameraObject = cameraObject,MinusTime = rtTol,PlusTime = rtTol,ppm = ppmTol,method="par")



  VariableData<-data.frame(matrix("Unknown",nrow = nrow(cameraPeakList),
                                                                ncol = (ncol(metfragRes)+1+ncol(cameraInformation))),stringsAsFactors = F)


  colnames(VariableData)<-c("variableMetadata",colnames(metfragRes),colnames(cameraInformation))
  VariableData[,"variableMetadata"]<-paste("variable_",1:nrow(cameraPeakList),sep="")
VariableData[,colnames(cameraInformation)]<-cameraInformation

for(rnName in rownames(cameraPeakList))
{
  if(rnName %in% names(mappedToCamera$mapped))
  {
    tmpId<-mappedToCamera$mapped[[rnName]]
    if(higherTheBetter)
    {
      tmpId<-tmpId[which.max(tmpId[,scoreColumn]),]
    }else{
      tmpId<-tmpId[which.min(tmpId[,scoreColumn]),]
    }

    VariableData[VariableData[,"variableMetadata"]==paste("variable_",rnName,sep=""),
                 c(2:(ncol(metfragRes)+1))]<-tmpId

  }
}

VariableData$imputed<-"No"
if(impute)
{

  toBeImputed<-which(VariableData[,2]=="Unknown")
  pcgroups<-VariableData[toBeImputed,"xcmsCamera_pcgroup"]

  for(pcgr in unique(pcgroups))
  {
    selectedFeatures<-
      VariableData[,"variableMetadata"]%in%(VariableData[VariableData[,"xcmsCamera_pcgroup"]==pcgr,"variableMetadata"]) &
      VariableData[,"parentMZ"]!="Unknown"

    if(any(selectedFeatures))
    {
      tmpIDs<-VariableData[selectedFeatures,]
      tmpId<-NA
      if(higherTheBetter)
      {
        tmpId<-tmpIDs[which.max(tmpIDs[,scoreColumn]),]
      }else
      {
        tmpId<-tmpIDs[which.min(tmpIDs[,scoreColumn]),]
      }


      imputedVariables<- (VariableData[VariableData[,"xcmsCamera_pcgroup"]==pcgr,"variableMetadata"])

      imputedVariables<- VariableData[,"variableMetadata"]%in%imputedVariables & VariableData[,2]=="Unknown"

      VariableData[imputedVariables,c(2:(ncol(metfragRes)+1))]<-tmpId[,c(2:ncol(tmpId))]
      VariableData[imputedVariables,"imputed"]<-"yes"

    }
  }

}

}else{

VariableData<-data.frame(matrix("Unknown",nrow = nrow(cameraPeakList),
                                                              ncol = (2+ncol(cameraInformation))),stringsAsFactors = F)
colnames(VariableData)<-c("variableMetadata","extraColumn",colnames(cameraInformation))
VariableData[,"variableMetadata"]<-paste("variable_",1:nrow(cameraPeakList),sep="")
VariableData[,colnames(cameraInformation)]<-cameraInformation
}



peakMatrix<-c()
peakMatrixNames<-c()
peakMatrixTMP<-cameraPeakList
technicalReps<-c()

phenotypeInfo<-phenotypeInfo[phenotypeInfo[,typeColumn]==selectedType,]
for(i in 1:nrow(cameraObject@xcmsSet@phenoData))
{
  index<-which(phenotypeInfo==rownames(cameraObject@xcmsSet@phenoData)[i],arr.ind = T)[1]
  if(!is.na(index))
  {
    peakMatrix<-cbind(peakMatrix, peakMatrixTMP[,rownames(cameraObject@xcmsSet@phenoData)[i]])
    if(rename)
    {

      peakMatrixNames<-c(peakMatrixNames,phenotypeInfo[index,renameCol])
    }else
    {
      peakMatrixNames<-c(peakMatrixNames,phenotypeInfo[index,1])
      #peakMatrixNames<-c(peakMatrixNames,rownames(cameraObject@xcmsSet@phenoData)[i])
    }
    if(combineReplicate)
    {
      technicalReps<-c(technicalReps,phenotypeInfo[index,combineReplicateColumn])
    }

  }
}




peakMatrix<-data.frame(peakMatrix)
colnames(peakMatrix)<-peakMatrixNames


sampleMetaData<-c()
phenotypeInfo<-phenotypeInfo[,!grepl(pattern = "step_",x = colnames(phenotypeInfo),fixed=T)]
if(rename)
{

  sampleMetaData<-phenotypeInfo[,c(renameCol,colnames(phenotypeInfo)[colnames(phenotypeInfo)!=renameCol])]
}else
{
  sampleMetaData<-phenotypeInfo

}
colnames(sampleMetaData)[1]<-"sampleMetadata"

technicalReps<-technicalReps[match(sampleMetaData[,1],colnames(peakMatrix))]
peakMatrix<-peakMatrix[,match(sampleMetaData[,1],colnames(peakMatrix))]
peakMatrixNames<-colnames(peakMatrix)
if(combineReplicate)
{
  newpheno<-c()
  newNames<-c()
  combinedPeakMatrix<-c()
  techs<-unique(technicalReps)
  for(x in techs)
  {
    if(ncol(data.frame(peakMatrix[,technicalReps==x]))>1)
    {

      dataTMP<-apply(data.frame(peakMatrix[,technicalReps==x]),MARGIN = 1,FUN = median,na.rm=T)
      newNames<-c(newNames,as.character(unique(peakMatrixNames[technicalReps==x]))[1])
      newpheno<-rbind(newpheno,sampleMetaData[sampleMetaData[,combineReplicateColumn]==x,][1,])
      combinedPeakMatrix<-cbind(combinedPeakMatrix,dataTMP)
    }else
    {
      dataTMP<-peakMatrix[,technicalReps==x]
      newNames<-c(newNames,as.character(unique(peakMatrixNames[technicalReps==x]))[1])
      newpheno<-rbind(newpheno,sampleMetaData[sampleMetaData[,combineReplicateColumn]==x,][1,])
      combinedPeakMatrix<-cbind(combinedPeakMatrix,dataTMP)
    }
  }

  peakMatrix<-  combinedPeakMatrix
  peakMatrixNames<-newNames
  sampleMetaData<-newpheno[,colnames(newpheno)!=combineReplicateColumn]
}



peakMatrix<-data.frame(peakMatrix)
colnames(peakMatrix)<-peakMatrixNames

if(iflog)
{
peakMatrix<-log2(peakMatrix)
}
normalize.median <- function(x, weights = NULL) {
	l <- dim(x)[2]

	if(is.null(weights)) {
		for(j in 1:l)
			x[, j] <- x[, j] - median(x[, j], na.rm = TRUE)
	} else {
		for(j in 1:l)
			x[, j] <- x[, j] - weighted.median(x[, j], weights[, j],
				na.rm = TRUE)
	}

	x
}
 # normalize.regression
# based on pek
norm.regression <- function(x) {
		y<-rowMedians(as.matrix(x), na.rm=TRUE)
		for(j in 1:ncol(x)){
		fit<-lm(y~x[,j],na.action=na.exclude)
		x[,j] <- predict(fit,na.action=na.exclude)
		}
return(x)
}
normalize.reference <- function(x) {
{
		sel <-1
		y<-1
		for(j in 1:ncol(x)){
		as.matrix(sel)
		sel[j] <- length(which(!is.na(x[,j])))
		ref<-which.max(sel[])
		}
		for(j in 1:ncol(x))
		{
		     y[j]<-median(x[, j]-x[,ref], na.rm = TRUE)
		     x[, j] <- (x[, j]-y[j])

}

return(x)
}
}

if(!is.na(Ifnormalize))
{
    if(Ifnormalize==1)
peakMatrix<-limma::normalizeCyclicLoess(peakMatrix)
    if(Ifnormalize==2)
peakMatrix<-normalize.median(peakMatrix)
    if(Ifnormalize==3)
peakMatrix<-normalize.reference(peakMatrix)
    if(Ifnormalize==4)
peakMatrix<-norm.regression(peakMatrix)

}
if(!onlyReportWithID & !is.na(scoreInput))
{
  peakMatrix<-peakMatrix[VariableData[,2]!="Unknown",]
  VariableData<-VariableData[VariableData[,2]!="Unknown",]
}

sep_covWithGroup<-function(X,groups)
{
  lft_f<-X


  dt<-list()
  dt_cov<-list()
  for(x in unique(groups))
  {
    assign(x,lft_f[,groups==x])
    assign(paste(x,"_cov",sep=""),(apply((!is.na(get(x))),1,function(x1){sum(x1)})/dim(get(x))[2])*100)
    dt[[x]]<-get(x)
    dt_cov[[x]]<-get(paste(x,"_cov",sep=""))
  }


  return(list(dt,dt_cov))
}

if(sampleCoverage>0)
{
coverageLogical<-rep(T,nrow(peakMatrix))
if(sampleCoverageMethod=="global")
{

groups<-rep("g",nrow(sampleMetaData))
coverage<-sep_covWithGroup(peakMatrix,groups)
coverageLogical<-coverage[[2]]$g>sampleCoverage
}else{

groups<-sampleMetaData[,sampleCoverageMethod]

coverage<-sep_covWithGroup(peakMatrix,groups)

for(gr in unique(groups))
{
coverageLogical<-coverageLogical & (coverage[[2]][[gr]]>sampleCoverage)
}

}
peakMatrix<-peakMatrix[coverageLogical==T,]
VariableData<-VariableData[coverageLogical==T,]
}
peakMatrix<-cbind.data.frame(dataMatrix=VariableData[,"variableMetadata"],peakMatrix,stringsAsFactors = F)
VariableData<-sapply(VariableData, gsub, pattern="\'|#", replacement="")
VariableData<-VariableData[apply(is.na(peakMatrix),1,sum)!=(ncol(peakMatrix)-1),]
peakMatrix<-peakMatrix[apply(is.na(peakMatrix),1,sum)!=(ncol(peakMatrix)-1),]
#peakMatrix[VariableData[,2]!="Unknown",1]<-VariableData[VariableData[,2]!="Unknown","Identifier"]
#VariableData[VariableData[,2]!="Unknown",1]<-VariableData[VariableData[,2]!="Unknown","Identifier"]

write.table(x = peakMatrix,file = outputPeakTable,
            row.names = F,quote = F,sep = "\t")
write.table(x = VariableData,file = outputVariables,
            row.names = F,quote = F,sep = "\t")

write.table(x = sampleMetaData,file = outputMetaData,
            row.names = F,quote = F,sep = "\t")
