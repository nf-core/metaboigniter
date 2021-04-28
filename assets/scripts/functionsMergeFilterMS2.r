merge.spectra.group <- function(spectra, eppm, eabs, int.threshold) {
  if(is.na(spectra) || length(spectra) == 0) return(NULL)
  max.precursor.int <- -1
  rt.at.max.int <- NA
  start.rt <- attributes(spectra[[1]])$rt
  end.rt <- attributes(spectra[[1]])$rt
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
  return(res)
}

grouped.list.to.matrix <- function(grouped.spectra) {
  data.mat <- matrix(0, ncol=3, nrow=0)
  colnames(data.mat) <- c("mz", "rt", "gid")
  for (i in 1:length(grouped.spectra)) {
    for(j in 1:length(grouped.spectra[[i]])) {
      data.mat <- rbind(data.mat, 
                        c(grouped.spectra[[i]][[j]]@precursorMz, grouped.spectra[[i]][[j]]@rt, i))
    }
  }
  return(data.mat)
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

plot.grouped.spectra <- function(grouped.spectra) {
  if(class(grouped.spectra)=="list" & length(grouped.spectra) > 0) {
    set.seed(100)
    cols <- sample(rainbow(length(grouped.spectra)))
    data.mat <- grouped.list.to.matrix(grouped.spectra)
    plot(data.mat[,2], data.mat[,1], col=cols[data.mat[,3]], xlab="RT", ylab="m/z")
    sapply(unique(data.mat[,3]), function(x) {
      a <- data.mat[data.mat[,3]==x,]
      if(class(a)=="numeric") a <- matrix(a, ncol=3)
      text(min(a[,2]), min(a[,1]), labels = x, col=cols[cols[x]], srt=45, cex=0.5)
    })
  }
}

save.plot.grouped.spectra <- function(grouped.spectra, file.name) {
  pdf(file.name, width=20, height=15)
  plot.grouped.spectra(grouped.spectra)
  dev.off()
}

filter.grouped.spectra <- function(grouped.spectra, max.rt.range, max.mz.range, min.rt, max.rt, min.mz, max.mz) {
  filtered.grouped.spectra <- list()
  sapply(grouped.spectra, function(grouped.spectrum) {
    mzs<-sapply(grouped.spectrum, function(x) attributes(x)$precursorMz) 
    rts<-sapply(grouped.spectrum, function(x) attributes(x)$rt)
    mean.mzs <- mean(mzs)
    mean.rts <- mean(rts)
    max.number.peaks <- max(sapply(grouped.spectrum, function(x) attributes(x)$peaksCount))
    if((max(mzs)-min(mzs)) <= max.mz.range & (max(rts)-min(rts)) <= max.rt.range & mean.rts < max.rt & mean.mzs < max.mz
       & mean.rts > min.rt & mean.mzs > min.mz & max.number.peaks > 0) {
      filtered.grouped.spectra[[length(filtered.grouped.spectra) + 1]] <<- grouped.spectrum
    }
  })
  return(filtered.grouped.spectra)
}

merge.spectra <- function(spectra, mzabs, mzppm, rtabs, max.rt.range, max.mz.range, min.rt, max.rt, min.mz, max.mz, output.pdf = NA, int.threshold = 0) {
  a <- collect.spectra.lists(spectra, mzabs, mzppm, rtabs)
  if(length(a) != 0 & !is.na(output.pdf)) {save.plot.grouped.spectra(a, output.pdf)}
  print(paste("Collected",length(a),"spectrum groups"))
  b <- filter.grouped.spectra(a, max.rt.range, max.mz.range, min.rt, max.rt, min.mz, max.mz)
  print(paste("Filtered",length(b),"spectrum groups"))
  merged.spectra <- sapply(1:length(b), function(x) {
    merge.spectra.group(b[[x]], mzppm * 10e-6, mzabs, int.threshold)
  })
  b<-Filter(Negate(is.null), merged.spectra)
  print(paste("Filtered",length(b),"spectrum groups with peak information"))
  return(b)
}
