#!/usr/bin/env Rscript

adductCalculator<-function(mz=NA,charge=NA,mode="pos",adduct=NA, primary = T)
{
  if(is.na(mz))stop("Provide the mz!")
  if(is.na(mode))stop("Provide the polarity!")
  
  Ion.name.pos=c("M+3H",
             "M+2H+Na",
             "M+H+2Na",
             "M+3Na",
             "M+2H",
             "M+H+NH4",
             "M+H+Na",
             "M+H+K",
             "M+ACN+2H",
             "M+2Na",
             "M+2ACN+2H",
             "M+3ACN+2H",
             "M+H",
             "M+NH4",
             "M+Na",
             "M+CH3OH+H",
             "M+K",
             "M+ACN+H",
             "M+2Na-H",
             "M+IsoProp+H",
             "M+ACN+Na",
             "M+2K-H",
             "M+DMSO+H",
             "M+2ACN+H",
             "M+IsoProp+Na+H",
             "2M+H",
             "2M+NH4",
             "2M+Na",
             "2M+K",
             "2M+ACN+H",
             "2M+ACN+Na")
  
  Ion.mass.pos=c(
    "M/3 + 1.007276",
    "M/3 + 8.334590",
    "M/3 + 15.7661904",
    "M/3 + 22.989218",
    "M/2 + 1.007276",
    "M/2 + 9.520550",
    "M/2 + 11.998247",
    "M/2 + 19.985217",
    "M/2 + 21.520550",
    "M/2 + 22.989218",
    "M/2 + 42.033823",
    "M/2 + 62.547097",
    "M + 1.007276",
    "M + 18.033823",
    "M + 22.989218",
    "M + 33.033489",
    "M + 38.963158",
    "M + 42.033823",
    "M + 44.971160",
    "M + 61.06534",
    "M + 64.015765",
    "M + 76.919040",
    "M + 79.02122",
    "M + 83.060370",
    "M + 84.05511",
    "2M + 1.007276",
    "2M + 18.033823",
    "2M + 22.989218",
    "2M + 38.963158",
    "2M + 42.033823",
    "2M + 64.015765")
  
  Charge.pos=c(
    "3+",
    "3+",
    "3+",
    "3+",
    "2+",
    "2+",
    "2+",
    "2+",
    "2+",
    "2+",
    "2+",
    "2+",
    "1+",
    "1+",
    "1+",
    "1+",
    "1+",
    "1+",
    "1+",
    "1+",
    "1+",
    "1+",
    "1+",
    "1+",
    "1+",
    "1+",
    "1+",
    "1+",
    "1+",
    "1+",
    "1+")
  
  Extended.pos<-c(T,T,T,T,T,T,T,T,T,T,T,T,F,F,F,T,F,T,T,T,T,T,T,T,T,T,T,T,T,T,T) 
 
  Ion.name.neg<-c("M-3H",
                 "M-2H",
                 "M-H2O-H",
                 "M-H",
                 "M+Na-2H",
                 "M+Cl",
                 "M+K-2H",
                 "M+FA-H",
                 "M+Hac-H",
                 "M+Br",
                 "M+TFA-H",
                 "2M-H",
                 "2M+FA-H",
                 "2M+Hac-H",
                 "3M-H")
  
  Ion.mass.neg<-c("M/3 - 1.007276",
    "M/2 - 1.007276",
    "M - 19.01839",
    "M - 1.007276",
    "M + 20.974666",
    "M + 34.969402",
    "M + 36.948606",
    "M + 44.998201",
    "M + 59.013851",
    "M + 78.918885",
    "M + 112.985586",
    "2M - 1.007276",
    "2M + 44.998201",
    "2M + 59.013851",
    "3M - 1.007276")
  
  Charge.neg<-c("3-",
    "2-",
    "1-",
    "1-",
    "1-",
    "1-",
    "1-",
    "1-",
    "1-",
    "1-",
    "1-",
    "1-",
    "1-",
    "1-",
    "1-")

  Extended.neg<-c(T,T,T,F,F,F,F,T,T,T,T,T,T,T,T)
  
  adductsFile.pos<-data.frame(
	Ion.name=Ion.name.pos[!(Extended.pos & primary)],
	Ion.mass=Ion.mass.pos[!(Extended.pos & primary)],
	Charge=Charge.pos[!(Extended.pos & primary)])
  adductsFile.neg<-data.frame(
	Ion.name=Ion.name.neg[!(Extended.neg & primary)],
	Ion.mass=Ion.mass.neg[!(Extended.neg & primary)],
	Charge=Charge.neg[!(Extended.neg & primary)])

  if(tolower(mode)%in%c("pos","positive","p"))
  {
    # select the adducts (primary or extended)
    tmpAdduct<-adductsFile.pos
    if(!is.na(charge) & is.numeric(charge))
    {
      chargeSign<-NA
      chargeSign<-"+"
      tmpAdduct<-tmpAdduct[tmpAdduct[,"Charge"]==paste(charge,chargeSign,sep=""),]
    }
    if(!is.na(adduct))
    {
      
      tmpAdduct<-tmpAdduct[tmpAdduct[,"Ion.name"]%in%adduct,]
    }
    
    if(nrow(tmpAdduct)==0){
      warning("Not found! Reporting all possible adducts")
      tmpAdduct<-adductsFile.pos
    }
    signs<-sapply(str_extract(as.character(tmpAdduct[,"Ion.mass"]),"\\+|\\-"),function(x){x[[1]]})
    signs[signs=="+"]=-1
    signs[signs=="-"]=+1
    mzCoefficients<-
      str_extract(sapply(strsplit(as.character(tmpAdduct[,"Ion.mass"]),split = "\\+|\\-"),function(x){x[1]}),
                  "\\d+")
    
    mzCoefficients[is.na(mzCoefficients)]<-1
    mzCoefficients<-as.numeric(mzCoefficients)
    mzCoefficients[!grepl("/",as.character(tmpAdduct[,"Ion.mass"]),fixed=T)]<-
      1/ mzCoefficients[!grepl("/",as.character(tmpAdduct[,"Ion.mass"]),fixed=T)]
    
    result<- mz+  (as.numeric(signs)*
            as.numeric(sapply(strsplit(as.character(tmpAdduct[,"Ion.mass"]),"\\+|\\-"),function(x){x[[2]]})))

    result<- result*mzCoefficients
  }else if(tolower(mode)%in%c("neg","negative","n"))
  {
    tmpAdduct<-adductsFile.neg
    if(!is.na(charge) & is.numeric(charge))
    {
      chargeSign<-NA
     chargeSign<-"-"
      tmpAdduct<-tmpAdduct[tmpAdduct[,"Charge"]==paste(charge,chargeSign,sep=""),]
    }
    if(!is.na(adduct))
    {
      
      tmpAdduct<-tmpAdduct[tmpAdduct[,"Ion.name"]%in%adduct,]
    }
    
    if(nrow(tmpAdduct)==0){
      warning("Not found! Reporting all possible adducts")
      tmpAdduct<-adductsFile.neg
    }
    signs<-sapply(str_extract(as.character(tmpAdduct[,"Ion.mass"]),"\\+|\\-"),function(x){x[[1]]})
    signs[signs=="+"]=-1
    signs[signs=="-"]=+1
    mzCoefficients<-
      str_extract(sapply(strsplit(as.character(tmpAdduct[,"Ion.mass"]),split = "\\+|\\-"),function(x){x[1]}),
                  "\\d+")
    
    mzCoefficients[is.na(mzCoefficients)]<-1
    mzCoefficients<-as.numeric(mzCoefficients)
    mzCoefficients[!grepl("/",as.character(tmpAdduct[,"Ion.mass"]),fixed=T)]<-
      1/ mzCoefficients[!grepl("/",as.character(tmpAdduct[,"Ion.mass"]),fixed=T)]
    
    result<- mz+  (as.numeric(signs)*
                     as.numeric(sapply(strsplit(as.character(tmpAdduct[,"Ion.mass"]),"\\+|\\-"),function(x){x[[2]]})))
    result<- result*mzCoefficients
    
  }else 
  {
    stop("Incorrect mode! Mode has to be either positive or negative!")
  }
 
  
return(data.frame(correctedMS=result,adductName=tmpAdduct[,"Ion.name"]))
  
}
