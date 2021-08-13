# A set of functions for preprocessing of MS2s
library(intervals)
library(CAMERA)
library(MSnbase)
library(xcms)
library(plyr)

ppmCal<-function(run,ppm)
{
  return((run*ppm)/1000000)
}

merge.spectra.group <- function(spectra, eppm, eabs, int.threshold) {
  if(is.na(spectra) || length(spectra) == 0) return(NULL)
  max.precursor.int <- -1
  rt.at.max.int <- NA
  start.rt <- attributes(spectra[[1]])$rt
  end.rt <- attributes(spectra[[1]])$rt
  all_unique_files<-paste(sapply(spectra,function(x){attributes(x)$fileName}),collapse = ";")
  mean.precursor.mz <- 0
  max.tic <- -1
  tandemms <- lapply(1:length(spectra), function(index) {
    # print(index)
    x<-spectra[[index]]
    # assign local variables
    cur.rt <- attributes(x)$rt
    cur.precursor.int <- attributes(x)$precursorIntensity
    cur.tic <- attributes(x)$tic
    cur.precursor.mz <- attributes(x)$precursorMz
    # assign global variables
    mean.precursor.mz <<- mean.precursor.mz + cur.precursor.mz
    max.tic <<- if(max.tic < cur.tic) cur.tic else max.tic
    if(max.precursor.int < cur.precursor.int) {
      max.precursor.int <<- cur.precursor.int
      rt.at.max.int <<- cur.rt
    }
    start.rt <<- if(start.rt > cur.rt) cur.rt else start.rt
    end.rt <<- if(end.rt < cur.rt) cur.rt else end.rt
    # start merging ms2 data
    a <- cbind(attributes(x)$mz, attributes(x)$intensity)
    colnames(a) <- c("mz", "intensity")
    return(a)
  })
  mean.precursor.mz <- mean.precursor.mz / length(spectra)

  # Filter intensity
  tandemms <- lapply(tandemms, function(spec) spec[spec[,"intensity"]>=int.threshold,])
  tandemrm <- sapply(1:length(tandemms), function(x) { if ( (dim(tandemms[[x]])[1] == 0) || is.null(dim(tandemms[[x]])[1]) ) x <- TRUE else x <- FALSE } )

  if ( (all(as.logical(tandemrm)) == TRUE) | (is.na(all(as.logical(tandemrm)))) )
    return(NULL)
  else
    tandemms <- tandemms[!tandemrm]

  # Process spectra
  peaks <- do.call(rbind, tandemms)
  g <- xcms:::mzClust_hclust(peaks[,"mz"], eppm=eppm, eabs=eabs)

  mz <- tapply (peaks[,"mz"], as.factor(g), mean)
  intensity <- tapply (peaks[,"intensity"], as.factor(g), max)

  if(length(mz) == 0)return(NULL);

  intensity <- intensity[order(mz)]
  mz <- mz[order(mz)]

  res <- .Call("Spectrum2_constructor_mz_sorted",
               attributes(spectra[[1]])$msLevel, length(mz), rt.at.max.int,
               attributes(spectra[[1]])$acquisitionNum,
               attributes(spectra[[1]])$scanIndex, max.tic, mz,
               intensity, attributes(spectra[[1]])$fromFile, attributes(spectra[[1]])$centroided,
               attributes(spectra[[1]])$smoothed, attributes(spectra[[1]])$polarity,
               attributes(spectra[[1]])$merged, attributes(spectra[[1]])$precScanNum,
               mean.precursor.mz, max.precursor.int, attributes(spectra[[1]])$precursorCharge, attributes(spectra[[1]])$collisionEnergy,
               TRUE, attributes(spectra[[1]])$.__classVersion__,
               PACKAGE = "MSnbase")
  attributes(res)$start.rt <- start.rt
  attributes(res)$end.rt <- end.rt
  attributes(res)$fileName <- all_unique_files

  return(res)
}

