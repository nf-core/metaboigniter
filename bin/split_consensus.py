#!/usr/bin/env python


# Written by Payam Emami and Axel Walter and released under the MIT license.



import os
import numpy as np
import pandas as pd
import pyopenms as py
import argparse

parser = argparse.ArgumentParser(description="Mass Spectrometry Data Processing Tool")

parser.add_argument("--consensus_file_path", help="Path to consensus XML file")

parser.add_argument("--split_parts", type=float, default=20, help="PPM for mapping")


parser.add_argument("--output", default="./", help="Path to consensus XML file")

args = parser.parse_args()


consensus_file = py.ConsensusXMLFile()
consensus_map = py.ConsensusMap()
consensus_file.load(args.consensus_file_path, consensus_map)

ft_map = py.ConsensusMap(consensus_map)


features_per_part = consensus_map.size() // args.split_parts


ft_map.clear(False)
counted_features = 0
parts = 0
total_counts = 0
for i in range(consensus_map.size()):
    ft_map.push_back(consensus_map[i])
    counted_features += 1
    total_counts += 1
    if (consensus_map.size() - total_counts) < features_per_part and not total_counts == consensus_map.size():
        continue
    if counted_features >= features_per_part or total_counts == consensus_map.size():
        parts += 1
        file_name_output = os.path.join(
            args.output,
            os.path.basename(os.path.splitext(args.consensus_file_path)[0])
            + "_part"
            + str(parts)
            + os.path.splitext(args.consensus_file_path)[1],
        )
        consensus_file.store(file_name_output, ft_map)
        counted_features = 0
        print(ft_map.size())
        ft_map.clear(False)
