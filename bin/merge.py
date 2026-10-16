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
parser.add_argument("--mz_tolerance_ppm", type=float, default=10.0, help="m/z tolerance (ppm) to consider a feature already detected")
parser.add_argument("--rt_tolerance", type=float, default=10.0, help="RT tolerance (s) to consider a feature already detected")


args = parser.parse_args()
fm_ffm = FeatureMap()
FeatureXMLFile().load(args.inputc, fm_ffm)
fm_ffmid = FeatureMap()
FeatureXMLFile().load(args.inputr, fm_ffmid)


def is_detected(feature, detections):
    mz = feature.getMZ()
    rt = feature.getRT()
    for d in detections:
        if (
            abs(d.getRT() - rt) <= args.rt_tolerance
            and abs(d.getMZ() - mz) / mz * 1e6 <= args.mz_tolerance_ppm
        ):
            return True
    return False


# keep every original detection, only fill in features without a detection
detections = [f for f in fm_ffm]
for f in fm_ffmid:
    if not is_detected(f, detections):
        fm_ffm.push_back(f)
fm_ffm.setUniqueIds()

FeatureXMLFile().store(args.output, fm_ffm)
