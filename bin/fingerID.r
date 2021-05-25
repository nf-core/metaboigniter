#!/usr/bin/env Rscript
options(stringAsfactors = FALSE, useFancyQuotes = FALSE)
# This is a helper script for fixing parameter file for FingerID
# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No files have been specified!")
inputMSMSparam<-NA
realName<-NA
outputCSV<-"."
tryOffline=F
PPMOverwrite<-NA
PPM_MS2_Overwrite<-NA
DatabaseOverwrite<-NA
IonizationOverwrite<-NA
numberofCompounds=10
numberofCompoundsforIon<-numberofCompounds
timeout=10 # this is timeout for csi.
timeoutTree<-10
siriusPath<-"sh /usr/bin/sirius/bin/sirius"
sirCores<-2
canopus<-F
UseHeuristic<-T
mzToUseHeuristicOnly<-650
mzToUseHeuristic<-300
canopusoutputCSV<-NA
library(tools)
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]

  if(argCase=="UseHeuristic")
  {
    UseHeuristic=as.logical(value)
  }
  if(argCase=="mzToUseHeuristicOnly")
  {
    mzToUseHeuristicOnly=as.numeric(value)
  }
  if(argCase=="mzToUseHeuristic")
  {
    mzToUseHeuristic=as.numeric(value)
  }
  if(argCase=="canopusOutput")
  {
    canopusoutputCSV=as.character(value)
  }
  if(argCase=="canopus")
  {
    canopus<-as.logical(value)
  }
  if(argCase=="ncores")
    {
    sirCores<-as.numeric(value)
    }
  if(argCase=="numberofCompounds")
  {
    numberofCompounds=as.numeric(value)
  }
  if(argCase=="numberofCompoundsIon")
  {
    numberofCompoundsforIon=as.numeric(value)
  }
if(argCase=="timeout")
  {
    timeout=as.numeric(value)
  }
  if(argCase=="timeoutTree")
  {
    timeoutTree=as.numeric(value)
  }
  if(argCase=="realName")
  {
    realName=as.character(value)
  }
  if(argCase=="input")
  {
    inputMSMSparam=as.character(value)
  }
  if(argCase=="tryOffline")
  {
    tryOffline=as.logical(value)
  }
  if(argCase=="ppm")
  {
    PPMOverwrite=as.numeric(value)
  }
  if(argCase=="ppmms2")
  {
    PPM_MS2_Overwrite=as.numeric(value)
  }
  if(argCase=="database")
  {
    DatabaseOverwrite=as.character(value)
  }
  if(argCase=="ionization")
  {
    IonizationOverwrite=as.character(value)
  }
  if(argCase=="output")
  {
    outputCSV=as.character(value)
  }


}



tmpdir<-paste(".","/",sep="")

setwd(tmpdir)
inputMSMSparamList<-inputMSMSparam

if(canopus)
{
  if(is.na(canopusoutputCSV))
  {
    stop("When canopus true, a path for output of canopus must be provided via canopusoutputCSV parameter!")
  }
}

if(as.logical(file.info(inputMSMSparam)["isdir"]))
{
  inputMSMSparamList<-list.files(inputMSMSparam,full.names = T)
}
if(file.exists("toCSI.ms"))
{
  file.remove("toCSI.ms")
}
if(dir.exists("outputTMP1"))
{
  unlink("outputTMP1",recursive = T,force = T)
}


