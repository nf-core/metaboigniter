#!/usr/bin/env python3

# Written by Payam Emami and Axel Walter and released under the MIT license.

import argparse
import subprocess
import os

parser = argparse.ArgumentParser()

parser.add_argument("--input", type=str, required=False, help="Path to the ms file.")
parser.add_argument("--output", type=str, default="sirius.tsv", required=False, help="Path to the mztab file.")
parser.add_argument("--outputfid", type=str, default="fingerid.tsv", required=False, help="Path to the mztab file.")
parser.add_argument("--prfolder", type=str, default="./output", required=False, help="Path to the mztab file.")

parser.add_argument(
    "--project_maxmz",
    type=float,
    default=-1,
    help="Just consider compounds with a precursor mz lower or equal this maximum mz. "
    "All other compounds in the input file are ignored.",
)
parser.add_argument(
    "--project_processors",
    type=int,
    default=1,
    help="Number of cpu cores to use. If not specified SIRIUS uses all available cores.",
)
parser.add_argument(
    "--project_loglevel",
    type=str,
    default="WARNING",
    choices=["SEVERE", "WARNING", "INFO", "FINER", "ALL"],
    help="Set logging level of the Jobs SIRIUS will execute.",
)
parser.add_argument(
    "--project_ignore-formula",
    action="store_true",
    help="Ignore given molecular formula in internal .ms format, while processing.",
)


parser.add_argument(
    "--sirius_ppm-max",
    type=float,
    default=10.0,
    help="Maximum allowed mass deviation in ppm for decomposing masses [ppm].",
)
parser.add_argument(
    "--sirius_ppm-max-ms2",
    type=float,
    default=10.0,
    help="Maximum allowed mass deviation in ppm for decomposing masses in MS2 [ppm].",
)
parser.add_argument(
    "--sirius_tree-timeout", type=int, default=100, help="Time out in seconds per fragmentation tree computations."
)
parser.add_argument(
    "--sirius_compound-timeout",
    type=int,
    default=100,
    help="Maximal computation time in seconds for a single compound.",
)
parser.add_argument("--sirius_no-recalibration", action="store_true", help="Disable recalibration of input spectra")
parser.add_argument(
    "--sirius_profile",
    type=str,
    default="default",
    choices=["default", "qtof", "orbitrap", "fticr"],
    help="Name of the configuration profile.",
)
parser.add_argument(
    "--sirius_formulas",
    type=str,
    default="",
    help="Specify the neutral molecular formula or a list of candidate formulas.",
)
parser.add_argument(
    "--sirius_ions-enforced",
    type=str,
    default="",
    help="The iontype/adduct of the MS/MS data. Comma separated list of adducts.",
)
parser.add_argument(
    "--sirius_candidates", type=int, default=10, help="The number of formula candidates in the SIRIUS output."
)
parser.add_argument(
    "--sirius_candidates-per-ion",
    type=int,
    default=1,
    help="Minimum number of candidates in the output for each ionization.",
)
parser.add_argument(
    "--sirius_elements-considered",
    type=str,
    default="SBrClBSe",
    help="Set the allowed elements for rare element detection.",
)
parser.add_argument(
    "--sirius_elements-enforced",
    type=str,
    default="CHNOP",
    help="Enforce elements for molecular formula determination.",
)
parser.add_argument("--sirius_no-isotope-score", action="store_true", help="Disable isotope pattern score.")
parser.add_argument("--sirius_no-isotope-filter", action="store_true", help="Disable molecular formula filter.")
parser.add_argument(
    "--sirius_ions-considered",
    type=str,
    default="[M+H]+,[M+K]+,[M+Na]+,[M+H-H2O]+,[M+H-H4O2]+,[M+NH4]+,[M-H]-,[M+Cl]-,[M-H2O-H]-,[M+Br]-",
    help="The iontype/adduct of the MS/MS data. You can also provide a comma separated list of adducts.",
)
parser.add_argument(
    "--sirius_db",
    type=str,
    help="""Search formulas in the Union of the given databases.db-name1,db-name2,db-name3.
                    If no database is given all possible molecular formulas will be respected (no database is used).
                    Example: possible DBs: ALL,BIO,PUBCHEM,MESH,HMDB,
                    KNAPSACK,CHEBI,PUBMED,KEGG,HSDB,MACONDA,METACYC,
                    GNPS,ZINCBIO,UNDP,YMDB,PLANTCYC,NORMAN,ADDITIONAL,
                    PUBCHEMANNOTATIONBIO,PUBCHEMANNOTATIONDRUG,
                    PUBCHEMANNOTATIONSAFETYANDTOXIC,
                    PUBCHEMANNOTATIONFOOD,KEGGMINE,ECOCYCMINE,YMDBMINE""",
)


