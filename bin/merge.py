#!/usr/bin/env python


# Written by Payam Emami and Axel Walter and released under the MIT license.



from pyopenms import *
import os
import glob
import sys

import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--inputc", help="input complete featureXML file")
parser.add_argument("--inputr", help="input requantified featureXML file")
parser.add_argument("--output", help="output featureXML file")


args = parser.parse_args()
fm_ffm = FeatureMap()
FeatureXMLFile().load(args.inputc, fm_ffm)
fm_ffmid = FeatureMap()
FeatureXMLFile().load(args.inputr, fm_ffmid)
for f in fm_ffmid:
    fm_ffm.push_back(f)
fm_ffm.setUniqueIds()

FeatureXMLFile().store(args.output, fm_ffm)
