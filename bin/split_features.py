#!/usr/bin/env python
import pyopenms as py
import argparse
import os

parser = argparse.ArgumentParser(description="Output tsv file containing mz of all features")

# Add the arguments
parser.add_argument("--input", type=str, help="the path to the input featureXML")

parser.add_argument("--input_boundries", type=str, help="the path to the input TSV feature boundries")


parser.add_argument("--output", type=str, help="the path to the output dir")


partition_boundaries = []

args = parser.parse_args()


with open(args.input_boundries) as f:
    next(f)
    for line in f:
        partition_boundaries.append(float(line))


features = py.FeatureMap()
py.FeatureXMLFile().load(args.input, features)

features_output = py.FeatureMap(features)
features_output.clear(False)
features_output.setProteinIdentifications(features.getProteinIdentifications())
feature_part_index = 0
for j in range(len(partition_boundaries) - 1):
    partition_start = partition_boundaries[j]
    partition_end = partition_boundaries[j + 1]
    for m in range(features.size()):
        if features[m].getMZ() >= partition_start and features[m].getMZ() < partition_end:
            features_output.push_back(features[m])
    features_output.updateRanges()
    output_path = os.path.join(
        args.output,
        os.path.splitext(os.path.basename(args.input))[0]
        + "_part"
        + str(feature_part_index)
        + os.path.splitext(os.path.basename(args.input))[1],
    )
    py.FeatureXMLFile().store(output_path, features_output)
    features_output.clear(False)
    feature_part_index += 1
