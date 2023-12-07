#!/usr/bin/env python

# Written by Payam Emami and Axel Walter and released under the MIT license.

import os
import pyopenms as py
import argparse

parser = argparse.ArgumentParser(description="Maps MS2 to consensusXML including names")

parser.add_argument("--consensus_input", type=str, help="The path to the consensus file")
parser.add_argument("--mzml_file_paths", type=str, nargs="+", help="The paths to the mzML files")
parser.add_argument("--output", type=str, help="The path for output")
parser.add_argument("--rt_tolerance", type=float, help="The retention time tolerance")
parser.add_argument("--mz_tolerance", type=float, help="The m/z tolerance")
parser.add_argument("--annotate_ids_with_subelements", action="store_true", help="Annotate IDs with sub-elements")
parser.add_argument("--measure_from_subelements", action="store_true", help="Measure from sub-elements")


# Parse the arguments
args = parser.parse_args()

# Now you can access your arguments as follows:
consensus_input = args.consensus_input
mzml_file_paths = args.mzml_file_paths
output = args.output
mz_tolerance = args.mz_tolerance
rt_tolerance = args.rt_tolerance
annotate_ids_with_subelements = args.annotate_ids_with_subelements
measure_from_subelements = args.measure_from_subelements


protein_ids = []
peptide_ids = []

mapper = py.IDMapper()


parameters = mapper.getParameters()
parameters.setValue("rt_tolerance", rt_tolerance)
parameters.setValue("mz_tolerance", mz_tolerance)

mapper.setParameters(parameters)

consensus_file = py.ConsensusXMLFile()
consensus_map = py.ConsensusMap()
consensus_file.load(consensus_input, consensus_map)


for i in range(len(mzml_file_paths)):
    id_input = mzml_file_paths[i]
    exp = py.MSExperiment()
    py.MzMLFile().load(id_input, exp)
    mapper.annotate(
        consensus_map, peptide_ids, protein_ids, measure_from_subelements, annotate_ids_with_subelements, exp
    )
    id_name = os.path.basename(id_input)
    for cons_i in range(consensus_map.size()):
        feature = consensus_map[cons_i]
        feature_pepts = feature.getPeptideIdentifications()
        mod_peptides = []
        for pept_id in feature_pepts:
            if pept_id.metaValueExists("spectrum_index"):
                if pept_id.metaValueExists("id_file") == False:
                    pept_id.setMetaValue("id_file", os.path.basename(id_input))
                    pept_id.setMetaValue("id_file_index", i)
            mod_peptides.append(pept_id)
        feature.setPeptideIdentifications(mod_peptides)
        consensus_map[cons_i] = feature


consensus_file.store(output, consensus_map)
