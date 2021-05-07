#!/usr/bin/env Rscript

options(stringAsfactors = FALSE, useFancyQuotes = FALSE)
# This script is used to convert XCMS and CAMERA to featureXML file
# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No file has been specified! Please select a file for conversion!\n")
require(xcms)
require(CAMERA)
require(XML)
require(stringr)
previousEnv<-NA
output<-NA
intensityColumn="into"
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]
  if(argCase=="input")
  {
    previousEnv=as.character(value)
  }
   if(argCase=="intensityColumn")
  {
    intensityColumn=as.character(value)
  }
  if(argCase=="output")
  {
    output=as.character(value)
  }


}

cameraToFeatureXML<-function(CameraObject=NA, intensityColumn="into")
{
  peaks<-getPeaklist(CameraObject)

  FeatureXMLHeader<-
    '<?xml version="1.0" encoding="ISO-8859-1"?>
  <featureMap version="1.8" id="fm_11508727577524311138" xsi:noNamespaceSchemaLocation="http://open-ms.sourceforge.net/schemas/FeatureXML_1_8.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  '
  peaksWithoutIsotope<-peaks[is.na(str_extract(peaks[,"isotopes"], "\\[\\d*\\]")),]
  peaksWithtIsotope<-peaks[!is.na(str_extract(peaks[,"isotopes"], "\\[\\d*\\]")),]



  singleFeatureOriginal<-'<feature id="featureID">
  <position dim="0">centroidRT</position>
  <position dim="1">centroidmz</position>
  <intensity>IntensityCentriod</intensity>
  <quality dim="0">quanlityScorert</quality>
  <quality dim="1">quanlityScoremz</quality>
  <overallquality>overalQualityScore</overallquality>
  <charge>chargeCal</charge>
  convexhullInfo
  <UserParam type="string" name="label" value="ADDUCTINFO"/>
userParamIsoIntOriginal
  </feature>'

  convexhullInfoOriginal<- '<convexhull nr="convexhullID">
  <pt x="borderStartrt" y="borderStartmz" />
  <pt x="borderEndrt" y="borderEndmz" />
  </convexhull>'
  allFeatures<-""
  userParamIsoIntOriginal<-'<UserParam type="float" name="masstrace_intensity_ISOID" value="ISOINT"/>'

  ############ for features without isotope
  for(i in c(1:nrow(peaksWithoutIsotope)))
  {
    ADDUCTINFO<-""
    singleFeature<-singleFeatureOriginal
    singleUserParam<-userParamIsoIntOriginal
    convexhullInfo <-convexhullInfoOriginal
    featureID<-rownames(peaksWithoutIsotope)[i]
    centroidRT<-peaksWithoutIsotope[i,"rt"]
    centroidmz<-peaksWithoutIsotope[i,"mz"]
    borderStartmz<-peaksWithoutIsotope[i,"mzmin"]
    borderStartrt<-peaksWithoutIsotope[i,"rtmin"]
    borderEndmz<-peaksWithoutIsotope[i,"mzmax"]
    borderEndrt<-peaksWithoutIsotope[i,"rtmax"]
    IntensityCentriod<-peaksWithoutIsotope[i,intensityColumn]
    quanlityScoremz<-1
    quanlityScorert<-1
    overalQualityScore<-1
    chargeCal<-0
    singleFeature<-gsub("featureID",featureID,singleFeature)
    singleFeature<-gsub("centroidRT",centroidRT,singleFeature)
    singleFeature<-gsub("centroidmz",centroidmz,singleFeature)
    singleFeature<-gsub("IntensityCentriod",IntensityCentriod,singleFeature)
    singleFeature<-gsub("quanlityScoremz",quanlityScoremz,singleFeature)
    singleFeature<-gsub("quanlityScorert",quanlityScorert,singleFeature)
    singleFeature<-gsub("overalQualityScore",overalQualityScore,singleFeature)
    singleFeature<-gsub("chargeCal",chargeCal,singleFeature)
    adduct<-as.character(peaksWithoutIsotope[i,"adduct"])
    singleFeature<-gsub("ADDUCTINFO",adduct,singleFeature)

    singleUserParam<-gsub("ISOID","0",singleUserParam)
    singleUserParam<-gsub("ISOINT",as.character(IntensityCentriod),singleUserParam)

    singleFeature<-gsub("userParamIsoIntOriginal",singleUserParam,singleFeature)

    convexhullInfo<-gsub("convexhullID",0,convexhullInfo)
    convexhullInfo<-gsub("borderStartmz",borderStartmz,convexhullInfo)
    convexhullInfo<-gsub("borderStartrt",borderStartrt,convexhullInfo)
    convexhullInfo<-gsub("borderEndmz",borderEndmz,convexhullInfo)
    convexhullInfo<-gsub("borderEndrt",borderEndrt,convexhullInfo)

    singleFeature<-gsub("convexhullInfo",convexhullInfo,singleFeature)

    allFeatures<-paste(allFeatures,singleFeature,"\n")

  }

  #### for features with isotope
  isotopeIDs<-unique(str_extract(peaksWithtIsotope[,"isotopes"], "\\[\\d*\\]"))
  featureList<-'<featureList count="nFeatures">'
  featureList<-gsub("nFeatures",nrow(peaksWithoutIsotope)+length(isotopeIDs),featureList)
  for(isotopeID in isotopeIDs)
  {
    isotopeID<-"[1]"
    peaksWithtIsotopeTMP<-
      peaksWithtIsotope[grepl(isotopeID,peaksWithtIsotope[,"isotopes"],fixed=T),]

    MonoIsoMass<-peaksWithtIsotopeTMP[grepl("[M]",peaksWithtIsotopeTMP[,"isotopes"],fixed=T),]

    #we take the
    i<-1
    singleFeature<-singleFeatureOriginal
    adduct<-""
    featureID<-rownames(MonoIsoMass)[i]
    centroidRT<-MonoIsoMass[i,"rt"]
    centroidmz<-MonoIsoMass[i,"mz"]
    adduct<-as.character(MonoIsoMass[i,"adduct"])
    IntensityCentriod<-MonoIsoMass[i,intensityColumn]
    quanlityScoremz<-1
    quanlityScorert<-1
    overalQualityScore<-1

    isoTMP<-gsub("\\[.*\\]","",MonoIsoMass[i,"isotopes"])
    charges<-str_extract(isoTMP,"\\d+")
    if(is.na(charges))charges<-1

    chargeCal<-charges
    singleFeature<-gsub("featureID",featureID,singleFeature)
    singleFeature<-gsub("centroidRT",centroidRT,singleFeature)
    singleFeature<-gsub("centroidmz",centroidmz,singleFeature)
    singleFeature<-gsub("IntensityCentriod",IntensityCentriod,singleFeature)
    singleFeature<-gsub("quanlityScoremz",quanlityScoremz,singleFeature)
    singleFeature<-gsub("quanlityScorert",quanlityScorert,singleFeature)
    singleFeature<-gsub("overalQualityScore",overalQualityScore,singleFeature)
    singleFeature<-gsub("chargeCal",chargeCal,singleFeature)
    singleFeature<-gsub("ADDUCTINFO",adduct,singleFeature)
    #### now find isotopeID

    isotopeIDLocal<-str_extract(str_extract(peaksWithtIsotopeTMP[,"isotopes"], "\\[M\\+\\d*\\]"),
                                "\\d+")

    isotopeIDLocal[is.na(isotopeIDLocal)]<-"0"
    isotopeIDLocal<-isotopeIDLocal[order(isotopeIDLocal)]
    peaksWithtIsotopeTMP<-peaksWithtIsotopeTMP[order(isotopeIDLocal),]
    allConvexhullInfo<-""

    allUserParamIsoInt<-""
     for(i in 1:nrow(peaksWithtIsotopeTMP))
    {
      convexhullInfo <-convexhullInfoOriginal
      borderStartmz<-peaksWithtIsotopeTMP[i,"mzmin"]
      borderStartrt<-peaksWithtIsotopeTMP[i,"rtmin"]
      borderEndmz<-peaksWithtIsotopeTMP[i,"mzmax"]
      borderEndrt<-peaksWithtIsotopeTMP[i,"rtmax"]
      isoIntensity<-peaksWithtIsotopeTMP[i,intensityColumn]
      convexhullInfo<-gsub("convexhullID",isotopeIDLocal[i],convexhullInfo)
      convexhullInfo<-gsub("borderStartmz",borderStartmz,convexhullInfo)
      convexhullInfo<-gsub("borderStartrt",borderStartrt,convexhullInfo)
      convexhullInfo<-gsub("borderEndmz",borderEndmz,convexhullInfo)
      convexhullInfo<-gsub("borderEndrt",borderEndrt,convexhullInfo)
      allConvexhullInfo<-paste(allConvexhullInfo,convexhullInfo,sep="\n")
      singleUserParam<-userParamIsoIntOriginal

      singleUserParam<-gsub("ISOID",isotopeIDLocal[i],singleUserParam)
      singleUserParam<-gsub("ISOINT",as.character(isoIntensity),singleUserParam)

      allUserParamIsoInt<-paste(allUserParamIsoInt,singleUserParam,sep="\n")


    }

    singleFeature<-gsub("convexhullInfo",allConvexhullInfo,singleFeature)
    singleFeature<-gsub("userParamIsoIntOriginal",allUserParamIsoInt,singleFeature)

    allFeatures<-paste(allFeatures,singleFeature,"\n")

  }


  FeatureEndTag<-'	</featureList>
</featureMap>'

  result<-paste(FeatureXMLHeader,"\n",featureList,"\n",allFeatures,"\n",FeatureEndTag,sep="")
  return(result)
}

if(is.na(previousEnv) | is.na(output)) stop("Both input and output need to be specified!\n")

load(file = previousEnv)

toConvertor<-get(varNameForNextStep)

featureXML<-cameraToFeatureXML(toConvertor,intensityColumn)

cat(featureXML,file=output)
