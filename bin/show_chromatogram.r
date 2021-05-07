#!/usr/bin/env Rscript

## Some code taken and adapted from: https://github.com/nturaga/bioc-galaxy-integration/

# Setup R error handling to go to stderr
options(show.error.messages=F, error=function(){cat(geterrmessage(),file=stderr());q("no",1,F)})

# Set proper locale
loc <- Sys.setlocale("LC_MESSAGES", "en_US.UTF-8")

# Import library
#library(getopt)
options(stringAsfactors = FALSE, useFancyQuotes = FALSE)

# Take in trailing command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Process RAW mzML
library(xcms)
xsetraw <- xcmsRaw(args[[1]])

# Save chromatogram as PNG
png(filename=args[[2]])
xchrom <- plotChrom(xsetraw, base=TRUE)
dev.off()
