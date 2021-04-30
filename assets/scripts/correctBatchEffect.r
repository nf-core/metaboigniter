#!/usr/bin/env Rscript

# Check if the limma and argparse are available, if not then install them
list.of.packages <- c("argparse", "limma")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

# load argparse for parsing arguments
suppressWarnings(library("argparse"))

# set require arguments
parser <- ArgumentParser()

# set require arguments.
parser$add_argument("-v", "--verbose", action="store_true", default=TRUE,
                    help="Print extra output [default]")

parser$add_argument("-q", "--quietly", action="store_false", 
                    dest="verbose", help="Print little output")

parser$add_argument("-in", "--dataMatrix_in", type="character",
                    help="Input data matrix containing peaks")

parser$add_argument("-out", "--dataMatrix_out", type="character",
                    help="Output data matrix containing peaks")

parser$add_argument("-s", "--sampleMetadata_in", type="character", 
                    help="Input data matrix containing sample metadata")



parser$add_argument("-b1", "--batch1", type="character", 
                    help="one of the column names (first row) of your sample metadata showing batch variable (this will be factored)")

parser$add_argument("-b2", "--batch2", type="character", 
                    help="one of the column names (first row) of your sample metadata showing batch variable (this will be factored)")

parser$add_argument("-c", "--covariates", type="character", 
                    help="one or more of the column names (first row) of your sample metadata showing batch variable. If more than one column selected, it should be separated by space or , or \\| or tab or |")


parser$add_argument("-g", "--group", type="character",
                    help="Optional treatment conditions to be preserved")
					

# parse arguments
args <- parser$parse_args()


if(is.null(args$dataMatrix_out))
{
  errorMessage<-"No output file has been specified. You MUST specify the output file see the help (-h)!"
  write(errorMessage,stderr())
  stop(errorMessage,
       call. = FALSE)
}

if(is.null(args$dataMatrix_in))
{
  errorMessage<-"No input file has been specified. You MUST specify the input file see the help (-h)!"
  write(errorMessage,stderr())
  stop(errorMessage,
       call. = FALSE)
}


if(is.null(args$batch1) & is.null(args$batch2) & is.null(args$covariates))
{
  errorMessage<-"No batch have been specified. You MUST specify one or more of the column names (first row) of your sample metadata showing batch!"
  write(errorMessage,stderr())
  stop(errorMessage,
       call. = FALSE)
}

if ( args$verbose ) { 
  write("Loading data matrix...\n", stdout()) 
}

# Load peak matrix

xMN <- t(as.matrix(read.table(args$dataMatrix_in,
                              check.names = FALSE,
                              header = TRUE,
                              row.names = 1,
                              sep = "\t",
                              comment.char = "")))


if ( args$verbose ) { 
  write("Loading sample data...\n", stdout()) 
}

# Load sample metaData
samDF <- read.table(args$sampleMetadata_in,
                    check.names = FALSE,
                    header = TRUE,
                    row.names = 1,
                    sep = "\t",
                    comment.char = "")

# generate error message if row and column names are not identical
if(!identical(rownames(xMN), rownames(samDF)))
{
  errorMessage<-"Sample names (or number) in the data matrix (first row) and sample metadata (first column) are not identical; use the 'Check Format' module in the 'Quality Control' section"
  write(errorMessage,stderr())
  stop(errorMessage,
       call. = FALSE)
}

batch1<-NULL
# check if batch 1 is in meta data
if(!is.null(args$batch1) && args$batch1%in%colnames(samDF))
{
  batch1 <- matrix(samDF[, args$batch1], ncol = 1, dimnames = list(rownames(xMN), args$batch1))
  
}else if(!is.null(args$batch1)){
  
  errorMessage<-"Batch1 was not found in the column names (first row) of your sample metadata!"
  write(errorMessage,stderr())
  stop(errorMessage,
       call. = FALSE)
}

batch2<-NULL
# check if batch 2 is in meta data

if(!is.null(args$batch2) && args$batch2%in%colnames(samDF))
{
  batch2 <- matrix(samDF[, args$batch2], ncol = 1, dimnames = list(rownames(xMN), args$batch2))
}else if(!is.null(args$batch2)){

  
  errorMessage<-"Batch2 was not found in the column names (first row) of your sample metadata!"
  write(errorMessage,stderr())
  stop(errorMessage,
       call. = FALSE)
}

# for variable, first split it and then check all of them
covariates<-NULL

covariatesColumns<-ifelse(!is.null(args$covariates),
                          yes = sapply(strsplit(x = args$covariates,split = "\\;|,| |\\||\\t"),function(x){x}),
                          no = NA)
if(!is.null(args$covariates))
{
  covariatesColumns<-sapply(strsplit(x = args$covariates,split = "\\;|,| |\\||\\t"),function(x){x})
}else{covariates<-na}

if(!is.na(covariatesColumns) && all(covariatesColumns%in%colnames(samDF)))
{
  covariates <- samDF[, covariatesColumns]
}else if(!is.na(covariatesColumns)){
  
  notFoundColumns<-paste(covariatesColumns[!covariatesColumns%in%colnames(samDF)],sep=", ")
  errorMessage<-paste(notFoundColumns,"was/were not found in the column names (first row) of your sample metadata!")
  write(errorMessage,stderr())
  stop(errorMessage,
       call. = FALSE)
}else{
  covariates<-NULL
}

if ( args$verbose ) { 
  write("all data loaded successfully! Now correcting for peaks ...\n", stdout()) 
}

if ( args$verbose ) { 
  write("Loading limme package ...\n", stdout()) 
}
suppressWarnings(library(limma))

group<-NULL
design<-NULL
# check if batch 1 is in meta data
if(!is.null(args$group) && args$group%in%colnames(samDF))
{
  group <- matrix(samDF[, args$group], ncol = 1, dimnames = list(rownames(xMN), args$group))
  design<-model.matrix(~0+group)

}else if(!is.null(args$group)){

  errorMessage<-"Group was not found in the column names (first row) of your sample metadata!"
  write(errorMessage,stderr())
  stop(errorMessage,
       call. = FALSE)
}

if ( args$verbose ) { 
  write("Performing the correction ...\n", stdout()) 
}

peakMatrix<-NA
if(!is.null(design))
{

peakMatrix<-limma::removeBatchEffect(t(xMN),batch = batch1,batch2 = batch2,covariates = covariates,design=design)

}else{

peakMatrix<-limma::removeBatchEffect(t(xMN),batch = batch1,batch2 = batch2,covariates = covariates)

}

if ( args$verbose ) { 
  write("Done! writing the results out ...\n", stdout()) 
}
# set formatting and write data out

peakMatrix<-cbind.data.frame(dataMatrix=colnames(xMN),peakMatrix,stringsAsFactors = F)

write.table(x = peakMatrix,file = args$dataMatrix_out,
            row.names = F,quote = F,sep = "\t")

if ( args$verbose ) { 
  write("Program finished!\n", stdout()) 
}
