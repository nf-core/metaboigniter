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


def get_highest_intensity_peak_in_mz_range(test_mz, spectrum, tolerance, ppm):
    tolerance_window = get_tol_window(test_mz, tolerance, ppm)

    # Assume spectrum is a pandas DataFrame
    mask = (spectrum["mz"] >= tolerance_window[0]) & (spectrum["mz"] <= tolerance_window[1])
    peaks_in_window = spectrum[mask]

    if peaks_in_window.empty:
        return -1

    # Get the index of the peak with max intensity
    max_intensity_index = peaks_in_window["intensity"].idxmax()

    return max_intensity_index


def extract_precursor_isotope_pattern(precursor_mz, precursor_spectrum, iterations, charge, tolerance=10):
    isotopes = []
    ppm = True
    isotope_tolerance = 1

    peak_index = get_highest_intensity_peak_in_mz_range(precursor_mz, precursor_spectrum, tolerance, ppm)

    if peak_index != -1:
        peak = precursor_spectrum.loc[peak_index]
        isotopes.append(peak)

    # further isotope_traces with the mass error of 1 ppm
    massdiff = 1.0033548378  # this is the C13C12_MASSDIFF_U

    if charge != 0:
        massdiff = massdiff / abs(charge)

    while peak_index != -1 and iterations > 0:
        peak_index = get_highest_intensity_peak_in_mz_range(
            peak["mz"] + massdiff, precursor_spectrum, isotope_tolerance, ppm
        )
        if peak_index != -1:
            peak = precursor_spectrum.loc[peak_index]
            isotopes.append(peak)

        iterations -= 1

    return pd.DataFrame(isotopes)  # return isotopes as pandas DataFrame


def to_adduct_string(ion_string, charge):
    # Initialize an instance of EmpiricalFormula with ion_string
    ef = py.EmpiricalFormula(ion_string)

    charge_sign = "+" if charge >= 0 else "-"
    s = "[M"

    # Use a dictionary for sorting elements
    sorted_elem_map = {}

    for em in ef.getElementalComposition():
        element_count = [em.decode(), ef.getElementalComposition()[em]]
        e_symbol = element_count[0]
        tmp = "+" if element_count[1] > 0 else "-"
        tmp += str(abs(element_count[1])) if abs(element_count[1]) > 1 else ""
        tmp += e_symbol
        sorted_elem_map[e_symbol] = tmp

    for sorted_e_cnt in sorted(sorted_elem_map.items()):
        s += sorted_e_cnt[1]

    s += "]"
    s += str(abs(charge)) if abs(charge) > 1 else ""
    s += charge_sign

    return s


def change_extension_to(file_paths, ext):
    return [os.path.splitext(file)[0] + ext for file in file_paths]


parser = argparse.ArgumentParser(description="Mass Spectrometry Data Processing Tool")

parser.add_argument("--consensus_file_path", help="Path to consensus XML file")
parser.add_argument("--mzml_file_paths", nargs="+", help="List of mzML file paths")
parser.add_argument(
    "--ion_select", choices=["all", "merge", "most_intense"], default="all", help="Ion selection method"
)
parser.add_argument("--use_feature_ionization", action="store_true", help="Flag to use feature ionization")
# parser.add_argument("--use_cons_mz", action="store_true", help="Flag to use consensus mz")
parser.add_argument("--ms1_data_from", choices=["MS1", "best_MS1", "MS2"], default="MS2", help="Source for MS1 data")
parser.add_argument(
    "--feature_selection", choices=["intensity", "quality"], default="quality", help="Feature selection method"
)
parser.add_argument("--normalized_intensity", action="store_true", help="Flag to use normalized intensity")
parser.add_argument("--iterations", type=float, default=3, help="Number of iterations")
parser.add_argument("--ppm_map", type=float, default=20, help="PPM for mapping")
parser.add_argument("--polarity", choices=["positive", "negative"], default="positive", help="Polarity of the data")

