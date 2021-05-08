#!/usr/bin/env Rscript

options(stringAsfactors = FALSE, useFancyQuotes = FALSE)
# This script calculate error scores for metabolite identification
library(tools)
# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No file has been specified!")
input<-NA
output<-NA
score<-"FragmenterScore"
readTable=F
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]

  if(argCase=="input")
  {
    input=as.character(value)
  }

  if(argCase=="output")
  {
    output=as.character(value)
  }
    if(argCase=="score")
  {
    score=as.character(value)
  }
if(argCase=="readTable")
{
readTable=as.logical(value)
}


}
metfragRes<-NA
if(readTable==T)
{
metfragRes<-read.table(file = input,header = T,sep = "\t",quote="",stringsAsFactors = F,comment.char = "")
}else{
metfragRes<-read.csv(input)
}

CompoundNameCol<-""
if("CompoundName"%in%colnames(metfragRes))
{
CompoundNameCol<-"CompoundName"
}else{
CompoundNameCol<-"Name"
}
dataForPassatuttoTMP<-metfragRes[,c(CompoundNameCol,"Identifier","InChI",score)]
names(metfragRes)<-paste("METFRAG_",names(metfragRes),sep="")
names(dataForPassatuttoTMP)<-c("query",	"target",	"target_inchi",	"score")

metFragForPassatutto<-cbind(dataForPassatuttoTMP,metfragRes)

metFragForPassatutto<-metFragForPassatutto[order(metFragForPassatutto$score,decreasing = T),]

dir.create("MetFragtemp")

directoryForResults<-file_path_as_absolute("MetFragtemp")

write.table(x = metFragForPassatutto,file = paste(directoryForResults,"/input.txt",sep=""),
            row.names = F,quote = F,sep = "\t")

passatuttoPath<-
"java -cp \"/usr/bin/Passatutto/lib/*\" QValueEstimator -target TARGETFILE -out OUTPUTFILE -method EBA"

passatuttoPath<-gsub(pattern = "TARGETFILE",
                     replacement = paste(directoryForResults,"/input.txt",sep=""),
                     x = passatuttoPath,fixed = T)
passatuttoPath<-gsub(pattern = "OUTPUTFILE",
                     replacement = paste(directoryForResults,"/output.txt",sep=""),
                     x = passatuttoPath,fixed=T)



system(passatuttoPath)

PEPscores<-read.table(file = paste(directoryForResults,"/output.txt",sep=""),header = T,sep = "\t",quote="",stringsAsFactors = F,comment.char = "")
PEPscores<-PEPscores[,-c(1,2,3,4)]
colnames(PEPscores)<-gsub(pattern = "METFRAG_",replacement = "",x = colnames(PEPscores),fixed = T)


write.table(x = PEPscores,file = output,
            row.names = F,quote = F,sep = "\t")
