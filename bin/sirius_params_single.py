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


parser.add_argument("--mzml_file_path", help="List of mzML file paths")
parser.add_argument("--input_csv", help="List of mzML file paths")
parser.add_argument("--iterations", type=float, default=3, help="Number of iterations")
parser.add_argument("--ppm_map", type=float, default=20, help="PPM for mapping")
parser.add_argument("--polarity", choices=["positive", "negative"], default="positive", help="Polarity of the data")

parser.add_argument("--ms_output", help="Path to msfile")


parser.add_argument("--mgf_output", help="Path to mgf file")


args = parser.parse_args()


mzml_file_paths = [args.mzml_file_path]


output = args.ms_output
output_mgf = args.mgf_output
input_csv = args.input_csv


iterations = args.iterations
ppm_map = args.ppm_map

polarity = args.polarity


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


specs_list = [py.OnDiscMSExperiment() for _ in range(len(mzml_file_paths))]

for map_index in range(len(mzml_file_paths)):
    specs_list[map_index].openFile(mzml_file_paths[map_index], False)


map_index_rm = {path: [] for path in mzml_file_paths}


with open(input_csv, "r") as file:
    next(file)
    values = [int(line.strip()) for line in file]

map_index_rm[mzml_file_paths[0]] = values


## there exist spectra
exist_one_spectra = False


for ks in range(len(map_index_rm)):
    if len(set(map_index_rm[list(map_index_rm.keys())[ks]])) >= specs_list[ks].getNrSpectra():
        continue
    f = open(output, "w")
    f_mgf = open(output_mgf, "w")

    comb_ms2 = ""
    for i in range(specs_list[ks].getNrSpectra()):
        if map_index_rm[list(map_index_rm.keys())[ks]].count(i) == 0:
            spec = specs_list[ks].getSpectrum(i)
            spectra = specs_list[ks].getMetaData()

            # ainfo_sf_path = spectra.getSourceFiles()[0].getPathToFile();
            # ainfo_sf_filename = spectra.getSourceFiles()[0].getNameOfFile();
            # ainfo_sf_type = spectra.getSourceFiles()[0].getFileType();
            #
            # ainfo_native_id_accession = spectra.getSourceFiles()[0].getNativeIDTypeAccession();
            # ainfo_native_id_type = spectra.getSourceFiles()[0].getNativeIDType();

            if spec.getMSLevel() == 2:
                pre_kh = getPrecursorSpectrum(i, specs_list[ks], use_rt=False, rt=spec.getRT(), only_rt=False)
                precursor_mz = spec.getPrecursors()[0].getMZ()
                precursor_spectrum = pd.DataFrame(pre_kh.get_peaks()).T
                precursor_spectrum.columns = ["mz", "intensity"]
                charge_f = spec.getPrecursors()[0].getCharge()
                if polarity == "positive" and charge_f == 0:
                    charge_f = 1
                elif polarity == "negative" and charge_f == 0:
                    charge_f = -1

                iso = extract_precursor_isotope_pattern(precursor_mz, precursor_spectrum, iterations, charge_f, ppm_map)

                f_rt = pre_kh.getRT()
                f_mz = precursor_mz

                native_id = spec.getNativeID()
                # scan_number = py.SpectrumLookup().extractScanNumber(native_id, ainfo_native_id_accession);

                mz_trace = 0
                if len(iso) > 0:
                    mz_trace = iso["mz"].to_list()
                    int_trace = iso["intensity"].to_list()
                    f_mz = list(iso["mz"])[0]

                id_to_c = py.SpectrumLookup().extractScanNumber(
                    spec.getNativeID(), specs_list[ks].getMetaData().getSourceFiles()[0].getNativeIDTypeAccession()
                )
                compound_id = ">compound " + "_" + str(0) + "-" + str(id_to_c) + "-" + "-" + str(ks) + "--" + "UNKOWN"
                parent_mass = ">parentmass " + str(f_mz)
                parent_rt = ">rt " + str(f_rt)
                comments = "##NativeID " + spec.getNativeID() + "\n"

                charge_cmp = ">charge " + str(charge_f)

                charge_f_mgf = (
                    "CHARGE=" + str(1 if charge_f == 0 else abs(charge_f)) + ("+" if polarity == "positive" else "-")
                )
                mz_f_mgf = "PEPMASS=" + str(f_mz)
                rt_f_mgf = "RTINSECONDS=" + str(f_rt)
                id_f_mgf = "FEATURE_ID=e_" + str(0)
                level_f_mgf = "MSLEVEL=2"
                scan_f_mgf = "SCANS=" + str(0)

                ms1_merged = ""
                if mz_trace != 0:
                    ms1_merged = ">ms1merged\n"
                    for i_iso in range(len(mz_trace)):
                        ms1_merged = ms1_merged + str(mz_trace[i_iso]) + " " + str(int_trace[i_iso]) + "\n"

                ms2_peaks = spec.get_peaks()
                ms1_peaks = pre_kh.get_peaks()
                if len(ms2_peaks[0]) > 0:
                    empty_spectra = False
                    exist_one_spectra = True
                else:
                    continue

                collision = spec.getPrecursors()[0].getActivationEnergy()

                ms1_ms2_peaks = ">ms1peaks\n"
                for ms_1_i in range(len(ms1_peaks[0])):
                    ms1_ms2_peaks = ms1_ms2_peaks + str(ms1_peaks[0][ms_1_i]) + " " + str(ms1_peaks[1][ms_1_i]) + "\n"
                if collision == 0.0:
                    ms1_ms2_peaks = ms1_ms2_peaks + ">ms2peaks\n"
                else:
                    ms1_ms2_peaks = ms1_ms2_peaks + ">collision" + " " + str(collision) + "\n"

                ms2_all_peaks = ""
                for ms_2_i in range(len(ms2_peaks[0])):
                    ms1_ms2_peaks = ms1_ms2_peaks + str(ms2_peaks[0][ms_2_i]) + " " + str(ms2_peaks[1][ms_2_i]) + "\n"
                    ms2_all_peaks = ms2_all_peaks + str(ms2_peaks[0][ms_2_i]) + " " + str(ms2_peaks[1][ms_2_i]) + "\n"

                comb_ms2 = (
                    compound_id
                    + "\n"
                    + parent_mass
                    + "\n"
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

                comb_ms2_mgf = (
                    "BEGIN IONS"
                    + "\n"
                    + "\n"
                    + id_f_mgf
                    + "\n"
                    + level_f_mgf
                    + "\n"
                    + charge_f_mgf
                    + "\n"
                    + mz_f_mgf
                    + "\n"
                    + "FILE_INDEX="
                    + str(ks)
                    + "\n"
                    + "FILE_NAME="
                    + mzml_file_paths[ks]
                    + "\n"
                    + rt_f_mgf
                    + "\n"
                    + ms2_all_peaks
                    + "\n"
                    + "END IONS"
                    + "\n"
                )

                nl = f.write(comb_ms2)
                nl2 = f_mgf.write(comb_ms2_mgf)
    f.close()
    f_mgf.close()


if exist_one_spectra == False:
    raise Exception("No MS2 peak were found in the data!")
