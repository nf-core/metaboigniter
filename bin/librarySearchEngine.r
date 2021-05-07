#!/usr/bin/env Rscript

# This script is used to perform internal library search using various parameters
  write("loading required packages ...\n", stdout())


list.of.packages <- c("argparse","MSnbase","intervals","tools","BiocParallel")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

# load argparse for parsing arguments
suppressWarnings(library("argparse"))
suppressWarnings(library("MSnbase"))
suppressWarnings(library("intervals"))
suppressWarnings(library("tools"))
suppressWarnings(library("BiocParallel"))

# set require arguments
parser <- ArgumentParser()

# set require arguments.

parser$add_argument("-v", "--verbose", action="store_true", default=TRUE,
                    help="Print extra output [default]")

parser$add_argument("-q", "--quietly", action="store_false",
                    dest="verbose", help="Print little output")


parser$add_argument("-i", "--inputMS2",type="character",
                    help="Input MS2 file (metfrag format). This can also be a zip file containing a number of metfrag MS2 file. In the later, a batch version of the script will be run.")

parser$add_argument("-l", "--inputLibrary",type="character",
                    help="Input MS2 library file")


parser$add_argument("-ri", "--readNameOftheMS2", type="character",
                    help="In the calse that inputMS2 is a single metfrag input file, real name of the file should be supplied. This option is for Galaxy that changes the name of the files but still keeps it in the metadata")

parser$add_argument("-out", "--outputCSV", type="character",
                    help="The results the search engine. If inputMS2 is zip, then the output will be concatenated unless option split is set.")

parser$add_argument("-s", "--split", type="logical", default=FALSE,
                    help="Set if you DONT want the output to be concatenated")


parser$add_argument("-mz", "--precursorPPMTol", type="double", default=10.0,
                    help="Precursors mz tolerance in ppm")


parser$add_argument("-mzf", "--fragmentPPMTol", type="double", default=10.0,
                    help="Fragments tolerance in ppm")

parser$add_argument("-mzfa", "--fragmentabsTol", type="double", default=0.07,
                    help="Fragments absolute tolerance")


parser$add_argument("-rt", "--precursorRTTol", type="double", default=0.07,
                    help="Precursors RT tolerance in sec")


parser$add_argument("-sr", "--searchRange", type="logical", default=T,
                    help="search based on feature RT or parent MS2")

parser$add_argument("-pr", "--preprocess", type="logical", default=F,
                    help="preprocess MS2 intensities")

parser$add_argument("-dec", "--outputSemiDecoy", type="logical", default=F,
                    help="estimate e-value for each MS2. This will take a lot of time unless you set low resampling number")


parser$add_argument("-rs", "--resample", type="integer", default=1000,
                    help="How many MS2s used to estimate e-value")


parser$add_argument("-th", "--topHits", type="integer", default=-1,
                    help="How many IDs per MS2 are reported (0 is the top score, -1 is all)")


parser$add_argument("-ts", "--topScore", type="character", default="Scoredotproduct",
                    help="which score to choose for selecting the top ions")


parser$add_argument("-im", "--ionMode", type="character", default="pos",
                    help="set ionization mode pos or neg, is not used now!")


parser$add_argument("-ncore", "--numberOfCores", type="integer", default=1,
                    help="Number of cores")

parser$add_argument("-outT", "--outTable", type="logical", default=T,
                    help="If set, the aggregatated results will be written as table otherwise CSV")


