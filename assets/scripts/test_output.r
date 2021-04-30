#!/usr/bin/env Rscript

# Setup R error handling to go to stderr
options(show.error.messages=F, error=function(){cat(geterrmessage(),file=stderr());q("no",1,F)})

# Set proper locale
loc <- Sys.setlocale("LC_MESSAGES", "en_US.UTF-8")

# Import library
#library(getopt)
options(stringAsfactors = FALSE, useFancyQuotes = FALSE)

# Take in trailing command line arguments
args <- commandArgs(trailingOnly = TRUE)



# Load libraries
library(xcms)

# Read raw mzml
chroma <- xcmsRaw(args[[1]])
x1 <- chroma@scantime
y1 <- round(scale(chroma@tic, center=FALSE), digits=2)

# Read chromatogram
xchrom <- read.table(args[[2]], header=TRUE, sep=",", quote="\"", fill=TRUE, dec=".", stringsAsFactors=FALSE)
x2 <- xchrom$rt
y2 <- round(xchrom$tic, digits=2)

# Compare
if (all(y1 %in% y2)) {
	print("mzML and CSV chromatogram are identical.")
} else {
	print("mzML and CSV chromatogram are NOT identical. Test Failed!!!")
	quit(save="no", status=2, runLast=FALSE)
}