parser.add_argument("--runfid", action="store_true", help="run fingerid")
parser.add_argument("--runpassatutto", action="store_true", help="run passatutto")

parser.add_argument(
    "--fingerid_db",
    type=str,
    help="Search structures in the Union of the given databases db-name1,db-name2,db-name3. "
    "If no database is given all possible molecular formulas will be respected (no database "
    "is used). Example: possible DBs: ALL,BIO,PUBCHEM,MESH,HMDB,KNAPSACK,CHEBI,PUBMED,KEGG,"
    "HSDB,MACONDA,METACYC,GNPS,ZINCBIO,UNDP,YMDB,PLANTCYC,NORMAN,ADDITIONAL,"
    "PUBCHEMANNOTATIONBIO,PUBCHEMANNOTATIONDRUG,PUBCHEMANNOTATIONSAFETYANDTOXIC,"
    "PUBCHEMANNOTATIONFOOD,KEGGMINE,ECOCYCMINE,YMDBMINE",
)

parser.add_argument("--sirius_solver", type=str, default="CLP", help="Solver option for SIRIUS.")

parser.add_argument("--email", type=str, default="", required=False, help="User email.")
parser.add_argument("--password", type=str, default="", required=False, help="User password.")
parser.add_argument("--executable", type=str, default="sirius", required=False, help="User password.")


args = parser.parse_args()


## login first

if args.email and args.password:
    command_line = [args.executable, "login", "--email=" + args.email, "--password=" + args.password]
    result = subprocess.run(command_line, capture_output=False, text=True)
    if result.returncode != 0:
        print(result.stderr)


##
dics_of_args = vars(args)
command_line = [args.executable, "--noCite"]

for key, value in dics_of_args.items():
    if key.split("_")[0] == "project":
        if isinstance(value, bool):
            print(key)

for key, value in dics_of_args.items():
    if key.split("_")[0] == "project":
        if value != parser.get_default(key):
            command_line.append("--" + key.replace("project_", "").replace("_", "-"))
            if not isinstance(value, bool):
                command_line.append(str(value))

command_line.append("--input")

command_line.append(str(args.input))

command_line.append("--project")

command_line.append(args.prfolder)
command_line.append("--no-compression")
command_line.append("sirius")


for key, value in dics_of_args.items():
    if key.split("_")[0] == "sirius":
        if value != parser.get_default(key):
            command_line.append("--" + key.replace("sirius_", "").replace("_", "-"))
            if not isinstance(value, bool):
                command_line.append(str(value))


if args.runpassatutto:
    command_line.append("passatutto")

if args.runfid:
    command_line.append("fingerprint")
    command_line.append("structure")


for key, value in dics_of_args.items():
    if key.split("_")[0] == "fingerid":
        if value != parser.get_default(key):
            command_line.append("--" + key.replace("fingerid_", "").replace("_", "-"))
            if not isinstance(value, bool):
                command_line.append(str(value))

command_line.append("write-summaries")

result = subprocess.run(command_line, capture_output=False, text=True)

