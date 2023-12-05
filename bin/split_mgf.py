#!/usr/bin/env python
import argparse
import os
from pyopenms import MSExperiment, MzMLFile, MascotGenericFile


def split_file(input_file, num_parts, output_dir, input_type):
    with open(input_file, "r") as file:
        content = file.read()

    # Check if it's an MGF or MS file
    if input_type == "mgf":
        spectra = content.split("BEGIN IONS")
        metadata = spectra[0]
        spectra = spectra[1:]
        delimiter = "BEGIN IONS"
    elif input_type == "ms":
        spectra = content.split(">compound")
        metadata = ""
        spectra = [spec for spec in spectra if spec.strip()]
        delimiter = ">compound"
    else:
        raise ValueError("Unsupported file format. Only .mgf and .ms are supported.")

    if num_parts >= len(spectra):
        num_parts = len(spectra)
    spectra_per_file = len(spectra) // num_parts

    extension = os.path.splitext(input_file)[1]
    base_name = os.path.basename(input_file).split(".")[0]

    for i in range(num_parts):
        start = i * spectra_per_file
        end = (i + 1) * spectra_per_file if i != num_parts - 1 else None

        with open(os.path.join(output_dir, f"{base_name}_part{i+1}{extension}"), "w") as file:
            file.write(metadata)
            file.write(delimiter + delimiter.join(spectra[start:end]))


def main():
    # Create the parser
    parser = argparse.ArgumentParser(description="Split an MGF file into several parts.")

    # Add the arguments
    parser.add_argument("--mgf_file", metavar="mgf_file", type=str, help="the path to the MGF file to split")

    parser.add_argument("--file_type", type=str, help="type of the file")

    parser.add_argument(
        "--num_parts", metavar="num_parts", type=int, help="the number of parts to split the MGF file into"
    )

    parser.add_argument("--output", metavar="output", type=str, default=".", help="the path to the output directory")

    # Execute the parse_args() method
    args = parser.parse_args()

    split_file(args.mgf_file, args.num_parts, args.output, args.file_type)


if __name__ == "__main__":
    main()
