#!/usr/bin/env python
import argparse
from os.path import join
from ms2query.create_new_library.library_files_creator import LibraryFilesCreator
from ms2query.clean_and_filter_spectra import clean_normalize_and_split_annotated_spectra
from ms2query.utils import load_matchms_spectrum_objects_from_file, select_files_in_directory
from ms2query.run_ms2query import download_zenodo_files
from ms2query.ms2library import select_files_for_ms2query

parser = argparse.ArgumentParser()
parser.add_argument("--input", help="input mgf library file")
parser.add_argument("--output", help="output dir")
parser.add_argument("--polarity", choices=["positive", "negative"], help="polarity")
parser.add_argument("--model", help="input model dir")
args = parser.parse_args()

spectrum_file_location = args.input
ionisation_mode = args.polarity
directory_for_library_and_models = args.model

# Downloads the models:
library_spectra = load_matchms_spectrum_objects_from_file(spectrum_file_location)

files_in_directory = select_files_in_directory(directory_for_library_and_models)
dict_with_file_names = select_files_for_ms2query(files_in_directory, ["s2v_model", "ms2ds_model", "ms2query_model"])
ms2ds_model_file_name = dict_with_file_names["ms2ds_model"]
s2v_model_file_name = dict_with_file_names["s2v_model"]
ms2query_model = dict_with_file_names["ms2query_model"]

cleaned_library_spectra = clean_normalize_and_split_annotated_spectra(
    library_spectra, ion_mode_to_keep=ionisation_mode
)[0]

print("test1")
library_creator = LibraryFilesCreator(
    cleaned_library_spectra,
    output_directory=args.output,
    ms2ds_model_file_name=join(directory_for_library_and_models, ms2ds_model_file_name),
    s2v_model_file_name=join(directory_for_library_and_models, s2v_model_file_name),
)

print("test2")

library_creator.create_all_library_files()
