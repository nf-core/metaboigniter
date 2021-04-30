#!/usr/bin/env python
import sys
from pyopenms import *

# Read inputs
nameOfInputMzml=sys.argv[1]
nameOfOutput=sys.argv[2]



fmap = FeatureMap()
FeatureXMLFile().load(nameOfInputMzml, fmap)

f= open(nameOfOutput, 'w')
f.write("mz,mzmin,mzmax,rt,rtmin,rtmax,npeaks,into,intb,maxo,sn,sample,isotopes,charge,y,iso,val\n")
idIso=0
chargeStr=sys.argv[3]

for feature in fmap:
   idIso=idIso+1
   for i in range(len(feature.getConvexHulls())):
      centMZ=feature.getMetaValue("masstrace_centroid_mz")[i]
      centInt=feature.getMetaValue("masstrace_intensity")[i]
      centRT=feature.getMetaValue("masstrace_centroid_rt")[i]
      rtmin=feature.getConvexHulls()[i].getBoundingBox().minPosition()[0] #RT low
      mzmin=feature.getConvexHulls()[i].getBoundingBox().minPosition()[1]  # mz low
      rtmax=feature.getConvexHulls()[i].getBoundingBox().maxPosition()[0] #RT high
      mzmax=feature.getConvexHulls()[i].getBoundingBox().maxPosition()[1]  # mz high
      npeaks=len(feature.getConvexHulls()[i].getHullPoints()) # number of peaks
      sn=feature.getOverallQuality() # quality
      charge=feature.getCharge() # charge
      label = ""
      if len(feature.getConvexHulls())>1:
         isoStr = i
         if isoStr==0:
            label="["+ str(idIso)+ "]"+ "["+ "M"+ "]"+ chargeStr
         else:
            label = "[" + str(idIso) + "]" + "[" + "M+"+str(isoStr) + "]" + chargeStr
         y=idIso
         iso=isoStr
         val=0
      else:
         y="NA"
         iso="NA"
         val="NA"
      line=[str(centMZ),str(mzmin),str(mzmax),str(centRT),str(rtmin),str(rtmax),str(npeaks),str(centInt),str(centInt),str(centInt),str(sn),str(1),(label),str(charge),str(y),str(iso),str(val)]
      line=",".join(line)+"\n"
      f.write(line)