write("loading the main function ...\n", stdout())
main<-function()
{


  ################# the following packages have been adapted from msnbasea and maldiquant
  #################


  numberOfCommonPeaks <- function(x, y, tolerance=25e-6, relative=TRUE) {
    sum(commonPeaks(x, y, tolerance=tolerance, relative=relative))
  }

  commonPeaks <- function(x, y, method=c("highest", "closest"),
                          tolerance=25e-6, relative=TRUE) {
    m <- matchPeaks(x, y, method=match.arg(method), tolerance=tolerance,
                    relative=relative)

    m[which(is.na(m))] <- 0L

    as.logical(m)
  }


  matchPeaks <- function(x, y, method=c("highest", "closest", "all"),
                         tolerance=25e-6, relative=TRUE) {
    method <- match.arg(method)

    y<-y[,"mz"]

    if (nrow(x) == 0 || length(y) == 0) {
      return(integer(peaksCount(x)))
    }

    m <- relaxedMatch((x[,"mz"]), y, nomatch=NA, tolerance=tolerance,
                      relative=relative)

    if (anyDuplicated(m)) {
      o <- order((x[,"intensity"]), decreasing=TRUE)
      sortedMatches <- m[o]
      sortedMatches[which(duplicated(sortedMatches))] <- NA
      m[o] <- sortedMatches
    }

    as.integer(m)
  }


  relaxedMatch <- function(x, table, nomatch=NA_integer_, tolerance=25e-6,
                           relative=TRUE) {

    if (relative) {
      if (tolerance > 1L) {
        stop(sQuote("tolerance"),
             " must be smaller than 1 for relative deviations.")
      }
      tolerance <- table*tolerance
    }

    MALDIquant:::match.closest(x, table, tolerance=tolerance, nomatch=nomatch)
  }

  bin_Spectra <- function(object1, object2, binSize = 1L,
                          breaks = seq(floor(min(c((object1[,"mz"]), (object2[,"mz"])))),
                                       ceiling(max(c((object1[,"mz"]), (object2[,"mz"])))),
                                       by = binSize)) {
    breaks <- .fix_breaks(breaks, range((object1[,"mz"]), (object2[,"mz"])))
    list(bin_Spectrum(object1, breaks = breaks),
         bin_Spectrum(object2, breaks = breaks))
  }

  bin_Spectrum <- function(object, binSize = 1L,
                           breaks = seq(floor(min((object[,"mz"]))),
                                        ceiling(max((object[,"mz"]))),
                                        by = binSize),
                           fun = sum,
                           msLevel.) {
    ## If msLevel. not missing, perform the trimming only if the msLevel
    ## of the spectrum matches (any of) the specified msLevels.
    # print(length(object[,"intensity"]))
    # print(length(object[,"mz"]))
    bins <- .bin_values(object[,"intensity"], object[,"mz"], binSize = binSize,
                        breaks = breaks, fun = fun)


    #data.frame(bins$mids,bins$x)
    object<-matrix(c(bins$mids,bins$x), nrow = length(bins$x), dimnames = list(1:length(bins$x), c("mz","intensity")))
    # object<-data.frame("mz" = bins$mids,"intensity" = bins$x)
    return(object)
  }

  dotproduct<-function (x, y)
  {
    as.vector(x %*% y)/(sqrt(sum(x * x)) * sqrt(sum(y * y)))
  }
  compare_Spectra2 <- function(x, y,
                               fun=c("common", "cor", "dotproduct"),binSize=0,tolerance =0,relative = F) {
    {

      if (fun == "cor" || fun == "dotproduct") {
        #binnedSpectra <- bin_Spectra(x, y, ...)

        binSize<-binSize

        breaks = seq(floor(min(c((x[,"mz"]), (y[,"mz"])))),
                     ceiling(max(c((x[,"mz"]), (y[,"mz"])))),
                     by = binSize)

        # breaks <- .fix_breaks(brks = breaks, rng = range((x[,"mz"]), (y[,"mz"]))) # fix!

        brks = breaks
        rng = range((x[,"mz"]), (y[,"mz"]))
        if (brks[length(brks)] <= rng[2])
          breaks <- c(brks, max((rng[2] + 1e-6),
                                brks[length(brks)] + mean(diff(brks))))


        breaks1 = breaks
        rng = range(x[,"mz"])
        if (brks[length(brks)] <= rng[2])
          breaks1 <- c(brks, max((rng[2] + 1e-6),
                                 brks[length(brks)] + mean(diff(brks))))

        nbrks <- length(breaks1)
        idx <- findInterval(x[,"mz"], breaks1)
        ## Ensure that indices are within breaks.
        idx[which(idx < 1L)] <- 1L
        idx[which(idx >= nbrks)] <- nbrks - 1L

        ints <- double(nbrks - 1L)
        ints[unique(idx)] <- unlist(lapply(base::split(x[,"intensity"], idx), sum),
                                    use.names = FALSE)
        binsx=ints
        binsmids = (breaks1[-nbrks] + breaks1[-1L]) / 2L

        list1<-binsx#matrix(c(binsmids,binsx), nrow = length(binsx), dimnames = list(1:length(binsx), c("mz","intensity")))


        # breaks2 <- .fix_breaks(breaks, range(y[,"mz"]))
        breaks2 = breaks
        brks = breaks
        rng = range(y[,"mz"])
        if (brks[length(brks)] <= rng[2])
          breaks2 <- c(brks, max((rng[2] + 1e-6),
                                 brks[length(brks)] + mean(diff(brks))))
        nbrks <- length(breaks2)
        idx <- findInterval(y[,"mz"], breaks2)
        ## Ensure that indices are within breaks.
        idx[which(idx < 1L)] <- 1L
        idx[which(idx >= nbrks)] <- nbrks - 1L

        ints <- double(nbrks - 1L)
        ints[unique(idx)] <- unlist(lapply(base::split(y[,"intensity"], idx), sum),
                                    use.names = FALSE)
        bins<-list(x = ints, mids = (breaks2[-nbrks] + breaks[-1L]) / 2L)
        binsmids = (breaks2[-nbrks] + breaks2[-1L]) / 2L
        binsx=ints

        list2<-binsx#matrix(c(binsmids,binsx), nrow = length(binsx), dimnames = list(1:length(binsx), c("mz","intensity")))


        #inten <- lapply(list(list1,list2), function(x){x[,"intensity"]})
        # ifelse(fun == "dotproduct",dotproduct(list1,list2),cor(list1,list2)
        return(c(dotproduct(list1,list2),cor(list1,list2)))
      } else if (fun == "common") {
        return(numberOfCommonPeaks(x, y, tolerance =tolerance,relative = relative))
      }
    }
  }

  .fix_breaks <- function(brks, rng) {
    ## Assuming breaks being sorted.
    if (brks[length(brks)] <= rng[2])
      brks <- c(brks, max((rng[2] + 1e-6),
                          brks[length(brks)] + mean(diff(brks))))
    brks
  }
  .bin_values <- function(x, toBin, binSize = 1, breaks = seq(floor(min(toBin)),
                                                              ceiling(max(toBin)),
                                                              by = binSize),
                          fun = max) {
    if (length(x) != length(toBin))
      stop("lengths of 'x' and 'toBin' have to match.")
    fun <- match.fun(fun)
    breaks <- .fix_breaks(breaks, range(toBin))
    nbrks <- length(breaks)
    idx <- findInterval(toBin, breaks)
    ## Ensure that indices are within breaks.
    idx[which(idx < 1L)] <- 1L
    idx[which(idx >= nbrks)] <- nbrks - 1L

    ints <- double(nbrks - 1L)
    ints[unique(idx)] <- unlist(lapply(base::split(x, idx), fun),
                                use.names = FALSE)
    list(x = ints, mids = (breaks[-nbrks] + breaks[-1L]) / 2L)

  }



  #################
  #################
  #################



  doSearch<-function(args)
  {


    inputLibrary<-NULL
    inputMS2<-NULL
    outputCSV<-NULL
    readNameOftheMS2<-NULL
    # MS1 PPM tol
    precursorPPMTol<-10

    # MS2 abs tol
    fragmentabsTol<-0.07

    # MS2 ppm tol
    fragmentPPMTol<-10

    # MS1 RT tol
    precursorRTTol<-20

    # search based on feature RT or parent MS2
    searchRange<-T

    # preprocess MS2 ?
    preprocess<-F

    # estimate decoy ?
    outputSemiDecoy<-T

    # how many we should peak 0 is top -1 is all
    topHits<--1

    # set ionization mode pos or neg
    ionMode<-"pos"
    # which score to choose
    topScore<-"Scoredotproduct"

    # resample
    resample=1000

    # libdata for parallel package
    libdata<-NULL
    # read the parameters
    for(arg in names(args))
    {
      argCase<-arg
      value<-args[[argCase]]

      if(argCase=="inputMS2" & !is.null(value))
      {
        inputMS2=as.character(value)
      }
      if(argCase=="inputLibrary" & !is.null(value))
      {
        inputLibrary=as.character(value)
      }
      if(argCase=="readNameOftheMS2" & !is.null(value))
      {
        readNameOftheMS2=as.character(value)
      }
      if(argCase=="outputCSV" & !is.null(value))
      {
        outputCSV=as.character(value)
      }
      if(argCase=="precursorPPMTol" & !is.null(value))
      {
        precursorPPMTol=as.numeric(value)
      }
      if(argCase=="fragmentabsTol" & !is.null(value))
      {
        fragmentabsTol=as.numeric(value)
      }
      if(argCase=="fragmentPPMTol" & !is.null(value))
      {
        fragmentPPMTol=as.numeric(value)
      }
      if(argCase=="precursorRTTol" & !is.null(value))
      {
        precursorRTTol=as.numeric(value)
      }
      if(argCase=="searchRange" & !is.null(value))
      {
        searchRange=as.logical(value)
      }

      if(argCase=="outputSemiDecoy" & !is.null(value))
      {
        outputSemiDecoy=as.logical(value)
      }


      if(argCase=="topHits" & !is.null(value))
      {
        topHits=as.numeric(value)
      }
      if(argCase=="ionMode" & !is.null(value))
      {
        ionMode=as.character(value)
      }

      if(argCase=="topScore" & !is.null(value))
      {
        topScore=as.character(value)
      }

      if(argCase=="resample" & !is.null(value))
      {
        resample=as.numeric(value)
      }
      if(argCase=="libdata" & !is.null(value))
      {
        libdata=value
      }


    }
    # load MSnbase package for comparing spectra





    if((is.null(inputLibrary) & is.null(libdata))| is.null(inputMS2)) stop("Both inputs (library & MS2) are required")
    # read library file
    ######################### UNCOMMENT #############################
    MSlibrary<-NA

    if(is.null(libdata))
    {
      MSlibrary<-read.csv(inputLibrary,stringsAsFactors = F)
    }else{
      MSlibrary<-libdata
    }

    if(nrow(MSlibrary)<1) stop("Library is empty!")


    checkAllCol<-all(sapply(c("startRT","endRT","startMZ","endMZ","centermz","centerrt","intensity","MS2fileName" ,"ID","Name", "nmass","MS2mz","MS2rt","MS2intensity","MS2mzs","MS2intensities","featureGroup" ),
                            function(x){x%in%colnames(MSlibrary)}))

    if(!checkAllCol)stop("Check the library file! it has to include the following columns:
                         startRT,endRT,startMZ,endMZ,centermz,centerrt, intensity,fileName ,ID,Name, nmass,MS2mz,MS2rt,MS2intensity,MS2mzs,featureGroup and MS2intensities" )

    # limit the library to those with MS2
    MSlibrary<-MSlibrary[MSlibrary[,"MS2mzs"]!="",]
    # extract name of the file
    MS2NameFileName<-readNameOftheMS2
    if(is.null(MS2NameFileName))MS2NameFileName<-basename(inputMS2)

    # extract precursor RT and mz from name of the file
    precursorRT<-as.numeric(strsplit(x = MS2NameFileName,split = "_",fixed = T)[[1]][2])
    precursorMZ<-as.numeric(strsplit(x = MS2NameFileName,split = "_",fixed = T)[[1]][3])
    if(is.na(precursorRT) | is.na(precursorMZ)) stop("File name does not contain RT or mz. Check the file name!")

    # extract MS2 information from MS2 file
    MS2Information<-readLines(inputMS2)

    # split the data into a dataframe for easy access
    MS2DataFrame<-sapply(X = strsplit(x = MS2Information,split = " ",fixed = T)[[1]],FUN = function(x){strsplit(x = x,split = "=",fixed = T)[[1]]})
    colnames(MS2DataFrame)<-MS2DataFrame[1,]

    # set parameters from input file
    # mz ppm
    if(!"DatabaseSearchRelativeMassDeviation"%in%colnames(MS2DataFrame))stop("DatabaseSearchRelativeMassDeviation is not in the parameter file!")
    if(is.null(precursorPPMTol))precursorPPMTol<-as.numeric(MS2DataFrame[2,"DatabaseSearchRelativeMassDeviation"])
    if(is.na(precursorPPMTol)) stop("precursorPPMTol has not been provided and is not in the parameter file!")

    # fragment absolute deviation
    if(!"FragmentPeakMatchAbsoluteMassDeviation"%in%colnames(MS2DataFrame))stop("FragmentPeakMatchAbsoluteMassDeviation is not in the parameter file!")
    if(is.null(fragmentabsTol))fragmentabsTol<-as.numeric(MS2DataFrame[2,"FragmentPeakMatchAbsoluteMassDeviation"])
    if(is.na(fragmentabsTol)) stop("fragmentabsTol has not been provided and is not in the parameter file!")

    # fragment PPM deviation

    if(is.null(fragmentPPMTol))fragmentPPMTol<-as.numeric(MS2DataFrame[2,"FragmentPeakMatchRelativeMassDeviation"])
    if(is.na(fragmentPPMTol)) stop("fragmentPPMTol has not been provided and is not in the parameter file!")
    # fix if RT tol is missing!
    if(is.na(precursorRTTol)) {cat("WARNNING: precursorRTTol has not been provided using largest RT region:",.Machine$double.xmax);precursorRTTol<-.Machine$double.xmax}

    parentFile<-"NotFound"
    if(!"SampleName"%in%colnames(MS2DataFrame))stop("SampleName is not in the parameter file!")
    parentFile<-basename(MS2DataFrame[2,"SampleName"])
    if(parentFile=="NotFound") {warning("SampleName was not found in the parameter file setting to NotFound")}

    # extract MS2 peaks
    if(!"PeakListString"%in%colnames(MS2DataFrame))stop("PeakListString is not in the parameter file!")
    MS2TMP<-MS2DataFrame[2,"PeakListString"]
    # if spectrum is empty do not continue
    isMS2Emtpy<-MS2TMP==""

    # define a function for calculating ppm!

    ppmCal<-function(run,ppm)
    {
      return((run*ppm)/1000000)
    }
    temp<-NA
    if(!isMS2Emtpy)
    {

      temp<-t(sapply(X=(strsplit(x = strsplit(x = MS2TMP,split = ";",fixed = T)[[1]],split = "_",fixed = T)),FUN = function(x){c(mz=as.numeric(x[1]),
                                                                                                                                 int=as.numeric(x[2]))}))
      temp<-temp[temp[,1]!=0,]
      if(nrow(temp)<1)isMS2Emtpy<-F
    }

    if(!isMS2Emtpy){
      # read MS2 and convert to dataframe

      # create a msnbase file!
      targetMS2<-new("Spectrum2", mz=temp[,1], intensity=temp[,2])
      targetMS2DataFrame<-data.frame(mz=temp[,1],intensity=temp[,2])
      targetMS2DataFrame<- matrix(c(temp[,1],temp[,2]), nrow = length(temp[,2]), dimnames = list(1:length(temp[,2]), c("mz","intensity")))
      #names(targetMS2DataFrame)<-c("mz","intensity")
      # set search interval for MS2
      mzTarget<-Intervals_full(cbind(precursorMZ,precursorMZ))
      rtTarget<-Intervals_full(cbind(precursorRT,precursorRT))

      # set search interval for library that is either as range or centroid
      mzLib<-NA
      rtLib<-NA
      if(searchRange)
      {
        if(!"startMZ"%in%colnames(MSlibrary))stop("startMZ is not in library file!")
        if(!"endMZ"%in%colnames(MSlibrary))stop("endMZ is not in library file!")
        mzLib<-Intervals_full(cbind(MSlibrary$startMZ-
                                      ppmCal(MSlibrary$startMZ,precursorPPMTol),
                                    MSlibrary$endMZ+
                                      ppmCal(MSlibrary$endMZ,precursorPPMTol)))

        if(!"startRT"%in%colnames(MSlibrary))stop("startRT is not in library file!")
        if(!"endRT"%in%colnames(MSlibrary))stop("endRT is not in library file!")
        rtLib<-Intervals_full(cbind(MSlibrary$startRT-
                                      precursorRTTol,
                                    MSlibrary$endRT+
                                      precursorRTTol))
      }else{

        if(!"centermz"%in%colnames(MSlibrary))stop("centermz is not in library file!")
        mzLib<-Intervals_full(cbind(MSlibrary$centermz-
                                      ppmCal(MSlibrary$centermz,precursorPPMTol),
                                    MSlibrary$centermz+
                                      ppmCal(MSlibrary$centermz,precursorPPMTol)))
        if(!"centerrt"%in%colnames(MSlibrary))stop("centerrt is not in library file!")
        rtLib<-Intervals_full(cbind(MSlibrary$centerrt-
                                      precursorRTTol,
                                    MSlibrary$centerrt+
                                      precursorRTTol))
      }

      # do precursor mass search
      Mass_iii <- interval_overlap(mzTarget,mzLib)

      # do precursor mass search
      Time_ii <- interval_overlap(rtTarget,rtLib)

      # check if there is any hit ?!
      imatch = mapply(intersect,Time_ii,Mass_iii)
      foundHit<-length(imatch[[1]])>0

      # create an empty array for the results
      results<-c()

      # compareSpectra needs relative deviation in fractions
      fragmentPPMTol<-fragmentPPMTol/1000000

      if(foundHit)
      {
        cat("Number of hits: ",length(imatch),"\n")
        for(i in imatch)
        {
          hitTMP<-MSlibrary[i,]

          if(hitTMP[,"MS2mzs"]!="")
          {


            # tmpResults<-c()
            # for(j in 1:length(parentmzs))
            {
              #MS2sTMPLib<-parentMS2s[[j]]
              tempmz<-as.numeric(strsplit(hitTMP[,"MS2mzs"],split = ";",fixed = T)[[1]])
              tempint<-as.numeric(strsplit(hitTMP[,"MS2intensities"],split = ";",fixed = T)[[1]])

              tempmz<-tempmz[tempint!=0]
              tempint<-tempint[tempint!=0]


              # if all the peaks were zero, skip rest of the loop!
              if(length(tempint)<1)next

              # extract name of the metabolite

              hitName<-hitTMP[,"Name"]
              hitChI<-NA
              Identifier<-ifelse(test = is.null(results),yes = 1,no = (nrow(results)+1))
              fileName<-parentFile
              parentMZ<-precursorMZ
              parentRT<-precursorRT

              restOfLibInformation<-hitTMP[,c("startRT","endRT","startMZ","endMZ","centermz","centerrt","intensity","MS2fileName" ,"ID","Name", "nmass","MS2mz","MS2rt","MS2intensity","featureGroup" )]
              featureGroup<-hitTMP[,"featureGroup"]
              nmass<-as.numeric(hitTMP[,"nmass"])
              MS1mzTolTh<-NA

              MS1mzTolTh<-((parentMZ-(nmass))/(nmass))*1000000


              MS1RTTol<-NA
              centerRT<-as.numeric(hitTMP[,"centerrt"])
              MS1RTTol<-parentRT-centerRT
              # create MS2 object
              libMS2Obj<-new("Spectrum2", mz=tempmz, intensity=tempint)



              ## output three types of scores: dotproduct, common peaks and correlation (dotproduct will be our main score)
              dotPeaks<-NA
              tryCatch({
                dotPeaks<-compareSpectra(targetMS2, libMS2Obj, fun="dotproduct",binSize =fragmentabsTol)
              }, warning = function(w) {
              }, error = function(e) {

              }, finally = {

              })

              nPeakCommon<-NA
              tryCatch({
                nPeakCommon<-compareSpectra(targetMS2, libMS2Obj, fun="common",tolerance =fragmentPPMTol,relative = TRUE)
              }, warning = function(w) {
              }, error = function(e) {

              }, finally = {

              })

              corPeaks<-NA
              tryCatch({
                corPeaks<-compareSpectra(targetMS2, libMS2Obj, fun="cor",binSize =fragmentabsTol)
              }, warning = function(w) {
              }, error = function(e) {

              }, finally = {

              })
              ##
              # if requrested create a decoyDatabase for this specific MS2 and estimate "e-value"
              # this will repeat the whole process but for rest of the peaks
              # it will take LONG time!
              decoyScore<-list()
              decoyScore[["dotproduct"]]<-c()
              decoyScore[["common"]]<-c()
              decoyScore[["cor"]]<-c()
	      dotPeaksDecoy<-NA
              nPeakCommonDecoy<-NA
              corPeaksDecoy<-NA


              if(outputSemiDecoy)
              {
                decoyLib<-MSlibrary[-as.vector(imatch),]
                decoyScoresTMP<-c()

                start_time <- Sys.time()
                allMzs<-as.character(decoyLib[,"MS2mzs"])
                allInts<-as.character(decoyLib[,"MS2intensities"])

                rowNumbersDecoy<-1:nrow(decoyLib)
                if(resample>0)
                {
                  set.seed(resample)
                  rowNumbersDecoy<-sample(x = rowNumbersDecoy,size = resample,replace = F)
                }
                for(k in rowNumbersDecoy)
                {
                  tempmzDecoy<-as.numeric(strsplit(allMzs[k],split = ";",fixed = T)[[1]])
                  tempintDecoy<-as.numeric(strsplit(allInts[k],split = ";",fixed = T)[[1]])
                  tempmzDecoy<-tempmzDecoy[tempintDecoy!=0]
                  tempintDecoy<-tempintDecoy[tempintDecoy!=0]


                  tempDecoy<- matrix(c(tempmzDecoy,tempintDecoy), nrow = length(tempintDecoy), dimnames = list(1:length(tempintDecoy), c("mz","intensity")))

                  dotPeaksDecoy<-NA
                  nPeakCommonDecoy<-NA
                  tryCatch({
                    tmp<-c(NA,NA)
                    tmp<-compare_Spectra2(targetMS2DataFrame, tempDecoy, fun="dotproduct",binSize =fragmentabsTol)
                    dotPeaksDecoy<-tmp[1]
                    corPeaksDecoy<-tmp[2]
                  }, warning = function(w) {
                  }, error = function(e) {

                  }, finally = {

                  })

                  nPeakCommonDecoy<-NA
                  tryCatch({
                    nPeakCommonDecoy<-compare_Spectra2(targetMS2DataFrame, tempDecoy, fun="common",tolerance =fragmentPPMTol,relative = TRUE)
                  }, warning = function(w) {
                  }, error = function(e) {

                  }, finally = {
                  })


                  decoyScore[["dotproduct"]]<-c(decoyScore[["dotproduct"]],dotPeaksDecoy)
                  decoyScore[["common"]]<-c(decoyScore[["common"]],nPeakCommonDecoy)
                  decoyScore[["cor"]]<-c(decoyScore[["cor"]],corPeaksDecoy)

                }


                decoyScore[["dotproduct"]]<-na.omit(decoyScore[["dotproduct"]])
                decoyScore[["common"]]<-na.omit(decoyScore[["common"]])
                decoyScore[["cor"]]<-na.omit(decoyScore[["cor"]])
                dotPeaksDecoy<-NA
                nPeakCommonDecoy<-NA
                corPeaksDecoy<-NA
                if(!is.na(dotPeaks))
                  dotPeaksDecoy<-sum(decoyScore[["dotproduct"]]>dotPeaks)/length(decoyScore[["dotproduct"]]   )
                if(!is.na(nPeakCommon))
                  nPeakCommonDecoy<-sum(decoyScore[["common"]]>nPeakCommon)/length(decoyScore[["common"]])
                if(!is.na(corPeaks))
                  corPeaksDecoy<-sum(decoyScore[["cor"]]>corPeaks)/length(decoyScore[["cor"]])

              }
              results<-rbind(results,  data.frame(fileName=parentFile,parentMZ=parentMZ,parentRT=parentRT,Name=fileName,Identifier=Identifier,InChI=NA,
                                                  MS1mzTolTh,MS1RTTol,
                                                  Scoredotproduct=dotPeaks,Scorecommon=nPeakCommon,ScoreCorrelation=corPeaks,
                                                  ScoredotproductEValue=dotPeaksDecoy,ScorecommonEValue=nPeakCommonDecoy,ScoreCorrelationEValue=corPeaksDecoy,
                                                  score=dotPeaks,scoreEValue=dotPeaksDecoy,restOfLibInformation,MS1RTTol=MS1RTTol,featureGroup=featureGroup))


            }


          }
        }
        # limit the results as requrested by user: tophit:-1 = all, tophit:0 = top, tophit:>0 = top tophits score higher the better (for now)
        resTMP<-c()
        if(topHits!=-1 & nrow(results)>1)
        {
          if(topHits==0)
          {
            for(groupNumber in unique(results[,"featureGroup"]))
            {
              tmpResults<-data.frame(results[results[,"featureGroup"]==groupNumber,])
              resTMP<-rbind(resTMP,tmpResults[which.max(tmpResults[,topScore]),])
            }

          }else{
            for(groupNumber in unique(results[,"featureGroup"]))
            {
              tmpResults<-data.frame(results[results[,"featureGroup"]==groupNumber,])
              resTMP<-rbind(resTMP,tmpResults[order(tmpResults[,topScore],decreasing = T,na.last = T),][seq(1,topHits),])
            }

          }
          results<-resTMP
        }

        write.csv(x =results, outputCSV)
      }else{file.create(outputCSV)}
    }else{
      file.create(outputCSV)
    }
  }



  # parsing the arguments
 args <- parser$parse_args()
  # args<-list()
 #  args$inputMS2<-"res.zip"
 # args$inputLibrary<-"library.csv"
 # args$outputCSV<-"ot.csv"
  # args$verbose<-T
 #  args$numberOfCores<-5
  if ( args$verbose ) {
    write("Checking if the inputs and outputs have been given ...\n", stdout())
  }

  # check if the input MS2 has been given
  if(is.null(args$inputMS2))
  {
    errorMessage<-"No inputMS2 file has been specified. You MUST specify the input file see the help (-h)!"
    write(errorMessage,stderr())
    stop(errorMessage,
         call. = FALSE)
  }
  # check if the input inputLibrary has been given
  if(is.null(args$inputLibrary))
  {
    errorMessage<-"No library file has been specified. You MUST specify the library file see the help (-h)!"
    write(errorMessage,stderr())
    stop(errorMessage,
         call. = FALSE)
  }

  # check if the input outputCSV has been given
  if(is.null(args$outputCSV))
  {
    errorMessage<-"No output file has been specified. You MUST specify the output file see the help (-h)!"
    write(errorMessage,stderr())
    stop(errorMessage,
         call. = FALSE)
  }



  # this is a helper function to fix the input names and output names
  # This is only used in parallel model and when TMP dir has been specified.
  prepareOut<-function(argsIn,input,outputDIR)
  {
    suppressWarnings(library("argparse"))
    suppressWarnings(library("MSnbase"))
    suppressWarnings(library("intervals"))
    suppressWarnings(library("tools"))
    suppressWarnings(library("BiocParallel"))
    argsIn$inputMS2<-input
  #  print(input)
    argsIn$outputCSV<-paste(outputDIR,"/",file_path_sans_ext(basename(input)),".csv",sep="")
    argsIn$readNameOftheMS2<-basename(input)
 #print(argsIn)
    doSearch(argsIn)
  }

  # now if the file extension is zip we assume it has a number of MS2 files in it.
  # we unzip to a temp folder and go forward with rest of the pipeline

  if(file_ext(args$inputMS2)=="zip" | sum(file_ext(args$readNameOftheMS2)=="zip")==1){


    if ( args$verbose ) {
      write("Seems like zip file have been provided, unzipping ...\n", stdout())
    }

    if ( args$verbose ) {
      write("creating temp folder ...\n", stdout())
    }


    baseTMP<-"tmp"
    dir.create(baseTMP)
    tmpDIR<-paste(baseTMP,"/","inputs",sep = "")
   dir.create(tmpDIR)
  # file.copy(list.files("wetransfer-a2e025/res/out/")[4000:5000],tmpDIR)
    #tmpDIR<-"wetransfer-a2e025/res/out/"
    if ( args$verbose ) {
      write("Unzipping the file ...\n", stdout())
    }

   unzip(args$inputMS2, overwrite = TRUE,
           junkpaths = TRUE, exdir = tmpDIR, unzip = "internal",
           setTimes = FALSE)

    if ( args$verbose ) {
      write("The data has been unzipped, reading list of the MS2 files ...\n", stdout())
    }

    # Get a the list of uinzip files
    AllMS2Files<-list.files(tmpDIR,full.names = T)

    if ( args$verbose ) {
      write("Done!\n", stdout())
    }
    if ( args$verbose ) {
      write("Reading the library file ...\n", stdout())
    }

    # We load the whole database in the memory instead of reading it for every single MS2.
    args$libdata<-read.csv(args$inputLibrary,stringsAsFactors = F)
    print(dim(args$libdata))
    if ( args$verbose ) {
      write("Done!\n", stdout())
    }


    if ( args$verbose ) {
      write("Setting Snow parameters ...\n", stdout())
    }

    # we set thge Snow parameters
    snow<-SnowParam(workers = 1, type = "SOCK")

    # More than 1 core is requested, we try to set it.
    if(args$numberOfCores>1)
    {
      snow <- SnowParam(workers = args$numberOfCores, type = "SOCK")
    }

    if ( args$verbose ) {
      write("Done!\n", stdout())
    }

    if ( args$verbose ) {
      write("Creating a temp folder for the results ...\n", stdout())
    }
   tmpDIROut<-paste(baseTMP,"/","outputs",sep = "")
    #tmpDIROut<-"test"
   dir.create(tmpDIROut)
    print(tmpDIROut)
   # tmpDIR
    if ( args$verbose ) {
      write("Done!\n", stdout())
    }

    if ( args$verbose ) {
      write("Running the database search ...\n", stdout())
    }

    # this will iterate through the MS2 files and run them.
    bplapply(AllMS2Files, FUN = function(x){prepareOut(args,input = x,outputDIR = tmpDIROut)},BPPARAM = snow)

    if ( args$verbose ) {
      write("Done!\n", stdout())
    }

# if the user wants to aggregate the results right here
    if(!args$split)
    {
      if ( args$verbose ) {
        write("Combining the results of the MS2s ...\n", stdout())
      }
      inputs<-list.files(tmpDIROut,full.names = T)
      realNamesTMP<-inputs
      allMS2IDs<-c()
      for(i in 1:length(inputs))
      {
        # check if the file is empty
        info = file.info(inputs[i])
        if(info$size!=0 & !is.na(info$size))
        {
          tmpFile<-read.csv(inputs[i])
          # check if the file has any IDs
          if(nrow(tmpFile)>0)
          {
            # Extract mz and rt from the real file names
            rt<-as.numeric(strsplit(x = realNamesTMP[i],split = "_",fixed = T)[[1]][2])
            mz<-as.numeric(strsplit(x = realNamesTMP[i],split = "_",fixed = T)[[1]][3])

            allMS2IDs<-rbind(allMS2IDs,data.frame(parentMZ=mz,parentRT=rt,tmpFile))
          }
        }

      }
      if ( args$verbose ) {
        write("Done!\n", stdout())
      }
      if ( args$verbose ) {
        write("Writing the results ...\n", stdout())
      }
      if(args$outTable)
      {

      if(is.null(allMS2IDs) || nrow(allMS2IDs)<1)
      {
file.create(args$outputCSV)
      }else{
        write.table(x=allMS2IDs,file=args$outputCSV,quote=F,sep="\t")
      }
      }else{
      if(is.null(allMS2IDs) || nrow(allMS2IDs)<1)
      {
file.create(args$outputCSV)
      }else{
        write.csv(x = allMS2IDs,file = args$outputCSV)
      }

      }




    }else{
      if ( args$verbose ) {
        write("Writing the results ...\n", stdout())
      }
      file.copy(list.files(tmpDIROut,full.names = T),getwd())
    }

  }else{

    doSearch(args)
  }

}



# running the main function. This is to make parallel stuff easier. Otherwise, not other value :)
main()
