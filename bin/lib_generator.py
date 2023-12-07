#!/usr/bin/env python


# Written by Payam Emami and Axel Walter and released under the MIT license.



import pyopenms as po
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--input", help="input consensusXML file")
parser.add_argument("--output", help="output tsv file")
parser.add_argument("--polarity", choices=["positive", "negative"], help="polarity")

args = parser.parse_args()

cmap = po.ConsensusMap()
po.ConsensusXMLFile().load(args.input, cmap)

polarity = "+"
# set polarity
if args.polarity == "negative":
    polarity = "-"


cmap.sortBySize()
column_headers = [
    "CompoundName",
    "SumFormula",
    "Mass",
    "Charge",
    "RetentionTime",
    "RetentionTimeRange",
    "IsoDistribution",
]


def mz_to_mass(mz, charge, polarity):
    # Treat charge zero as one
    if charge == 0:
        charge = 1

    mass = (mz * charge) - (charge * polarity * 1.007825)
    return mass


i = 0
with open(args.output, "w") as f:
    f.write("\t".join(column_headers) + "\n")
    for cfeature in cmap:
        int_info = ["NA" for number in range(len(column_headers))]
        int_info[0] = "feature_" + str(i)
        int_info[1] = " "

        # set charge first
        charge = cfeature.getCharge()
        # set mass

        int_info[2] = str(mz_to_mass(cfeature.getMZ(), charge, int(polarity + "1")))
        if charge == 0:
            charge = 1
        int_info[3] = polarity + str(charge)
        int_info[4] = str(cfeature.getRT())

        int_info[5] = "0"
        int_info[6] = "0"
        i = i + 1
        f.write("\t".join(int_info) + "\n")
