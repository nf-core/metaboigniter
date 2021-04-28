#!/usr/bin/env Rscript

options(stringAsfactors = FALSE, useFancyQuotes = FALSE)

# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No file has been specified! Please select a file for conversion!\n")
require(xcms)
require(CAMERA)
require(XML)
consensusXMLFile<-NA
output<-NA

for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]
  if(argCase=="input")
  {
    consensusXMLFile=as.character(value)
  }
  if(argCase=="output")
  {
    output=as.character(value)
  }
  
}


consensusXMLToXCMS<-function(consensusXMLFile=NA)
{

  xmlfile=xmlParse(consensusXMLFile)
  xmltop = xmlRoot(xmlfile)
  xmlSize(xmltop)

  mapListIndex<-as.numeric(which(xmlSApply(xmltop,xmlName)=="mapList"))
  mapNamesAndIDs<-c()
  for(j in 1:xmlSize(xmltop[[mapListIndex]]))
  {
    mapID<-as.numeric(xmlAttrs(xmltop[[mapListIndex]][[j]])["id"])+1
    mapPath<-as.character(xmlAttrs(xmltop[[mapListIndex]][[j]])["name"])
    mapName<-basename(mapPath)
    mapName<-tools::file_path_sans_ext(mapName)
    mapNamesAndIDs<-rbind(mapNamesAndIDs,data.frame(ID=mapID,path=mapPath,name=mapName))
  }

  consensusElementListIndex<- as.numeric(which(xmlSApply(xmltop,xmlName)=="consensusElementList"))
  
  numberOfConsensusElements<-xmlSize(xmltop[[consensusElementListIndex]])
  matrixOfConsensus<-matrix(nrow=numberOfConsensusElements,ncol=8)
  rownames(matrixOfConsensus)<-1:numberOfConsensusElements
  colnames(matrixOfConsensus)<-c("mzmed","mzmin","mzmax","rtmed","rtmin","rtmax","npeaks","featureXMLXCMS")
  listOfConsensusLink<-list()
  
  numberOfSubElements<-0
  for(i in 1:numberOfConsensusElements)
  {
    consensusElement<-xmltop[[consensusElementListIndex]][[i]]
    groupedElementListIndex<-as.numeric(which(xmlSApply(consensusElement,xmlName)=="groupedElementList"))
    numberOfSubElements<-numberOfSubElements+xmlSize(consensusElement[[groupedElementListIndex]])
  }
  matrixOfsubElements<-matrix(nrow=numberOfSubElements,ncol=11)
  rownames(matrixOfsubElements)<-1:numberOfSubElements
  colnames(matrixOfsubElements)<-c("mz","mzmin","mzmax","rt","rtmin","rtmax",
                                 "into","intb","maxo","sn","sample")
  
  matrixOfsubElementsCounter<-1
  for(i in 1:numberOfConsensusElements)
  {
    consensusElement<-xmltop[[consensusElementListIndex]][[i]]
    centroidIndex<-as.numeric(which(xmlSApply(consensusElement,xmlName)=="centroid"))
    
    consensusRT<-as.numeric(xmlAttrs(consensusElement[[centroidIndex]])["rt"])
    consensusMZ<-as.numeric(xmlAttrs(consensusElement[[centroidIndex]])["mz"])
    consensusIT<-as.numeric(xmlAttrs(consensusElement[[centroidIndex]])["it"])
    
    minMZ<-NA
    maxMZ<-NA
    minRT<-NA
    maxRT<-NA
    
    SubElementsIndex<-as.numeric(which(xmlSApply(consensusElement,xmlName)=="groupedElementList"))
    numberOfSubElementstmp<-xmlSize(consensusElement[[groupedElementListIndex]])
    subElementsLinkIndex<-c()
    for(j in 1:numberOfSubElementstmp)
    {
      subElementAttr<-xmlAttrs(consensusElement[[SubElementsIndex]][[j]])
      sample<-as.numeric(subElementAttr["map"])+1
      subRT<-as.numeric(subElementAttr["rt"])
      subMZ<-as.numeric(subElementAttr["mz"])
      subIT<-as.numeric(subElementAttr["it"])
      
      minMZ<-min(c(minMZ,subMZ),na.rm = T)
      maxMZ<-max(c(minMZ,subMZ),na.rm = T)
      minRT<-min(c(minRT,subRT),na.rm = T)
      maxRT<-max(c(minRT,subRT),na.rm = T)  
      matrixOfsubElements[matrixOfsubElementsCounter,]<-
        c(subMZ,subMZ,subMZ,subRT,subRT,subRT,subIT,subIT,subIT,1,sample)
      subElementsLinkIndex<-c(subElementsLinkIndex,matrixOfsubElementsCounter)
      matrixOfsubElementsCounter<-matrixOfsubElementsCounter+1
    }
    matrixOfConsensus[i,]<-c(consensusMZ,minMZ,maxMZ,consensusRT,minRT,maxRT,numberOfSubElementstmp,2)
    listOfConsensusLink[[i]]<-subElementsLinkIndex
  }
  ###### building RT
  rt<-list()
  for(sm in unique(matrixOfsubElements[,"sample"]))
  {
   
    rt[[sm]]<- sort(unique(matrixOfsubElements[matrixOfsubElements[,"sample"]==sm,"rt"]))
  }
  
  outputXCMS<-new("xcmsSet")
  outputXCMS@peaks<-matrixOfsubElements
  outputXCMS@groups<-matrixOfConsensus
  outputXCMS@groupidx<-listOfConsensusLink
  phenoData<-data.frame(class=rep(1,nrow(mapNamesAndIDs)))
  rownames(phenoData)<-as.character(mapNamesAndIDs[,"name"])
  outputXCMS@phenoData<-phenoData
  outputXCMS@rt$raw<-rt
  outputXCMS@rt$corrected<-rt
  
  outputXCMS@peaks[,"mz"]
  outputXCMS@filepaths<-as.character(mapNamesAndIDs[,"path"])
  
  return(outputXCMS)
}


xcmsObject<-consensusXMLToXCMS(consensusXMLFile)

varNameForNextStep<-as.character("xcmsObject")
preprocessingSteps<-c("consensusXMLToXcms")
save(list = c("xcmsObject","varNameForNextStep","preprocessingSteps"),file = output)
