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

# Prepare chromatogram
chroma <- xcmsRaw(args[[1]])
x <- chroma@scantime
y <- scale(chroma@tic, center=FALSE)
xchrom <- data.frame(x, y)
colnames(xchrom) <- c("rt", "tic")
        
# Write CSV
write.csv(xchrom, file=args[[2]], row.names=FALSE)


