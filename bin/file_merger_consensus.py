#!/usr/bin/env python

# Written by Payam Emami and Axel Walter and released under the MIT license.

import pyopenms as py
import argparse
import os

parser = argparse.ArgumentParser(description="merge consensusXML files")

parser.add_argument("--input", nargs="+", help="List of consensusXML file paths")

parser.add_argument("--output", type=str, help="the path to the output dir")


args = parser.parse_args()
inputs = args.input
cns_map = py.ConsensusMap()
py.ConsensusXMLFile().load(inputs[0], cns_map)
cns_map.clear(False)
empty_protein_id = py.ProteinIdentification()

empty_protein_id.setIdentifier("UNKNOWN_SEARCH_RUN_IDENTIFIER")
cns_map.setProteinIdentifications([empty_protein_id])


for i in range(len(inputs)):
    cns_map_tmp = py.ConsensusMap()
    py.ConsensusXMLFile().load(inputs[i], cns_map_tmp)
    for x in range(cns_map_tmp.size()):
        cnf_feature = cns_map_tmp[x]
        peptides = cnf_feature.getPeptideIdentifications()
        for j in range(len(peptides)):
            peptides[j].setIdentifier(empty_protein_id.getIdentifier())
        cnf_feature.setPeptideIdentifications(peptides)
        cns_map.push_back(cnf_feature)


py.ConsensusXMLFile().store(args.output, cns_map)