if result.returncode != 0:
    print(result.stderr)


def list_directories(path):
    return [d for d in os.listdir(path) if os.path.isdir(os.path.join(path, d))]


output_dirs = list_directories(args.prfolder)


output_dirs.sort()


class SiriusSpectrumMSInfo:
    def __init__(self):
        self.ext_mz = None
        self.ext_rt = None
        self.ext_n_id = []


def extractSpectrumMSInfo(single_sirius_path):
    info = SiriusSpectrumMSInfo()

    sirius_spectrum_ms = os.path.join(single_sirius_path, "spectrum.ms")

    if os.path.exists(sirius_spectrum_ms):
        with open(sirius_spectrum_ms, "r") as file:
            lines = file.readlines()
            for line in lines:
                if line.startswith(">parentmass"):
                    info.ext_mz = float(line.replace(">parentmass", "").strip())
                elif line.startswith(">rt"):
                    line = line.replace("s", "").replace(">rt", "").strip()  # Removing "s" and ">rt" prefixes
                    info.ext_rt = float(line)
                elif line.startswith("##best_feature_id"):
                    info.ext_n_id.append(line.replace("##best_feature_id", "").strip())
        return info
    else:
        raise FileNotFoundError(f"File not found: {sirius_spectrum_ms}")


all_lines = []
for target in output_dirs:
    parts = target.split("_")[-1].split("-")
    feature_id = parts[0]
    scan_index = parts[1]
    scan_id = parts[3]
    full_path = os.path.join(args.prfolder, target, "formula_candidates.tsv")
    folder_path = os.path.join(args.prfolder, target)
    spc = extractSpectrumMSInfo(folder_path)
    if os.path.exists(full_path):
        with open(full_path, "r") as f:
            lines = f.readlines()

            # Modifying the header only once
            if not all_lines:
                # Add the new column headers for the first file
                header = "Feature_ID\tScan_Index\tScan_ID\tSpectra_RT\tSpectra_mz\tBest_Feature_ID\t" + lines[0]
                all_lines.append(header)

            corrected_lines = [line if line.endswith("\n") else line + "\n" for line in lines]
            # Process and append the data rows with the new columns
            for line in corrected_lines[1:]:
                new_line = f"{feature_id}\t{scan_index}\t{scan_id}\t{spc.ext_rt}\t{spc.ext_mz}\t{spc.ext_n_id}\t{line}"
                all_lines.append(new_line)
if len(all_lines) > 0:
    with open(args.output, "w") as out_file:
        out_file.writelines(all_lines)
else:
    print("No metabolite were detected")

all_lines = []
if args.runfid:
    for target in output_dirs:
        parts = target.split("_")[-1].split("-")
        feature_id = parts[0]
        scan_index = parts[1]
        scan_id = parts[3]
        full_path = os.path.join(args.prfolder, target, "structure_candidates.tsv")
        folder_path = os.path.join(args.prfolder, target)
        spc = extractSpectrumMSInfo(folder_path)
        if os.path.exists(full_path):
            with open(full_path, "r") as f:
                lines = f.readlines()

                # Modifying the header only once
                if not all_lines:
                    # Add the new column headers for the first file
                    header = "Feature_ID\tScan_Index\tScan_ID\tSpectra_RT\tSpectra_mz\tBest_Feature_ID\t" + lines[0]
                    all_lines.append(header)
                corrected_lines = [line if line.endswith("\n") else line + "\n" for line in lines]
                # Process and append the data rows with the new columns
                for line in corrected_lines[1:]:
                    new_line = (
                        f"{feature_id}\t{scan_index}\t{scan_id}\t{spc.ext_rt}\t{spc.ext_mz}\t{spc.ext_n_id}\t{line}"
                    )
                    all_lines.append(new_line)
    if len(all_lines) > 0:
        with open(args.outputfid, "w") as out_file:
            out_file.writelines(all_lines)
    else:
        print("No metabolite were detected")