parser.add_argument("--csv_output", nargs="+", help="List of csv file paths")

parser.add_argument("--ms_output", help="Path to msfile")


parser.add_argument("--mgf_output", help="Path to mgf file")


args = parser.parse_args()


consensus_file_path = args.consensus_file_path
mzml_file_paths = args.mzml_file_paths


output = args.ms_output
output_mgf = args.mgf_output
outputs_unampped = args.csv_output


ion_select = args.ion_select


use_feature_ionization = args.use_feature_ionization
use_cons_mz = True

feature_selection = args.feature_selection
normalized_intensity_flag = args.normalized_intensity
iterations = args.iterations
ppm_map = args.ppm_map


polarity = args.polarity

# os.chdir("/Users/payam/wabi_projects/metaboigniter_new/work/5e/e8ed3e068021a6b65fe604d3526d74")
# args.consensus_file_path="Preprocessed_unfiltered.consensusXML"


def getPrecursorSpectrum(spec_index, spectra, use_rt=True, rt=-1, only_rt=False):
    spc = 0
    if use_rt == False and only_rt == False:
        for i in reversed(range(spec_index)):
            spc = spectra.getSpectrum(i)
            if spc.getMSLevel() == 1:
                break
    elif use_rt == True and only_rt == False:
        for i in reversed(range(spec_index)):
            spc1 = spectra.getSpectrum(i)
            if spc1.getMSLevel() == 1:
                break
        for i in range(spec_index, spectra.getNrSpectra()):
            spc2 = spectra.getSpectrum(i)
            if spc2.getMSLevel() == 1:
                break

        if abs(spc1.getRT() - rt) < abs(spc2.getRT() - rt):
            spc = spc1
        else:
            spc = spc2
    elif use_rt == True and only_rt == True:
        rt_dif = 1000000
        index_closest = -1
        for i in range(spectra.getNrSpectra()):
            spc1 = spectra.getSpectrum(i)
            if abs(spc1.getRT() - rt) < rt_dif and spc1.getMSLevel() == 1:
                index_closest = i
                rt_dif = abs(spc1.getRT() - rt)
        spc = spectra.getSpectrum(index_closest)
    return spc


consensus_file = py.ConsensusXMLFile()
consensus_map = py.ConsensusMap()
consensus_file.load(consensus_file_path, consensus_map)

specs_list = [py.OnDiscMSExperiment() for _ in range(len(mzml_file_paths))]
feature_list = []

for map_index in range(len(mzml_file_paths)):
    specs_list[map_index].openFile(mzml_file_paths[map_index], False)


map_index_rm = {path: [] for path in outputs_unampped}


