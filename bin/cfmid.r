#!/usr/bin/env Rscript

options(stringAsfactors = FALSE, useFancyQuotes = FALSE)
# This is a helper script to prepare input for CFM-ID
# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No files have been specified!")
inputMSMSparam<-NA
realName<-NA
outputCSV<-NA
tryOffline=F
PPMOverwrite<-NA
PPMPrecursorOverwrite<-NA
absDevOverwrite<-NA
DatabaseOverwrite<-NA
IonizationOverwrite<-NA

CFMPath<-"cfm-id"

candidate_file<-NA
candidate_id<-NA
candidate_inchi_smiles<-NA
candidate_mass<-NA
scoreType<-"Jaccard"
databaseNameColumn<-NA
databaseInChIColumn<-NA
library(tools)
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]

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
  if(argCase=="ppmPrecursor")
  {
    PPMPrecursorOverwrite=as.numeric(value)
  }
  if(argCase=="absDev")
  {
    absDevOverwrite=as.numeric(value)
  }

  if(argCase=="database")
  {
    DatabaseOverwrite=as.character(value)
  }
  if(argCase=="ionization")
  {
    IonizationOverwrite=as.character(value)
  }

  if(argCase=="databaseFile")
  {
    candidate_file=as.character(value)
  }

  if(argCase=="candidate_id")
  {
    candidate_id=as.character(value)
  }

  if(argCase=="candidate_inchi_smiles")
  {
    candidate_inchi_smiles=as.character(value)
  }

  if(argCase=="candidate_mass")
  {
    candidate_mass=as.character(value)
  }

  if(argCase=="scoreType")
  {
    scoreType=as.character(value)
  }

  if(argCase=="databaseNameColumn")
  {
    databaseNameColumn=as.character(value)
  }
  if(argCase=="databaseInChIColumn")
  {
    databaseInChIColumn=as.character(value)
  }


  if(argCase=="output")
  {
    outputCSV=as.character(value)
  }

}



tmpdir<-paste(tempdir(),"/",sep="")

setwd(tmpdir)


cat("Loading ",inputMSMSparam,"\n")

MSMSparams<-readLines(inputMSMSparam)


splitParams<-strsplit(MSMSparams,split = " ",fixed = T)

database=""
ppm<-NA

databaseIndex<-sapply(splitParams,FUN =  function(x){grep(x,pattern = "MetFragDatabaseType",fixed=T)})
database<-tolower(strsplit(splitParams[[1]][[databaseIndex]],split = "=",fixed=T)[[1]][[2]])
if(!is.na(DatabaseOverwrite))
  database<-tolower(DatabaseOverwrite)
# this is for fragments
ppmIndex<-sapply(splitParams,FUN =  function(x){grep(x,pattern = "FragmentPeakMatchRelativeMassDeviation",fixed=T)})
ppm<-as.numeric(strsplit(splitParams[[1]][[ppmIndex]],split = "=",fixed=T)[[1]][[2]])
if(!is.na(PPMOverwrite))
  ppm<-as.numeric(PPMOverwrite)
cat("ppm is set to \"",ppm,"\"\n")
if(is.null(ppm) | is.na(ppm))
  stop("Peak relative mass deviation is not defined!")


# this is for limiting the database
ppmIndex<-sapply(splitParams,FUN =  function(x){grep(x,pattern = "DatabaseSearchRelativeMassDeviation",fixed=T)})
ppmPrecursor<-as.numeric(strsplit(splitParams[[1]][[ppmIndex]],split = "=",fixed=T)[[1]][[2]])
if(!is.na(PPMPrecursorOverwrite))
  ppmPrecursor<-as.numeric(PPMPrecursorOverwrite)
cat("Peak DB relative mass deviationis set to \"",ppmPrecursor,"\"\n")
if(is.null(ppmPrecursor) | is.na(ppmPrecursor))
  stop("Peak DB relative mass deviation is not defined!")


# this is for limiting the database
absDevIndex<-sapply(splitParams,FUN =  function(x){grep(x,pattern = "FragmentPeakMatchAbsoluteMassDeviation",fixed=T)})
absDev<-as.numeric(strsplit(splitParams[[1]][[absDevIndex]],split = "=",fixed=T)[[1]][[2]])
if(!is.na(absDevOverwrite))
  absDev<-as.numeric(absDevOverwrite)
