#!/usr/bin/env python


# Written by Payam Emami and Axel Walter and released under the MIT license.



import argparse
import pandas as pd
import glob
import os


def adjust_indices_and_concatenate(input_dir, output_file, in_type, output_type):
    # Get a list of all TSV files in the input directory
    tsv_files = sorted(
        glob.glob(os.path.join(input_dir, "*." + in_type)),
        key=lambda x: int(x.split("_part")[-1].split(".")[0]) if "_part" in x else -1,
    )

    total_rows = 0
    all_data = []
    if in_type == "csv":
        separator_in = ","
    elif in_type == "tsv":
        separator_in = "\t"

    if output_type == "csv":
        separator_out = ","
    elif output_type == "tsv":
        separator_out = "\t"

    for tsv_file in tsv_files:
        df = pd.read_csv(tsv_file, sep=separator_in)

        # Adjust the indices
        df.index = df.index + total_rows + 1

        all_data.append(df)
        total_rows += df.shape[0]

    # Concatenate all dataframes
    result = pd.concat(all_data)

    # Write the final output file
    result.to_csv(output_file, sep=separator_out, index=False)


def main():
    # Create the parser
    parser = argparse.ArgumentParser(description="Adjust indices in TSV files and concatenate them.")

    # Add the arguments
    parser.add_argument(
        "--input_dir", metavar="input_dir", type=str, help="the path to the input directory containing the TSV files"
    )

    parser.add_argument("--input_type", type=str, help="tsv or csv")
    parser.add_argument("--output_type", type=str, help="tsv or csv")

    parser.add_argument("--output_file", metavar="output_file", type=str, help="the path to the final output TSV file")

    # Execute the parse_args() method
    args = parser.parse_args()

    adjust_indices_and_concatenate(args.input_dir, args.output_file, args.input_type, args.output_type)


if __name__ == "__main__":
    main()
