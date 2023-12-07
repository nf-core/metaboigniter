#!/usr/bin/env python


# Written by Payam Emami and Axel Walter and released under the MIT license.



import pandas as pd
import numpy as np
from pyopenms import *
import sys
import csv
import argparse


def cleanup(input_cmap, output_tsv):
    consensus_map = ConsensusMap()
    ConsensusXMLFile().load(input_cmap, consensus_map)
    df = consensus_map.get_df()
    for cf in consensus_map:
        if cf.metaValueExists("best ion"):
            df["adduct"] = [cf.getMetaValue("best ion") for cf in consensus_map]
            break
    df["feature_ids"] = [[handle.getUniqueId() for handle in cf.getFeatureList()] for cf in consensus_map]
    df = df.reset_index()
    df = df.drop(columns=["sequence"])
    df.to_csv(output_tsv, sep="\t", index=False)
    return df


def modify_tsv_column(input_file, output_file, old_column_name, new_column_name, new_position):
    """
    Modify a TSV file: Rename a column and change its position.

    :param input_file: Path to the input TSV file
    :param output_file: Path to the output TSV file
    :param old_column_name: Current name of the column to be changed
    :param new_column_name: New name for the column
    :param new_position: New position index for the column (0-based)
    """

    with open(input_file, "r", newline="", encoding="utf-8") as infile, open(
        output_file, "w", newline="", encoding="utf-8"
    ) as outfile:
        reader = csv.reader(infile, delimiter="\t")
        writer = csv.writer(outfile, delimiter="\t")

        headers = next(reader)

        # Check if old column name exists
        if old_column_name not in headers:
            raise ValueError(f"Column '{old_column_name}' not found in the TSV file.")

        # Rename the column
        old_position = headers.index(old_column_name)
        headers[old_position] = new_column_name

        # Move the column to the new position
        headers.insert(new_position, headers.pop(old_position))

        writer.writerow(headers)

        for row in reader:
            # Rearrange the row data based on new headers
            value_to_move = row.pop(old_position)
            value_to_move.replace("e_", "")
            row.insert(new_position, value_to_move)

            writer.writerow(row)


def main():
    # Create the parser
    parser = argparse.ArgumentParser(description="Output tsv files and fix identification columns")

    # Add the arguments
    parser.add_argument(
        "--input_consensus",
        metavar="input_dir",
        type=str,
        help="the path to the input directory containing the TSV files",
    )

    parser.add_argument("--sirius_id", type=str, help="tsv or csv")
    parser.add_argument("--finger_id", type=str, help="tsv or csv")
    parser.add_argument("--ms2query_id", type=str, help="tsv or csv")
    parser.add_argument("--sirius_file", type=str, help="tsv or csv")
    parser.add_argument("--finger_file", type=str, help="tsv or csv")
    parser.add_argument("--ms2query_file", type=str, help="tsv or csv")
    parser.add_argument("--output", type=str, help="the path to the final output TSV file")

    # Execute the parse_args() method
    args = parser.parse_args()

    if args.sirius_file:
        modify_tsv_column(args.sirius_file, args.sirius_id, "Feature_ID", "id", 0)

    if args.finger_file:
        modify_tsv_column(args.finger_file, args.finger_id, "Feature_ID", "id", 0)
    if args.ms2query_file:
        modify_tsv_column(args.ms2query_file, args.ms2query_id, "feature_id", "id", 0)

    cleanup(args.input_consensus, args.output)


if __name__ == "__main__":
    main()