cat("FragmentPeak absolute mass deviation is set to \"",absDev,"\"\n")
if(is.null(absDev) | is.na(absDev))
  stop("FragmentPeak absolute mass deviation is not defined!")


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
  ionization<-as.character(IonizationOverwrite)

cat("Ionization mass is set to \"",ionization,"\"\n")
if(is.na(ionization) | is.null(ionization) | ionization=="")
  stop("ionization is not defined!")

# extract polarity
polarity<-gsub(pattern = "\\[(.*?)\\]",replacement = "",x =ionization ,fixed = F)
if(!polarity%in%c("+","-")){

  stop("failed to extract the polarity! check PrecursorIonType! It must have the polarity sign. It should be like [blabla]+ or [blabla]-")
}


collision<-""
collisionIndex<-sapply(splitParams,FUN =  function(x){grep(x,pattern = "PeakListString",fixed=T)})
collision<-as.character(strsplit(splitParams[[1]][[collisionIndex]],split = "=",fixed=T)[[1]][[2]])
collision<-gsub(pattern = "_",replacement = " ",x = collision,fixed=T)
collision<-gsub(pattern = ";",replacement = "\n",x = collision,fixed=T)
cat("Extracting MS2 information ...\n")
if(is.na(collision) | is.null(collision) | collision=="")
  stop("MS2 ions have not been not found!")

# finding neutral masses
NeutralPrecursorMass<-""
NeutralPrecursorMassIndex<-sapply(splitParams,FUN =  function(x){grep(x,pattern = "NeutralPrecursorMass",fixed=T)})
NeutralPrecursorMass<-as.character(strsplit(splitParams[[1]][[NeutralPrecursorMassIndex]],split = "=",fixed=T)[[1]][[2]])
NeutralPrecursorMass<-as.numeric(NeutralPrecursorMass)

# We need to limit the database to the ones within the range of nmass+-ppms
mzdeviation = (ppmPrecursor*NeutralPrecursorMass)/1000000
mass_upper = NeutralPrecursorMass+mzdeviation
mass_lower = NeutralPrecursorMass-mzdeviation

cat("Creating MS file ...\n")

# This is for a single energy! CFM needs three types of energies. We provide one that is repeating!
toCFM0<-paste("energy0","\n",collision,"\n",sep = "")
toCFM1<-paste("energy1","\n",collision,"\n",sep = "")
toCFM2<-paste("energy2","\n",collision,"\n",sep = "")
toCFM<-paste(toCFM0,toCFM1,toCFM2,sep = "")


# check the database file
if(is.na(candidate_file))
{
  stop("database file not provided")
}
if(!file.exists(candidate_file))
{
  stop("database file does not exist")
}

if(is.na(candidate_id))
{
  stop("candidate_id not provided")
}


if(is.na(candidate_inchi_smiles))
{
  stop("candidate_inchi_smiles not provided")
}

if(is.na(candidate_mass))
{
  stop("candidate_mass not provided")
}



if(is.na(databaseNameColumn))
{
  stop("databaseNameColumn not provided")
}
if(is.na(databaseInChIColumn))
{
  stop("databaseInChIColumn not provided")
}
candidateFile<-read.csv(candidate_file)
if(!candidate_id%in%colnames(candidateFile))
{
  stop("Could not find candidate_id in columns of the candidateFile")
}
if(!candidate_inchi_smiles%in%colnames(candidateFile))
{
  stop("Could not find candidate_inchi_smiles in columns of the candidateFile")
}

if(!candidate_mass%in%colnames(candidateFile))
{
  stop("Could not find candidate_mass in columns of the candidateFile")
}

if(!databaseNameColumn%in%colnames(candidateFile))
{
  stop("Could not find databaseNameColumn in columns of the candidateFile")
}

if(!databaseInChIColumn%in%colnames(candidateFile))
{
  stop("Could not find databaseInChIColumn in columns of the candidateFile")
}


candidateFile<-na.omit(candidateFile)
limitCandiateFile<-candidateFile[,candidate_mass]>=mass_lower & candidateFile[,candidate_mass]<mass_upper
candidateFile<-candidateFile[limitCandiateFile==TRUE,]