## there exist spectra
exist_one_spectra = False
## generate consensus MGF file
f_mgf = open(output_mgf, "w")
for cons_i in range(consensus_map.size()):
    feature = consensus_map[cons_i]
    feature_pepts_all = feature.getPeptideIdentifications()
    all_file_names = []
    feature_pepts = []
    if len(feature_pepts_all) == 0:
        continue
    for pept_id in feature_pepts_all:
        if pept_id.metaValueExists("spectrum_index"):
            # map_index = pept_id.getMetaValue("map_index")
            spec_index = pept_id.getMetaValue("spectrum_index")
            ms2_index = pept_id.getMetaValue("id_file_index")
            ms2_file_name = pept_id.getMetaValue("id_file")
            all_file_names.append(ms2_file_name + "_" + str(spec_index))
            feature_pepts.append(pept_id)

    if len(all_file_names) == 0:
        continue

    print(cons_i)
    subset_dict = {}
    for file, feature_s in zip(all_file_names, feature_pepts):
        if file not in subset_dict:
            subset_dict[file] = [feature_s]
        else:
            subset_dict[file].append(feature_s)

    feature_charge = feature.getCharge()

    charge_f = (
        "CHARGE=" + str(1 if feature_charge == 0 else abs(feature_charge)) + ("+" if polarity == "positive" else "-")
    )
    mz_f = "PEPMASS=" + str(feature.getMZ())
    rt_f = "RTINSECONDS=" + str(feature.getRT())
    id_f = "FEATURE_ID=e_" + str(feature.getUniqueId())
    level_f = "MSLEVEL=2"
    scan_f = "SCANS=" + str(cons_i)

    adduct_f = ""
    if feature.metaValueExists("best ion") == True:
        adduct_f = feature.getMetaValue("best ion")

    IONMODE = polarity

    for p in subset_dict.keys():
        id_sel = subset_dict[p][0]
        map_index = id_sel.getMetaValue("id_file_index")
        spec_index = id_sel.getMetaValue("spectrum_index")
        file_name = id_sel.getMetaValue("id_file")
        kk = specs_list[map_index].getSpectrum(spec_index)
        ms2_peaks = kk.get_peaks()
        if len(ms2_peaks[0]) == 0:
            continue
        exist_one_spectra = True
        ms1_ms2_peaks = ""
        for ms_2_i in range(len(ms2_peaks[0])):
            ms1_ms2_peaks = ms1_ms2_peaks + str(ms2_peaks[0][ms_2_i]) + " " + str(ms2_peaks[1][ms_2_i]) + "\n"

        comb_ms2 = (
            "BEGIN IONS"
            + "\n"
            + scan_f
            + "\n"
            + id_f
            + "\n"
            + level_f
            + "\n"
            + charge_f
            + "\n"
            + mz_f
            + "\n"
            + "FILE_INDEX="
            + str(map_index)
            + "\n"
            + "FILE_NAME="
            + file_name
            + "\n"
            + rt_f
            + "\n"
            + ms1_ms2_peaks
            + "\n"
            + "END IONS"
            + "\n"
        )
        f_mgf.write(comb_ms2)

f_mgf.close()