get.ppm.from.abs <- function(peak, ppm) {
  return ((peak / 1000000.0) * ppm)
}

collect.spectra.lists <- function(spectra, mzabs, mzppm, rtabs) {
  a<-t(sapply(1:length(spectra), function(spectrum.id) {
    return(c(attributes(spectra[[spectrum.id]])$rt, attributes(spectra[[spectrum.id]])$precursorMz, spectrum.id))
  }))
  a <- a[order(a[,2], a[,1]),]
  index <- 1
  grouped.spectra.tmp <- list()
  while(index <= dim(a)[1]) {
    spectra.list <- list()
    spectra.list[[1]] <- spectra[[a[index,3]]]
    cur.abs <- get.ppm.from.abs(a[index, 2], mzppm * 0.5) + mzabs
    index <- index + 1
    while(index <= dim(a)[1]) {
      diff.mz <- abs(a[index - 1, 2] - a[index, 2])
      if(diff.mz <= cur.abs) {
        spectra.list[[length(spectra.list) + 1]] <- spectra[[a[index,3]]]
        index <- index + 1
      } else break
    }
    grouped.spectra.tmp[[length(grouped.spectra.tmp) + 1]] <- spectra.list
  }
  grouped.spectra <- list()
  for(spectrum.group.index in 1:length(grouped.spectra.tmp)) {
    spectrum.group <- grouped.spectra.tmp[[spectrum.group.index]]
    a<-t(sapply(1:length(spectrum.group), function(spectrum.index) {
      c(attributes(spectrum.group[[spectrum.index]])$rt, attributes(spectrum.group[[spectrum.index]])$precursorMz, spectrum.index)
    }))
    a <- matrix(a[order(a[,1], a[,2]),], ncol=3)
    index <- 1
    while(index <= dim(a)[1]) {
      spectra.list <- list()
      spectra.list[[1]] <- spectrum.group[[a[index,3]]]
      index <- index + 1
      while(index <= dim(a)[1]) {
        diff.rt <- abs(a[index - 1, 1] - a[index, 1])
        if(diff.rt <= rtabs) {
          spectra.list[[length(spectra.list) + 1]] <- spectrum.group[[a[index,3]]]
          index <- index + 1
        } else break
      }
      grouped.spectra[[length(grouped.spectra) + 1]] <- spectra.list
    }
  }
  return(grouped.spectra)
}