for(inputMSMSparam in inputMSMSparamList)
{


cat("Loading ",inputMSMSparam,"\n")

MSMSparams<-readLines(inputMSMSparam)


splitParams<-strsplit(MSMSparams,split = " ",fixed = T)

database=""
ppm<-NA

databaseIndex<-sapply(splitParams,FUN =  function(x){grep(x,pattern = "MetFragDatabaseType",fixed=T)})
database<-tolower(strsplit(splitParams[[1]][[databaseIndex]],split = "=",fixed=T)[[1]][[2]])
if(!is.na(DatabaseOverwrite))
  database<-tolower(DatabaseOverwrite)
cat("Database is set to \"",database,"\"\n")
if(database=="localcsv")
  stop("Local database is not supported yet! use any of the following: all, pubchem, bio, kegg, hmdb")

ppmIndex<-sapply(splitParams,FUN =  function(x){grep(x,pattern = "DatabaseSearchRelativeMassDeviation",fixed=T)})
ppm<-as.numeric(strsplit(splitParams[[1]][[ppmIndex]],split = "=",fixed=T)[[1]][[2]])
if(!is.na(PPMOverwrite))
  ppm<-as.numeric(PPMOverwrite)
cat("ppm is set to \"",ppm,"\"\n")
if(is.null(ppm) | is.na(ppm))
  stop("Peak relative mass deviation is not defined!")

# set PPM for MS2

ppmms2Index<-sapply(splitParams,FUN =  function(x){grep(x,pattern = "FragmentPeakMatchRelativeMassDeviation",fixed=T)})
ppm_ms2<-as.numeric(strsplit(splitParams[[1]][[ppmms2Index]],split = "=",fixed=T)[[1]][[2]])
if(!is.na(PPM_MS2_Overwrite))
  ppm_ms2<-as.numeric(PPM_MS2_Overwrite)
cat("ppm for MS2 is set to \"",ppm_ms2,"\"\n")
if(is.null(ppm_ms2) | is.na(ppm_ms2))
  stop("MS2 peak relative mass deviation is not defined!")

#### create MS file
compound<-basename(inputMSMSparam)
parentmass<-as.numeric(strsplit(compound,split = "_",fixed = T)[[1]][3])
cat("Parent mass is set to \"",parentmass,"\"\n")
if(is.null(parentmass) | is.na(parentmass))
  stop("Parent mass is not defined!")


ionization<-""
ionizationIndex<-sapply(splitParams,FUN =  function(x){grep(x,pattern = "PrecursorIonType",fixed=T)})
ionization<-as.character(strsplit(splitParams[[1]][[ionizationIndex]],split = "=",fixed=T)[[1]][[2]])
if(!is.na(PPMOverwrite))
  IonizationOverwrite<-as.character(IonizationOverwrite)

cat("Ionization mass is set to \"",ionization,"\"\n")
if(is.na(ionization) | is.null(ionization) | ionization=="")
  stop("ionization is not defined!")


collision<-""
collisionIndex<-sapply(splitParams,FUN =  function(x){grep(x,pattern = "PeakListString",fixed=T)})
collision<-as.character(strsplit(splitParams[[1]][[collisionIndex]],split = "=",fixed=T)[[1]][[2]])
collision<-gsub(pattern = "_",replacement = " ",x = collision,fixed=T)
collision<-gsub(pattern = ";",replacement = "\n",x = collision,fixed=T)
cat("Extracting MS2 information ...\n")
if(is.na(collision) | is.null(collision) | collision=="")
  stop("MS2 ions have not been not found!")


cat("Creating MS file ...\n")
toCSI<-paste(">compound ",compound,"\n",
             ">parentmass ",parentmass,"\n",
             ">ionization ",ionization,"\n",
             ">AdductSettings.detectable ",ionization,"\n",
             ">AdductSettings.fallback ",ionization,"\n",
             ">MS1MassDeviation.allowedMassDeviation ",ppm," ppm","\n",
             ">MS2MassDeviation.allowedMassDeviation ",ppm_ms2," ppm\n",
             ">NumberOfCandidatesPerIon ",numberofCompoundsforIon,"\n",
             ">StructureSearchDB ",database,"\n",
             ">Timeout.secondsPerInstance ",timeout,"\n",
             ">Timeout.secondsPerTree ",timeoutTree,"\n\n",
             ">collision\n",collision,"\n",sep = "")

write(toCSI,"toCSI.ms",append = T)
}



if(!is.numeric(sirCores) & sirCores<1)
{
  stop("Number of cores (ncore) but be an integer number higher than 0!")
}else{
  cat("Running CSI with",sirCores,"cores\n")
}


if(!is.numeric(timeout) & timeout<0)
{
  stop("timeout should be 0 or higher!")
}else{
  cat("Running CSI with",timeout,"seconds timeout! Ions taking more than",timeout,"seconds will not be considered (0=unlimited)!\n")
}

if(!is.numeric(timeoutTree) & timeoutTree<0)
{
  stop("timeoutTree should be 0 or higher!")
}else{
  cat("Running CSI with",timeoutTree,"seconds timeoutTree! Trees taking more than",timeoutTree,"seconds will not be considered (0=unlimited)!\n")
}

if(UseHeuristic)
{
 if((!is.numeric(mzToUseHeuristicOnly) & mzToUseHeuristicOnly<0)|(!is.numeric(mzToUseHeuristic) & mzToUseHeuristic<0))
 {
  stop("mzToUseHeuristicOnly and mzToUseHeuristic must be numberic and higher than 0")
 }else{
 cat("Using heuristics with ",mzToUseHeuristicOnly, " as mzToUseHeuristicOnly and ",mzToUseHeuristic, "as mzToUseHeuristic!\n")
 }
}

inpitToCSIFile<-file_path_as_absolute("toCSI.ms")


