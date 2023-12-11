#!/usr/bin/env python

# Written by Payam Emami and Axel Walter and released under the MIT license.

import pyopenms as py
import re
import numpy as np


import argparse

# Create the parser
parser = argparse.ArgumentParser(description="Removes duplicated MS2s from consensus file")

# Add the arguments
parser.add_argument("--consensus_file_path", type=str, help="The path to the consensus file")
parser.add_argument("--mzml_file_paths", type=str, nargs="+", help="The paths to the mzML files")
parser.add_argument("--output", type=str, help="The path for output")

# Parse the arguments
args = parser.parse_args()

# Now you can access your arguments as follows:
consensus_file_path = args.consensus_file_path
mzml_file_paths = args.mzml_file_paths
output = args.output


consensus_file = py.ConsensusXMLFile()
consensus_map = py.ConsensusMap()
consensus_file.load(consensus_file_path, consensus_map)

specs_list = [py.OnDiscMSExperiment() for _ in range(len(mzml_file_paths))]

for map_index in range(len(mzml_file_paths)):
    specs_list[map_index].openFile(mzml_file_paths[map_index], False)


for cons_i in range(consensus_map.size()):
    feature = consensus_map[cons_i]
    feature_pepts = feature.getPeptideIdentifications()
    all_file_names = []
    all_spec_ids = []
    for pept_id in feature_pepts:
        if pept_id.metaValueExists("spectrum_index") and pept_id.metaValueExists("map_index"):
            map_index = pept_id.getMetaValue("map_index")
            spec_index = pept_id.getMetaValue("spectrum_index")
            kk = specs_list[map_index].getSpectrum(spec_index)
            filename = re.search(r'File:"(.*?)"', kk.getMetaValue("spectrum title")).group(1)
            scan_number = re.search(r"scan=(\d+)", kk.getMetaValue("spectrum title")).group(1)
            all_file_names.append(kk.getMetaValue("spectrum title"))
            all_spec_ids.append(scan_number)
    subset_dict = dict(zip(all_file_names, feature_pepts))
    subset = list(subset_dict.values())
    feature.setPeptideIdentifications(subset)
    consensus_map[cons_i] = feature


consensus_file.store(output, consensus_map)
