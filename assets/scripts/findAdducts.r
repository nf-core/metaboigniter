#!/usr/bin/env Rscript
options(stringAsfactors = FALSE, useFancyQuotes = FALSE)

# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No file has been specified! Please select a file for performing findAdducts!\n")
require(xcms)
require(CAMERA)
previousEnv<-NA
output<-NA
output.pdf<-NA
plotpdf<-F
ppm<-10
polarity<-"positive"
rules<-"primary"
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]
  if(argCase=="input")
  {
    previousEnv=as.character(value)
  }
  if(argCase=="ppm")
  {
    ppm=as.numeric(value)
  }
  if(argCase=="polarity")
  {
    polarity=as.character(value)
  }
  if(argCase=="output")
  {
    output=as.character(value)
  }
  if(argCase=="output.pdf")
  {
    output.pdf=as.character(value)
  }
  if(argCase=="plotpdf")
  {
    plotpdf=as.logical(value)
  }
  if(argCase=="rules")
  { 
    rules=as.character(value)
  }
}
if(is.na(previousEnv) | is.na(output)) stop("Both input and output need to be specified!\n")

print.pspectra <- function(file, camera.object) {
	ncols=3
	nrows=ceiling(length(camera.object@pspectra) / ncols)
	pdf(file, width=30, height=(3*nrows))
	par(mfrow=c(nrows, ncols))
	sapply(1:length(camera.object@pspectra), function(x) {
		plotPsSpectrum(camera.object, pspec=x, maxlabel=5)
	})
	dev.off()
}

load(file = previousEnv)

toIsoCharac<-get(varNameForNextStep)

mode <- "pos"
if(polarity == "negative") {mode <- "neg"}
rulefile <- paste("rules/", rules, "_adducts_", mode, ".csv", sep="")
ruleset <- read.csv(system.file(rulefile, package = "CAMERA")) 

xcmsSetAdduCharac<-findAdducts(toIsoCharac,polarity = polarity,ppm = ppm, rules=ruleset)

if(!is.na(output.pdf) & plotpdf==T) {print.pspectra(output.pdf, xcmsSetAdduCharac)}

preprocessingSteps<-c(preprocessingSteps,"findAdducts")

varNameForNextStep<-as.character("xcmsSetAdduCharac")

save(list = c("xcmsSetAdduCharac","preprocessingSteps","varNameForNextStep"),file = output)