## generate consensus MS File
f = open(output, "w")
for cons_i in range(consensus_map.size()):
    feature = consensus_map[cons_i]
    feature_pepts_all = feature.getPeptideIdentifications()
    all_file_names = []
    if feature.getCharge() > 1 or feature.getCharge() < -1:
        continue
    if len(feature_pepts_all) == 0:
        continue

    masstrace_intensity = []
    masstrace_centroid_mz = []
    isotope_calcdist_mz = []
    isotope_calcdist_int = []
    feature_quality = []
    map_index_meta = []
    normalized_intensity = []
    feature_pepts = []
    ## extract spectrum
    for pept_id in feature_pepts_all:
        if pept_id.metaValueExists("spectrum_index"):
            # map_index = pept_id.getMetaValue("map_index")
            spec_index = pept_id.getMetaValue("spectrum_index")
            ms2_index = pept_id.getMetaValue("id_file_index")
            ms2_file_name = pept_id.getMetaValue("id_file")
            all_file_names.append(ms2_file_name + "_" + str(spec_index))
            feature_pepts.append(pept_id)
        elif pept_id.metaValueExists("masstrace_intensity"):
            masstrace_intensity.append(pept_id.getMetaValue("masstrace_intensity"))
            masstrace_centroid_mz.append(pept_id.getMetaValue("masstrace_centroid_mz"))
            isotope_calcdist_mz.append(pept_id.getMetaValue("isotope_calcdist_mz"))
            isotope_calcdist_int.append(pept_id.getMetaValue("isotope_calcdist_int"))
            feature_quality.append(pept_id.getMetaValue("feature_quality"))
            map_index_meta.append(pept_id.getMetaValue("map_index"))
            normalized_intensity.append(pept_id.getMetaValue("normalized_intensity"))

    if len(all_file_names) == 0:
        continue
    subset_dict = dict(zip(all_file_names, feature_pepts))
    selected_id = list(subset_dict.values())

    empty_spectra = True
    ms1_ms2_peaks = ""
    all_precursor_charges = {}
    all_inds = []
    all_ids = []
    for id_sel in selected_id:
        map_index = id_sel.getMetaValue("id_file_index")
        spec_index = id_sel.getMetaValue("spectrum_index")
        kk = specs_list[map_index].getSpectrum(spec_index)
        ms2_peaks = kk.get_peaks()
        id_to_c = py.SpectrumLookup().extractScanNumber(
            kk.getNativeID(), specs_list[map_index].getMetaData().getSourceFiles()[0].getNativeIDTypeAccession()
        )
        ms1_spec = getPrecursorSpectrum(spec_index, specs_list[map_index], use_rt=False, rt=kk.getRT(), only_rt=False)

        ms1_peaks = ms1_spec.get_peaks()
        map_index_rm[outputs_unampped[map_index]].append(spec_index)
        if len(ms2_peaks) > 0:
            empty_spectra = False
        else:
            continue

        all_inds.append(spec_index)
        all_ids.append(id_to_c)
        collision = kk.getPrecursors()[0].getActivationEnergy()
        pre_charge = kk.getPrecursors()[0].getCharge()
        if pre_charge in all_precursor_charges:
            all_precursor_charges[pre_charge] += 1
        else:
            all_precursor_charges[pre_charge] = 1

        if isinstance(ms1_spec, int):
            raise Exception(
                "No MS1 peak where found for ID: " + str(spec_index) + " in map: " + mzml_file_paths[map_index]
            )
        ms1_ms2_peaks = ms1_ms2_peaks + ">ms1peaks\n"
        for ms_1_i in range(len(ms1_peaks[0])):
            ms1_ms2_peaks = ms1_ms2_peaks + str(ms1_peaks[0][ms_1_i]) + " " + str(ms1_peaks[1][ms_1_i]) + "\n"
        if collision == 0.0:
            ms1_ms2_peaks = ms1_ms2_peaks + ">ms2peaks\n"
        else:
            ms1_ms2_peaks = ms1_ms2_peaks + ">collision" + " " + str(collision) + "\n"

        for ms_2_i in range(len(ms2_peaks[0])):
            ms1_ms2_peaks = ms1_ms2_peaks + str(ms2_peaks[0][ms_2_i]) + " " + str(ms2_peaks[1][ms_2_i]) + "\n"

    most_common_charge = max(all_precursor_charges, key=all_precursor_charges.get)

    if empty_spectra == True:
        continue

    exist_one_spectra = True
    all_precursor_charges

    mz_trace = 0
    int_trace = 0
    output_ms_dt = ""

    f_rt = feature.getRT()
    f_mz = feature.getMZ()
    f_int = feature.getIntensity()
    charge_f = feature.getCharge()

    ionization = ""
    if feature.metaValueExists("best ion") == True and use_feature_ionization == True:
        ionization = ">ionization " + feature.getMetaValue("best ion")

    charge_f = (1 if polarity == "positive" else -1) * (1 if charge_f == 0 else abs(charge_f))

    # extract the top feature
    int_of_features = [sub_feature.getIntensity() for sub_feature in feature.getFeatureList()]

    maps_of_features = [sub_feature.getMapIndex() for sub_feature in feature.getFeatureList()]

    ids_of_features = [sub_feature.getUniqueId() for sub_feature in feature.getFeatureList()]

    index_of_the_best = ""
    if args.feature_selection == "intensity":
        index_of_the_best = maps_of_features.index(maps_of_features[int_of_features.index(max(int_of_features))])
        if normalized_intensity_flag:
            index_of_the_best = normalized_intensity.index(max(normalized_intensity))
    elif args.feature_selection == "quality":
        index_of_the_best = feature_quality.index(max(feature_quality))

    ## first check if mass trace isotope is there if not use the calced isotope

    if len(masstrace_centroid_mz[index_of_the_best]) > 1:
        iso_int = masstrace_intensity[index_of_the_best]
        iso_mz = masstrace_centroid_mz[index_of_the_best]
    else:
        iso_int = isotope_calcdist_int[index_of_the_best]
        iso_mz = isotope_calcdist_mz[index_of_the_best]

    feature_id = ids_of_features[maps_of_features.index(map_index_meta[index_of_the_best])]

    compound_id = (
        ">compound "
        + "_"
        + str(feature.getUniqueId())
        + "-"
        + str(all_ids[0])
        + "-"
        + "-"
        + str(all_inds[0])
        + "--"
        + "UNKOWN"
    )
    parent_mass = ">parentmass " + str(f_mz)
    parent_rt = ">rt " + str(f_rt)
    comments = "##best_feature_id " + str(feature_id) + "\n"

    charge_cmp = ">charge " + str(charge_f)
    ms1_merged = ""
    if len(iso_mz) > 0:
        ms1_merged = ">ms1merged\n"
        for i_iso in range(len(iso_mz)):
            ms1_merged = ms1_merged + str(iso_mz[i_iso]) + " " + str(iso_int[i_iso]) + "\n"
    comb_ms2 = (
        compound_id
        + "\n"
        + parent_mass
        + "\n"
        + ionization
        + "\n"
        + charge_cmp
        + "\n"
        + parent_rt
        + "\n"
        + comments
        + "\n"
        + ms1_merged
        + "\n"
        + ms1_ms2_peaks
        + "\n"
    )
    f.write(comb_ms2)

