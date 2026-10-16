#!/usr/bin/env python

# Written by Payam Emami and Axel Walter and released under the MIT license.

import argparse

import pyopenms as py

parser = argparse.ArgumentParser(
    description="Output tsv file containing mz of all features"
)

# Add the arguments
parser.add_argument(
    "--input", type=str, help="the path to the input directory containing the TSV files"
)

parser.add_argument(
    "--output",
    type=str,
    help="the path to the input directory containing the TSV files",
)


args = parser.parse_args()

features = py.FeatureMap()
py.FeatureXMLFile().load(args.input, features)
with open(args.output, "a") as tsv_file:
    tsv_file.write("mz\n")
    tsv_file.writelines(str(features[i].getMZ()) + "\n" for i in range(features.size()))