preprocess_msms<-function(mapped_msms=NA,centroid=F,merge=TRUE,centroid_after_merge=F,ppm=10,ppm_precursor=10,abs_mz=0.01,abs_mz_precursor=0.01,rt=10,centroid_onlymapped=FALSE,merge_onlymapped=FALSE,int_threshold=0,verbose=FALSE)
{
  if(!is.logical(verbose)){
    stop("verbose must be TRUE or FALSE!")
  }

  if(verbose)cat("Checking inputs ...","\n")
  if(!is.list(mapped_msms))
  {
    stop("mapped_msms has to be a list from map_features")
  }else{
    if(!all(names(mapped_msms)==c("mapped","unmapped"))){
      stop("mapped_msms does not appear to be map_features! mapped_msms has to be a list from map_features!")
    }
    if(all(sapply(mapped_msms, length)<1)){
      stop("No MS2s were found in mapped_msms")
    }
  }

  if(!is.logical(centroid)){
    stop("centroid must be TRUE or FALSE!")
  }

  if(!is.logical(merge)){
    stop("merge must be TRUE or FALSE!")
  }

  if(!is.logical(centroid_after_merge)){
    stop("centroid_after_merge must be TRUE or FALSE!")
  }

  if(!is.logical(merge_onlymapped)){
    stop("merge_onlymapped must be TRUE or FALSE!")
  }

  if(!is.logical(centroid_onlymapped)){
    stop("centroid_onlymapped must be TRUE or FALSE!")
  }



  if(any(is.na(ppm)) | any(is.null(ppm)))
  {
    stop("No ppm input have been provided!")
  }

  if(!is.numeric(rt))
  {
    stop("rt must be numberic")
  }

  if(!is.numeric(int_threshold))
  {
    stop("int_threshold must be numberic")
  }


  if(!is.numeric(ppm_precursor))
  {
    stop("ppm_precursor must be numberic")
  }

  if(!is.numeric(abs_mz_precursor))
  {
    stop("abs_mz_precursor must be numberic")
  }

  if(abs_mz_precursor<0)
  {
    stop("abs_mz_precursor must be numberic and higher than 0")
  }



  if(!is.numeric(abs_mz))
  {
    stop("abs_mz must be numberic")
  }


  if(!is.numeric(ppm))
  {
    stop("ppm must be numberic")
  }

  if(ppm<0)
  {
    stop("ppm must be numberic and higher than 0")
  }

  if(rt<0)
  {
    stop("rt must be numberic and higher than 0")
  }

  if(abs_mz<0)
  {
    stop("abs_mz must be numberic and higher than 0")
  }
  if(ppm_precursor<0)
  {
    stop("ppm_precursor must be numberic and higher than 0")
  }



  if(centroid==TRUE){
    if(verbose)cat("Centroiding ...","\n")
    for(i in 1:length(mapped_msms$mapped))
    {
      for(j in 1:length(mapped_msms$mapped[[i]]))
      {
        MSMS<-mapped_msms$mapped[[i]][[j]]
        MSMS@centroided<-F
        MSMS@polarity<-as.integer(1)
        MSMS@smoothed<-F
        MSMS<-MSnbase::pickPeaks(MSMS)
        mapped_msms$mapped[[i]][[j]]<-MSMS
      }
    }

    if(!centroid_onlymapped){
      for(i in 1:length(mapped_msms$unmapped))
      {

          MSMS<-mapped_msms$unmapped[[i]]
          MSMS@centroided<-F
          MSMS@polarity<-as.integer(1)
          MSMS@smoothed<-F
          MSMS<-MSnbase::pickPeaks(MSMS)
          mapped_msms$unmapped[[i]]<-MSMS

      }
    }
  }

  if(merge==TRUE)
  {
    if(verbose)cat("Creating hyperMS2 for mapped ions...","\n")
    for(i in 1:length(mapped_msms$mapped))
    {
      if(length(mapped_msms$mapped[[i]])>1)
      {
        merge_msms<-merge.spectra.group(mapped_msms$mapped[[i]],eppm = ppm* 10e-6,eabs = abs_mz_precursor,int.threshold = int_threshold)
        if(centroid_after_merge==TRUE)
        {
          MSMS<-merge_msms
          MSMS@centroided<-F
          MSMS@polarity<-as.integer(1)
          MSMS@smoothed<-F
          MSMS<-MSnbase::pickPeaks(MSMS)
          merge_msms<-MSMS
        }
        mapped_msms$mapped[[i]]<-list(merge_msms)
      }
    }

    if(merge_onlymapped==FALSE)
    {
      a <- collect.spectra.lists(mapped_msms$unmapped, abs_mz, ppm_precursor, rt)
      merged.spectra <- sapply(1:length(a), function(x) {
        merge.spectra.group(a[[x]], ppm * 10e-6, abs_mz, int_threshold)
      })

      if(centroid_onlymapped==FALSE & centroid_after_merge==TRUE)
      {
        list_of_unmapped<-c()
        for(i in 1:length(merged.spectra))
        {

          MSMS<-merged.spectra[[i]]
          MSMS@centroided<-F
          MSMS@polarity<-as.integer(1)
          MSMS@smoothed<-F
          MSMS<-MSnbase::pickPeaks(MSMS)
          list_of_unmapped[[i]]<-MSMS

        }
        mapped_msms$unmapped<-list_of_unmapped
      }

    }


  }

  return(mapped_msms)


}