f.close()


for key, values in map_index_rm.items():
    # Create a filename based on the key

    # Write the values to the CSV file
    with open(key, "w") as file:
        # Write the header
        file.write("index\n")

        # Write the values
        for value in values:
            file.write(str(value) + "\n")

#
#
# for ks in range(len(map_index_rm)):
#
#   if len(set(map_index_rm[list(map_index_rm.keys())[ks]]))>=specs_list[ks].getNrSpectra():
#     continue
#   f = open(outputs_unampped[ks], "w")
#   f_mgf = open(outputs_unampped_mgf[ks], "w")
#
#   comb_ms2 = ""
#   for i in range(specs_list[ks].getNrSpectra()):
#     if map_index_rm[list(map_index_rm.keys())[ks]].count(i)==0:
#       spec = specs_list[ks].getSpectrum(i)
#       spectra = specs_list[ks].getMetaData()
#
#       # ainfo_sf_path = spectra.getSourceFiles()[0].getPathToFile();
#       # ainfo_sf_filename = spectra.getSourceFiles()[0].getNameOfFile();
#       # ainfo_sf_type = spectra.getSourceFiles()[0].getFileType();
#       #
#       # ainfo_native_id_accession = spectra.getSourceFiles()[0].getNativeIDTypeAccession();
#       # ainfo_native_id_type = spectra.getSourceFiles()[0].getNativeIDType();
#
#       if spec.getMSLevel()==2:
#         pre_kh = getPrecursorSpectrum(i,specs_list[ks],use_rt=False,rt=spec.getRT(),only_rt=False)
#         precursor_mz=spec.getPrecursors()[0].getMZ()
#         precursor_spectrum = pd.DataFrame(pre_kh.get_peaks()).T
#         precursor_spectrum.columns=["mz","intensity"]
#         charge_f = spec.getPrecursors()[0].getCharge()
#         if polarity == "positive" and charge_f==0:
#           charge_f = 1
#         elif polarity == "negative" and charge_f==0:
#           charge_f = -1
#
#         iso=extract_precursor_isotope_pattern(precursor_mz,precursor_spectrum,iterations,charge_f,ppm_map)
#
#         f_rt=pre_kh.getRT()
#         f_mz=precursor_mz
#
#         native_id=spec.getNativeID()
#         #scan_number = py.SpectrumLookup().extractScanNumber(native_id, ainfo_native_id_accession);
#
#         mz_trace = 0
#         if len(iso)>0:
#           mz_trace = iso["mz"].to_list()
#           int_trace = iso["intensity"].to_list()
#           f_mz=list(iso["mz"])[0]
#
#         id_to_c = py.SpectrumLookup().extractScanNumber(spec.getNativeID(),specs_list[ks].getMetaData().getSourceFiles()[0].getNativeIDTypeAccession())
#         compound_id= ">compound " +  "_" + str(0)+"-" + str(id_to_c) + "-"+"-" + str(ks) + "--"+"UNKOWN"
#         parent_mass = ">parentmass " + str(f_mz)
#         parent_rt = ">rt " + str(f_rt)
#         comments = "##NativeID " + spec.getNativeID() + "\n"
#
#         charge_cmp = ">charge " + str(charge_f)
#
#         charge_f_mgf = "CHARGE=" + str(1 if charge_f == 0 else abs(charge_f)) + ("+" if polarity=="positive" else "-")
#         mz_f_mgf = "PEPMASS=" + str(f_mz)
#         rt_f_mgf = "RTINSECONDS=" + str(f_rt)
#         id_f_mgf = "FEATURE_ID=e_" + str(0)
#         level_f_mgf= "MSLEVEL=2"
#         scan_f_mgf = "SCANS=" + str(0)
#
#         ms1_merged = ""
#         if mz_trace!=0:
#           ms1_merged = ">ms1merged\n"
#           for i_iso in range(len(mz_trace)):
#             ms1_merged = ms1_merged + str(mz_trace[i_iso]) + " " + str(int_trace[i_iso]) + "\n"
#
#
#         ms2_peaks = spec.get_peaks()
#         ms1_peaks=pre_kh.get_peaks()
#         if len(ms2_peaks[0])>0:
#           empty_spectra=False
#           exist_one_spectra=True
#         else:
#           continue
#
#         collision = spec.getPrecursors()[0].getActivationEnergy()
#
#         ms1_ms2_peaks =  ">ms1peaks\n"
#         for ms_1_i in range(len(ms1_peaks[0])):
#           ms1_ms2_peaks = ms1_ms2_peaks + str(ms1_peaks[0][ms_1_i]) + " " + str(ms1_peaks[1][ms_1_i]) + "\n"
#         if collision == 0.0:
#           ms1_ms2_peaks = ms1_ms2_peaks+">ms2peaks\n"
#         else:
#           ms1_ms2_peaks = ms1_ms2_peaks+">collision"+" "+str(collision)+"\n"
#
#         ms2_all_peaks = ""
#         for ms_2_i in range(len(ms2_peaks[0])):
#           ms1_ms2_peaks = ms1_ms2_peaks + str(ms2_peaks[0][ms_2_i]) +" " + str(ms2_peaks[1][ms_2_i]) + "\n"
#           ms2_all_peaks = ms2_all_peaks+ str(ms2_peaks[0][ms_2_i]) +" " + str(ms2_peaks[1][ms_2_i]) + "\n"
#
#         comb_ms2 = compound_id + "\n" +parent_mass + "\n" + "\n" + charge_cmp + "\n" + parent_rt + "\n" +comments+"\n" + ms1_merged + "\n" +ms1_ms2_peaks
#
#         comb_ms2_mgf = "BEGIN IONS" + "\n" + "\n" +id_f_mgf + "\n" + level_f_mgf + "\n" + charge_f_mgf + "\n" +mz_f_mgf+"\n" + "FILE_INDEX="+str(ks) +"\n" + "FILE_NAME="+mzml_file_paths[ks]+"\n"+rt_f_mgf+"\n" +ms2_all_peaks
#
#         nl=f.write(comb_ms2)
#         nl2 = f_mgf.write(comb_ms2_mgf)
#   f.close()
#   f_mgf.close()
#

if exist_one_spectra == False:
    raise Exception("No MS2 peak were found in the data!")
