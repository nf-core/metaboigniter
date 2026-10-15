#!/usr/bin/env python

# Written by Payam Emami and Axel Walter and released under the MIT license.

import os
import numpy as np
import pandas as pd
import pyopenms as py
import argparse


def get_tol_window(val, tol, ppm):
    if ppm:
        left = val - val * tol * 1e-6
        right = val / (1.0 - tol * 1e-6)
    else:
        left = val - tol
        right = val + tol

    return (left, right)


def get_highest_intensity_peak_in_mz_range(test_mz, spectrum, tolerance, ppm, rt_min, rt_max):
    tolerance_window = get_tol_window(test_mz, tolerance, ppm)

    peaks_in_window = spectrum.get2DPeakDataLong(rt_min, rt_max, tolerance_window[0], tolerance_window[1])

    if len(peaks_in_window[0]) == 0:
        return []

    max_element = peaks_in_window[2].argmax()
    return [peaks_in_window[1][max_element], peaks_in_window[2][max_element]]


def extract_precursor_isotope_pattern(precursor_mz, precursor_spectrum, iterations, charge, tolerance, rt_min, rt_max):
    isotopes = []
    ppm = True
    isotope_tolerance = 1

    peak = get_highest_intensity_peak_in_mz_range(precursor_mz, precursor_spectrum, tolerance, ppm, rt_min, rt_max)
    if len(peak) > 0:
        isotopes.append(peak)

    # further isotope_traces with the mass error of 1 ppm
    massdiff = 1.0033548378  # this is the C13C12_MASSDIFF_U

    if charge != 0:
        massdiff = massdiff / abs(charge)

    while len(peak) > 0 and iterations > 0:
        peak = get_highest_intensity_peak_in_mz_range(
            peak[0] + massdiff, precursor_spectrum, isotope_tolerance, ppm, rt_min, rt_max
        )
        if len(peak) > 0:
            isotopes.append(peak)

        iterations -= 1

    return isotopes  # return isotopes as pandas DataFrame


parser = argparse.ArgumentParser(description="Mass Spectrometry Data Processing Tool")

parser.add_argument("--input_feature", help="Path to consensus XML file")
parser.add_argument("--input_mzml", help="Path to consensus XML file")

parser.add_argument("--ppm", type=float, default=10, help="ppm for isotope detection")
parser.add_argument("--mz", type=float, default=6.5, help="ppm for isotope detection")
parser.add_argument("--rt", type=float, default=3, help="RT for isotope detection")
parser.add_argument("--iterations", type=int, default=3, help="RT for isotope detection")
parser.add_argument("--polarity", choices=["positive", "negative"], default="positive", help="Polarity of the data")

parser.add_argument("--output_feature", help="Path to consensus XML file")


args = parser.parse_args()


## load feature files
features = py.FeatureMap()
py.FeatureXMLFile().load(args.input_feature, features)

## load mzMLfie

exp = py.MSExperiment()
py.MzMLFile().load(args.input_mzml, exp)

exp.updateRanges(1)
max_rt_exp = exp.getMaxRT()
min_rt_exp = exp.getMinRT()

max_mz_exp = exp.getMaxMZ()
min_mz_exp = exp.getMinMZ()


empty_protein_id = py.ProteinIdentification()

empty_protein_id.setIdentifier("UNKNOWN_SEARCH_RUN_IDENTIFIER")
features.setProteinIdentifications([empty_protein_id])


all_ints = 0
for i in range(features.size()):
    sl_feature = features[i]
    sl_feature.setConvexHulls([])
    sl_feature.setSubordinates([])
    all_ints += sl_feature.getIntensity()
    features[i] = sl_feature


for i in range(features.size()):
    sl_feature = features[i]
    sl_feature.setConvexHulls([])
    sl_feature.setSubordinates([])
    rt = sl_feature.getRT()
    mz = sl_feature.getMZ()

    charge_f = sl_feature.getCharge()
    if args.polarity == "positive" and charge_f == 0:
        charge_f = 1
    elif args.polarity == "negative" and charge_f == 0:
        charge_f = -1

    rt_max = max_rt_exp if (rt + args.rt) > max_rt_exp else (rt + args.rt)
    rt_min = min_rt_exp if (rt - args.rt) < min_rt_exp else (rt - args.rt)

    mz_max = max_mz_exp if (mz + args.mz) > max_mz_exp else (mz + args.mz)
    mz_min = min_mz_exp if (mz - args.mz) < min_mz_exp else (mz - args.mz)

    iso = extract_precursor_isotope_pattern(mz, exp, args.iterations, charge_f, args.ppm, rt_min, rt_max)

    peptide = py.PeptideIdentification()
    peptide.setRT(rt)
    peptide.setMZ(mz)
    iso_mz = []
    iso_in = []
    if len(iso) > 0:
        iso_mz = list([float(mz[0]) for mz in iso])
        iso_in = [float(inte[1]) for inte in iso]

    peptide.setMetaValue("isotope_calcdist_mz", iso_mz)
    peptide.setMetaValue("isotope_calcdist_int", iso_in)

    iso_mz = []
    iso_in = []
    if sl_feature.metaValueExists("masstrace_intensity"):
        iso_mz = sl_feature.getMetaValue("masstrace_centroid_mz")
        iso_in = sl_feature.getMetaValue("masstrace_intensity")

    peptide.setMetaValue("masstrace_intensity", iso_in)
    peptide.setMetaValue("masstrace_centroid_mz", iso_mz)

    peptide.setMetaValue("feature_quality", sl_feature.getOverallQuality())
    peptide.setMetaValue("normalized_intensity", (sl_feature.getIntensity() / all_ints))

    peptide.setIdentifier(empty_protein_id.getIdentifier())

    sl_feature.setPeptideIdentifications([peptide])
    features[i] = sl_feature

py.FeatureXMLFile().store(args.output_feature, features)
