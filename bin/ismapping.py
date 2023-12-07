#!/usr/bin/env python


# Written by Payam Emami and Axel Walter and released under the MIT license.



import os
import pyopenms as py
import argparse

parser = argparse.ArgumentParser(description="Maps MS2 to consensusXML including names")

parser.add_argument("--consensus_input", type=str, help="The path to the consensus file")
parser.add_argument("--featurexml", type=str, nargs="+", help="The paths to the mzML files")
parser.add_argument("--output", type=str, help="The path for output")


# Parse the arguments
args = parser.parse_args()

# Now you can access your arguments as follows:
consensus_input = args.consensus_input
featurexml = args.featurexml
output = args.output


consensus_file = py.ConsensusXMLFile()
consensus_map = py.ConsensusMap()
consensus_file.load(consensus_input, consensus_map)


for i in range(len(featurexml)):
    id_input = featurexml[i]
    print(id_input)
    fm = py.FeatureMap()
    py.FeatureXMLFile().load(id_input, fm)
    id_name = os.path.basename(id_input)
    for cons_i in range(consensus_map.size()):
        feature = consensus_map[cons_i]
        feature_pepts = feature.getPeptideIdentifications()
        if len(feature_pepts) == 0:
            continue

        list_of_features = feature.getFeatureList()

        sel_ftr = 0
        for ftr in list_of_features:
            if ftr.getMapIndex() == i:
                sel_ftr = ftr
                break

        if isinstance(sel_ftr, int) and sel_ftr == 0:
            continue

        selected_feature = 0
        for ftr_s in fm:
            if ftr_s.getUniqueId() == sel_ftr.getUniqueId():
                selected_feature = ftr_s
                break

        if isinstance(selected_feature, int) and selected_feature == 0:
            continue

        qual = selected_feature.getOverallQuality()
        isotope_int = selected_feature.getMetaValue("masstrace_intensity")
        isotope_mz = selected_feature.getMetaValue("masstrace_centroid_mz")

        if feature.metaValueExists("best_feature_quality"):
            print(str(i) + "--" + str(qual) + "--" + str(feature.getMetaValue("best_feature_quality")))
            if qual > feature.getMetaValue("best_feature_quality"):
                feature.setMetaValue("top_feature_iso_int", isotope_int)
                feature.setMetaValue("top_feature_iso_mz", isotope_mz)
                feature.setMetaValue("top_feature_map_id", i)
                feature.setMetaValue("best_feature_quality", qual)
                feature.setMetaValue("best_feature_file", id_name)
            else:
                continue
        else:
            feature.setMetaValue("top_feature_iso_int", isotope_int)
            feature.setMetaValue("top_feature_iso_mz", isotope_mz)
            feature.setMetaValue("top_feature_map_id", i)
            feature.setMetaValue("best_feature_quality", qual)
            feature.setMetaValue("best_feature_file", id_name)
        consensus_map[cons_i] = feature

consensus_file.store(output, consensus_map)
