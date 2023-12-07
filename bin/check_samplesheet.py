#!/usr/bin/env python


# Written by Payam Emami and Axel Walter and released under the MIT license.


import pandas as pd
import os
import argparse
import sys


def validate_csv(file_path):
    # Load the csv file into a pandas DataFrame
    df = pd.read_csv(file_path)

    # 1. Check the headers
    required_headers = ["sample", "level", "type", "msfile"]
    if not set(required_headers).issubset(df.columns):
        print("The CSV file does not contain the required headers: sample, level, type, msfile.")
        return None

    # 2. Check the level column
    valid_levels = ["MS1", "MS2", "MS12"]
    if not df["level"].isin(valid_levels).all():
        print("The 'level' column contains invalid values. Accepted values are: MS1, MS2, MS12.")
        return None

    # 3. Check the sample column for duplicates
    if df["sample"].duplicated().any():
        print("The 'sample' column contains duplicated values.")
        return None

    # 4. Check the msfile column for correct format and no duplicates in basename
    if not df["msfile"].apply(lambda x: x.endswith(".mzML")).all():
        print("The 'msfile' column contains file names not ending with '.mzML'.")
        return None

    if df["msfile"].apply(lambda x: os.path.basename(x)).duplicated().any():
        print("The 'msfile' column contains duplicated base file names.")
        return None

    print("CSV file is valid.")
    return df


def main():
    # Parse the command-line arguments
    parser = argparse.ArgumentParser(description="Validate CSV file.")
    parser.add_argument("csvfile", help="Path to the CSV file to validate.")
    parser.add_argument("csvfile_out", help="Path to the CSV file to output.")
    args = parser.parse_args()

    # Validate the CSV file
    df = validate_csv(args.csvfile)

    # If the CSV is valid, print it
    if df is not None:
        df.to_csv(args.csvfile_out, encoding="utf-8", index=False)


if __name__ == "__main__":
    main()