outputFolder<-paste(getwd(),"/outputTMP1",sep="")
if(canopus)
{

if(UseHeuristic)
{



  toCSICommand<-paste(siriusPath," -i ", inpitToCSIFile," --output ",outputFolder, " --cores ",sirCores, " config ",
  " --UseHeuristic.mzToUseHeuristicOnly ", mzToUseHeuristicOnly, " --UseHeuristic.mzToUseHeuristic ", mzToUseHeuristic," formula"," -c ",numberofCompounds," fingerid canopus", " 2>&1",sep="")

}else{
toCSICommand<-paste(siriusPath," -i ", inpitToCSIFile," --output ",outputFolder, " --cores ",sirCores, " config",
                    " formula"," -c ",numberofCompounds," fingerid canopus", " 2>&1",sep="")
}

}else{

  if(UseHeuristic)
  {

  toCSICommand<-paste(siriusPath," -i ", inpitToCSIFile," --output ",outputFolder, " --cores ",sirCores, " config", "sirius --UseHeuristic.mzToUseHeuristicOnly ", mzToUseHeuristicOnly, " --UseHeuristic.mzToUseHeuristic ", mzToUseHeuristic,

                      " formula"," -c ",numberofCompounds," fingerid", " 2>&1",sep="")
  }else{
  toCSICommand<-paste(siriusPath," -i ", inpitToCSIFile," --output ",outputFolder, " --cores ",sirCores, " config",

                      " formula"," -c ",numberofCompounds," fingerid", " 2>&1",sep="")
  }



}


cat("Running CSI using", toCSICommand, "\n")

unlink(recursive = T,x = outputFolder)


t1<-try(system(command = toCSICommand,intern = T))



if(!is.null(attr(t1,which = "status")) && attr(t1,which = "status")==1){
  cat("::: Error :::\n")
  stop(t1)
}else if(!is.null(attr(t1,which = "status")) && attr(t1,which = "status")==124){
cat("Took too long! Nothing will be output!\n")
}

cat("CSI finished! Trying to load the results ...\n")
requiredOutput<-paste(outputFolder,"/","compound_identifications.tsv",sep = "")
if(file.exists(requiredOutput))
{
    CSI_results<-read.table(requiredOutput,header = T,sep = "\t",quote = "",check.names = F,stringsAsFactors = F,comment.char = "")
    csi_input<-readLines(con = inpitToCSIFile)
    csi_input<-csi_input[grepl(csi_input,pattern = ">compound ",fixed = T)]
    csi_input<-gsub(pattern = ">compound ",replacement = "",x = csi_input,fixed = T)
    for(cid in unique(CSI_results[,"id"]))
    {
    compound<-gsub(pattern = "[[:digit:]]_toCSI_",replacement = "",x = cid)
    tmpData<-read.table(paste(outputFolder,"/",cid,"/","structure_candidates.tsv",sep = ""),
                        header = T,sep = "\t",quote = "",check.names = F,stringsAsFactors = F,comment.char = "")



    if(nrow(tmpData)!=0)
    {
      tmpData[tmpData$name=="\"\"","name"]<-"NONAME"
      parentRT<-as.numeric(strsplit(compound,split = "_",fixed = T)[[1]][2])
      parentMZ<-as.numeric(strsplit(compound,split = "_",fixed = T)[[1]][3])
      parentFile<-paste((strsplit(compound,split = "_",fixed = T)[[1]][-c(1,2,3)]),collapse = "_")

      if(parentFile==".txt")
      {
        parentFile<-"NotFound"
      }else{
        parentFile<-gsub(pattern = ".txt",replacement = "",x = parentFile,fixed = T)
      }
      cat("Setting headers required for downstream ...\n")
      tmpData<-data.frame(fileName=parentFile,parentMZ=parentMZ,parentRT=parentRT,tmpData)
      tmpData<-cbind(data.frame(Name=tmpData[,"name"],
                                "Identifier"=paste("Metabolite_",1:nrow(tmpData),sep=""),
                                "InChI"=tmpData[,"InChI"]),score=tmpData[,"CSI.FingerIDScore"],tmpData)
      cat("Writing the results ...\n")
      write.csv(x = tmpData,file = paste(outputCSV,"/",compound,".csv",sep = ""))
      cat("Done!\n")
    }else{
      cat("Empty results! Nothing will be output!\n")
    }
    }

}else{
  cat("Empty results! Nothing will be written out!\n")
}


requiredOutput<-paste(outputFolder,"/","canopus_summary.tsv",sep = "")
if(file.exists(requiredOutput) & canopus==T)
{
  cat("Loading canopus output ...\n")
  canopus_results<-read.table(requiredOutput,header = T,sep = "\t",quote = "",check.names = F,stringsAsFactors = F,comment.char = "")
  write.csv(x = canopus_results,file = canopusoutputCSV)
  cat("write canopus output ...\n")
}
