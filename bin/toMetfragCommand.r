#!/usr/bin/env Rscript

# These fucntions converts raw MS2 ions to Metfrag parameter files. It also finds adducts information
validate.adduct <- function(adduct) {
    if(adduct == "[M+H+NH3]+") {return("[M+NH4]+")}
    if(adduct == "M+Na-2H") {return("M-2H+Na")}
    if(adduct == "M+K-2H") {return("M-2H+K")}
    return (adduct)
}

parameterToCommand<-function(param,outputName="")
{
 param$MetFragPeakListReader<-"de.ipbhalle.metfraglib.peaklistreader.FilteredStringTandemMassPeakListReader"
 param$MetFragCandidateWriter<-"CSV"
 param$PeakListString<-paste(apply(param$PeakList,1,paste,collapse="_"),collapse = ";")
 param$SampleName<-outputName
 param[[which(names(param)=="PeakList")]]<-NULL

 param$MetFragDatabaseType
 toOutput<-""
 for(i in 1:length(param))
 {
   if(i==1) {toOutput<- paste(names(param)[i],"=",param[[i]],sep="")
   } else {toOutput<- paste(toOutput," ",names(param)[i],"=",param[[i]],sep="")}
 }
 ### the output is specid_rt_mz_intensity[_origfilename]. specid is an enumerative number and origfilename is read from the original mzml file if included
 cat(toOutput, file = outputName, sep="\n")
}
require(CAMERA)
require(stringr)
toMetfragCommand<-function(mappedMS2=NA,
                           unmappedMS2=NA,
                           cameraObject=NA,
                           searchMultipleChargeAdducts=F,
                           includeUnmapped=T,includeMapped=T,
                           settingsObject=list(),preprocess=NA,savePath="",minPeaks=0,maxSpectra=NA,
			   maxPrecursorMass = NA, minPrecursorMass = NA, mode = "pos", primary = T)
{
  peakList<-getPeaklist(cameraObject)
  file.origin<-""
  numberSpectraWritten <- 0
  if(includeMapped)
  {
    searchChargeFlag<-F
    searchAdductsFlag<-F
    massTraceNames<-names(mappedMS2)
    metFragResult<-c()
    for(x in massTraceNames)
    {
      seachAdducts<-NA
      seachCharge<-NA
      searchChargeFlag<-F
      intb <- peakList[as.numeric(x),"intb"]
      if(peakList[as.numeric(x),"adduct"]=="" & peakList[as.numeric(x),"isotopes"]=="")
      {
        adduct<-NA
        neutralMASS<-peakList[as.numeric(x),"mz"]
        searchChargeFlag<-T
        searchAdductsFlag<-T
        seachAdducts<-adduct
      }else if(peakList[as.numeric(x),"adduct"]!="")
      {
        if(str_count(peakList[as.numeric(x),"adduct"], "]")==1)
        {
          adduct<-gsub(" ","",str_extract(peakList[as.numeric(x),"adduct"], "\\[.*\\]*. "))
          neutralMASS<-as.numeric(str_extract(peakList[as.numeric(x),"adduct"], " .*"))
          searchChargeFlag<-F
        }else
        {
          adduct<-""
          neutralMASS<-peakList[as.numeric(x),"mz"]
          adduct<-unique(sapply(strsplit(str_extract_all(peakList[as.numeric(x),"adduct"], "\\[.*?\\]")[[1]]," "),
                                function(x){x[[1]]}))
          searchChargeFlag<-T
          seachAdducts<-adduct
        }
      }else if(peakList[as.numeric(x),"isotopes"]!="")
      {

        isotopID<- str_extract(peakList[as.numeric(x),"isotopes"], "\\[\\d*\\]")

        monoIsotopic<-grepl("[M]",peakList[ grepl(isotopID,peakList[,"isotopes"],fixed=T),"isotopes"],fixed=T)
        adduct<- gsub(" ","",
                      str_extract(peakList[ grepl(isotopID,peakList[,"isotopes"],fixed=T),][monoIsotopic,"adduct"],"\\[.*\\]*. "))

        tmpMASS<-as.numeric(str_extract(peakList[ grepl(isotopID,peakList[,"isotopes"],fixed=T),][monoIsotopic,"adduct"], " .*"))
        if(adduct!="" & !is.na(adduct)[1])
        {
      if(str_count(peakList[ grepl(isotopID,peakList[,"isotopes"],fixed=T),][monoIsotopic,"adduct"], "]")==1)
        {
          adduct<-gsub(" ","",str_extract(peakList[ grepl(isotopID,peakList[,"isotopes"],fixed=T),][monoIsotopic,"adduct"], "\\[.*\\]*. "))
          neutralMASS<-as.numeric(str_extract(peakList[ grepl(isotopID,peakList[,"isotopes"],fixed=T),][monoIsotopic,"adduct"], " .*"))
          searchChargeFlag<-F
        }else
        {
          adduct<-""
          neutralMASS<-peakList[as.numeric(x),"mz"]
          adduct<-unique(sapply(strsplit(str_extract_all(peakList[ grepl(isotopID,peakList[,"isotopes"],fixed=T),][monoIsotopic,"adduct"], "\\[.*?\\]")[[1]]," "),
                                function(x){x[[1]]}))
          searchChargeFlag<-T
          seachAdducts<-adduct
        }

        }else
        {
          isoTMP<-gsub("\\[.*\\]","",peakList[as.numeric(x),"isotopes"])
          charges<-str_extract(isoTMP,"\\d+")

          if(is.na(charges))
          {
            adduct<-NA
            neutralMASS<-peakList[as.numeric(x),"mz"]
            searchChargeFlag<-T
            seachCharge<-1
          }else
          {
            neutralMASS<-peakList[as.numeric(x),"mz"]
            searchChargeFlag<-T
            seachCharge<-charges
          }

        }

      }

      mappedMS2TMP<-NA
      if(class(mappedMS2[[x]])=="list")
      {
        mappedMS2TMP<-mappedMS2[[x]]
      } else if(class(mappedMS2[[x]])=="Spectrum2")
      {
        mappedMS2TMP<-list(mappedMS2[[x]])
      }
      for(MSMS in mappedMS2TMP)
      {
        if(preprocess)
        {

          MSMS@centroided<-F
          MSMS@polarity<-as.integer(1)
          MSMS@smoothed<-F
          MSMS<-MSnbase::pickPeaks(MSMS)

        }
        MS2<-as.matrix(cbind(MSMS@mz,MSMS@intensity))
        # if number MS/MS peaks is too low
    	  if(length(MSMS@mz) == 0) { next }
	      if(!is.na(minPeaks) & dim(MS2)[1] < minPeaks) { next }
        if(!searchChargeFlag)
        {
          settingsObject[["NeutralPrecursorMass"]]<-neutralMASS
          settingsObject[["PeakList"]]<-MS2
          settingsObject[["IsPositiveIonMode"]]<-"True"
          if(mode == "neg") {settingsObject[["IsPositiveIonMode"]]<-"False"}
            modeSuffix<-"+"
          if(mode == "neg") {modeSuffix<-"-"}
	        settingsObject[["PrecursorIonType"]]<-validate.adduct(adduct)
          fileName<-""
          # add id, rt, neu_mass, intensity, orig file name
	  file.origin <- gsub("\\?.*", "", gsub(".*/", "", attributes(MSMS)$fileName))
          if(file.origin == "") {
		      fileName<-paste(as.character(numberSpectraWritten+1),"_",as.character(MSMS@rt),"_",as.character(round(MSMS@precursorMz,4)),"_",as.character(intb),".txt",sep="")
	       } else {
		      fileName<-paste(as.character(numberSpectraWritten+1),"_",as.character(MSMS@rt),"_",as.character(round(MSMS@precursorMz,4)),"_",as.character(intb),"_",file.origin,".txt",sep="")
         }
         if(savePath!="")
          fileName<-paste(savePath,"/",fileName,sep="")
         if(!is.na(maxPrecursorMass) & maxPrecursorMass < neutralMASS) { next }
         if(!is.na(minPrecursorMass) & minPrecursorMass > neutralMASS) { next }
	       if(is.na(maxSpectra) || maxSpectra > numberSpectraWritten) {
         	parameterToCommand(settingsObject,fileName)
	 	      numberSpectraWritten<-numberSpectraWritten+1
	       }
        } else if(searchChargeFlag & searchMultipleChargeAdducts)
        {

          allChargesHits<-list()
          allAdductForSearch<-adductCalculator(mz = neutralMASS,charge = seachCharge,
                                               adduct = gsub("\\[|\\]","",seachAdducts),mode = mode,primary = primary)
          for(k in 1:nrow(allAdductForSearch))
          {
            mass <- allAdductForSearch[k,"correctedMS"]
            settingsObject[["NeutralPrecursorMass"]]<-mass
            settingsObject[["PeakList"]]<-MS2
            settingsObject[["IsPositiveIonMode"]]<-"True"
            if(mode == "neg") {settingsObject[["IsPositiveIonMode"]]<-"False"}
            modeSuffix<-"+"
            if(mode == "neg") {modeSuffix<-"-"}
            settingsObject[["PrecursorIonType"]]<-paste("[",validate.adduct(as.character(allAdductForSearch[k,"adductName"])),"]", modeSuffix, sep="")
            fileName<-""
            file.origin <- gsub("\\?.*", "", gsub(".*/", "", attributes(MSMS)$fileName))
            if(file.origin == "") {
                 fileName<-paste(as.character(numberSpectraWritten+1),"_",as.character(MSMS@rt),"_",as.character(round(MSMS@precursorMz,4)),"_",as.character(intb),".txt",sep="")
            } else {
                 fileName<-paste(as.character(numberSpectraWritten+1),"_",as.character(MSMS@rt),"_",as.character(round(MSMS@precursorMz,4)),"_",as.character(intb),"_",file.origin,".txt",sep="")
            }
            if(savePath!="")
              fileName<-paste(savePath,"/",fileName,sep="")
            if(!is.na(maxPrecursorMass) & maxPrecursorMass < mass) { next }
            if(!is.na(minPrecursorMass) & minPrecursorMass > mass) { next }
            if(is.na(maxSpectra) || maxSpectra > numberSpectraWritten) {
	    	      parameterToCommand(settingsObject,fileName)
	    	      numberSpectraWritten<-numberSpectraWritten+1
	          }
          }
        }
      }
    }
  }

  if(includeUnmapped)
  {
    for(p in 1:length(unmappedMS2))
    {
      MSMS<-unmappedMS2[[p]]
      if(preprocess)
      {

        MSMS@centroided<-F
        MSMS@polarity<-as.integer(1)
        MSMS@smoothed<-F
        MSMS<-MSnbase::pickPeaks(MSMS)

      }
      neutralMASS<-MSMS@precursorMz
      MS2<-as.matrix(cbind(MSMS@mz,MSMS@intensity))
      adduct<-"[M+H]+"
      if(mode == "neg") {adduct<-"[M-H]-"}
      if(length(MSMS@mz) == 0) { next }
      if(!is.na(minPeaks) & dim(MS2)[1] < minPeaks) { next }
      if(!searchMultipleChargeAdducts)
      {
        settingsObject[["NeutralPrecursorMass"]]<-neutralMASS
        settingsObject[["PeakList"]]<-MS2
	      settingsObject[["IsPositiveIonMode"]]<-"True"
        if(mode == "neg") {settingsObject[["IsPositiveIonMode"]]<-"False"}
	      settingsObject[["PrecursorIonType"]]<-adduct
        fileName<-""
        intb<-MSMS@precursorIntensity
	      if(file.origin == "") {
             fileName<-paste(as.character(numberSpectraWritten+1),"_",as.character(MSMS@rt),"_",as.character(round(MSMS@precursorMz,4)),"_",as.character(intb),".txt",sep="")
        } else {
             fileName<-paste(as.character(numberSpectraWritten+1),"_",as.character(MSMS@rt),"_",as.character(round(MSMS@precursorMz,4)),"_",as.character(intb),"_",file.origin,".txt",sep="")
        }
        if(savePath!="")
          fileName<-paste(savePath,"/",fileName,sep="")
        if(!is.na(maxPrecursorMass) & maxPrecursorMass < neutralMASS) { next }
        if(!is.na(minPrecursorMass) & minPrecursorMass > neutralMASS) { next }
	      if(is.na(maxSpectra) || maxSpectra > numberSpectraWritten) {
		      parameterToCommand(settingsObject,fileName)
          numberSpectraWritten<-numberSpectraWritten+1
	      }
      }else if(searchMultipleChargeAdducts)
      {
        allChargesHits<-list()
        allAdductForSearch<-adductCalculator(mz = neutralMASS,charge = NA,
                                             adduct = NA,mode = mode, primary = primary)
        for(k in 1:nrow(allAdductForSearch))
        {
          mass <- allAdductForSearch[k,"correctedMS"]
          settingsObject[["NeutralPrecursorMass"]]<-mass
          settingsObject[["PeakList"]]<-MS2
	        settingsObject[["IsPositiveIonMode"]]<-"True"
	        if(mode == "neg") {settingsObject[["IsPositiveIonMode"]]<-"False"}
	        modeSuffix<-"+"
	        if(mode == "neg") {modeSuffix<-"-"}
	        settingsObject[["PrecursorIonType"]]<-paste("[",as.character(allAdductForSearch[k,"adductName"]),"]", modeSuffix, sep="")
          fileName<-""
          if(file.origin == "") {
             fileName<-paste(as.character(numberSpectraWritten+1),"_",as.character(MSMS@rt),"_",as.character(round(MSMS@precursorMz,4)),"_",as.character(intb),".txt",sep="")
          } else {
             fileName<-paste(as.character(numberSpectraWritten+1),"_",as.character(MSMS@rt),"_",as.character(round(MSMS@precursorMz,4)),"_",as.character(intb),"_",file.origin,".txt",sep="")
          }
          if(savePath!="")
            fileName<-paste(savePath,"/",fileName,sep="")
          if(!is.na(maxPrecursorMass) & maxPrecursorMass < mass) { next }
          if(!is.na(minPrecursorMass) & minPrecursorMass > mass) { next }
          if(is.na(maxSpectra) || maxSpectra > numberSpectraWritten) {
		        parameterToCommand(settingsObject,fileName)
	 	        numberSpectraWritten<-numberSpectraWritten+1
	        }
        }
      }
    }

  }
}
