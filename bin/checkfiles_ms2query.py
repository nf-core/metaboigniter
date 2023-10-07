#!/usr/bin/env python

import argparse
from typing import List, Optional


# this has been copied from ms2query
def select_files_for_ms2query(file_names: List[str], files_to_select=None, tocheck="all"):
    """Selects the files needed for MS2Library based on their file extensions."""
    if tocheck == "all":
        dict_with_file_extensions = {
            "sqlite": ".sqlite",
            "s2v_model": ".model",
            "ms2ds_model": ".hdf5",
            "ms2query_model": ".onnx",
            "s2v_embeddings": "s2v_embeddings.pickle",
            "ms2ds_embeddings": "ms2ds_embeddings.pickle",
            "trainables_syn1neg": ".trainables.syn1neg.npy",
            "wv_vectors": ".wv.vectors.npy",
        }
    else:
        dict_with_file_extensions = {
            "s2v_model": ".model",
            "ms2ds_model": ".hdf5",
            "ms2query_model": ".onnx",
            "trainables_syn1neg": ".trainables.syn1neg.npy",
            "wv_vectors": ".wv.vectors.npy",
        }

    if files_to_select is not None:
        dict_with_file_extensions = {
            key: value for key, value in dict_with_file_extensions.items() if key in files_to_select
        }
    # Create a dictionary with None as values.
    dict_with_file_names = {key: None for key in dict_with_file_extensions}
    for file_name in file_names:
        # Loop over the different expected file extensions.
        for file_type, file_extension in dict_with_file_extensions.items():
            if str.endswith(file_name, file_extension):
                assert (
                    dict_with_file_names[file_type] is None
                ), f"Multiple files could be the file containing the {file_type} file"
                dict_with_file_names[file_type] = file_name
        # Check if the old ms2query model is stored (instead of onnx) to give a good warning.
        if str.endswith(file_name, ".pickle") and "ms2q" in file_name:
            file_type = "ms2query_model_pickle"
            dict_with_file_names[file_type] = file_name

    # Check if all the file types are available
    for file_type, stored_file_name in dict_with_file_names.items():
        if file_type == "ms2query_model" and stored_file_name is None:
            assert dict_with_file_names["ms2query_model_pickle"] is None, (
                "Only a MS2Query model in pickled format was found. The current version of MS2Query needs a .onnx format. "
                "To download the new format check the readme https://github.com/iomega/ms2query. "
                "Alternatively MS2Query can be downgraded to version <= 0.6.7"
            )
            assert False, "The MS2Query model was not found in the directory"
        elif file_type != "ms2query_model_pickle":
            assert (
                stored_file_name is not None
            ), f"The file type {file_type} was not found in the file names: {file_names}"
    return dict_with_file_names


parser = argparse.ArgumentParser(description="Select files for MS2Query")
parser.add_argument("files", nargs="+", help="The files to check.")
parser.add_argument("--select", nargs="*", help="The specific file types to select.")
args = parser.parse_args()
selected_files = select_files_for_ms2query(args.files, args.select)