if(nrow(candidateFile)<0)
{

  return( cat("Empty results! Nothing will be written out!\n"))
}

if(is.na(scoreType))
{
  stop("scoreType not provided")
}
if(!scoreType%in%c("DotProduct","Jaccard"))
{
  stop("scoreType must be either DotProduct or Jaccard")
}



write.table(candidateFile[,c(candidate_id,candidate_inchi_smiles)],file = "databaseFile.txt",sep = " ",
            row.names = F,quote = F,col.names = F)
writeLines(toCFM,"toCFM.txt")

inpitToCFMFile<-file_path_as_absolute("toCFM.txt")
inpitToCFMFileDatabase<-file_path_as_absolute("databaseFile.txt")

outputFileTMP<-paste(getwd(),"/outputTMP.txt",sep="")
ModelFilfe<-NA
logFile<-NA
if(polarity=="+")
{

logFile<-"/engine/cfm-id-code/cfm/supplementary_material/trained_models/esi_msms_models/metab_se_cfm/param_output0.log"
  ModelFilfe<-"/engine/cfm-id-code/cfm/supplementary_material/trained_models/esi_msms_models/metab_se_cfm/param_config.txt"

}else if(polarity=="-"){
  logFile<-"/engine/cfm-id-code/cfm/supplementary_material/trained_models/esi_msms_models/negative_metab_se_cfm/param_output0.log"
  ModelFilfe<-"/engine/cfm-id-code/cfm/supplementary_material/trained_models/esi_msms_models/negative_metab_se_cfm/param_config.txt"

}
if(is.na(ModelFilfe) | is.na(logFile))
{
  stop("Something wrong with the polarity")
}

if(!file.exists(logFile))
{
  stop("CFM-ID logFile does not exist")
}

if(!file.exists(ModelFilfe))
{
  stop("CFM-ID ModelFilfe does not exist")
}


 toCFMCommand<-paste(CFMPath," ",inpitToCFMFile," IDTMP ", inpitToCFMFileDatabase, " ",
                    100, " ",ppmPrecursor, " ",ppm," ", absDev, " ", logFile, " ", ModelFilfe," ",
                     scoreType," 1 ",outputFileTMP,sep="")


cat("Running CFM-ID using: ", toCFMCommand, "\n")

t1<-try(system(command = toCFMCommand,intern=T))

if(file.exists(outputFileTMP) && file.size(outputFileTMP)>0)
{
  cat("Reading the results file!\n")
  tmpDataResults<-read.table(file = outputFileTMP,header = F,sep = " ",quote = "",check.names = F,stringsAsFactors = F,comment.char = "")
  colnames(tmpDataResults)<-c("IndexCFM",paste(scoreType,"Score",sep="_"),candidate_id,candidate_inchi_smiles)
  if(nrow(tmpDataResults)>0)
  {
   completeDataResults<- merge.data.frame(tmpDataResults,candidateFile,by = c(candidate_id,candidate_inchi_smiles))
   completeDataResults<-completeDataResults[order(completeDataResults[,"IndexCFM"],decreasing = F),]

   parentRT<-as.numeric(strsplit(compound,split = "_",fixed = T)[[1]][2])
   parentFile<-paste((strsplit(compound,split = "_",fixed = T)[[1]][-c(1,2,3)]),collapse = "_")

   if(parentFile==".txt")
   {
     parentFile<-"NotFound"
   }else{
     parentFile<-gsub(pattern = ".txt",replacement = "",x = parentFile,fixed = T)
   }
   cat("Setting headers required for downstream ...\n")

   completeDataResults<-data.frame(fileName=parentFile,parentMZ=parentmass,parentRT=parentRT,completeDataResults)

   colnames(completeDataResults)[which(colnames(completeDataResults)==candidate_id)]<-"Identifier"
   colnames(completeDataResults)[which(colnames(completeDataResults)==databaseInChIColumn)]<-"InChI"
   colnames(completeDataResults)[which(colnames(completeDataResults)==databaseNameColumn)]<-"Name"

   cat("Writing the results ...\n")
   write.csv(x = completeDataResults,file = outputCSV)
   cat("Done!\n")
  }else{
    cat("No result file!")
  }


}else{
  cat("No result file!\n Writting out the log:\n")
  cat(t1)
}
