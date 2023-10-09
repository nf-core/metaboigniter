#!/usr/bin/env python
import pyopenms as py
import argparse

parser = argparse.ArgumentParser(description="Output tsv file containing mz of all features")

# Add the arguments
parser.add_argument("--input", type=str, help="the path to the input directory containing the TSV files")

parser.add_argument("--nr_partitions", default=100, type=int, help="number of partitions")

parser.add_argument("--mz_tol", type=float, default=10, help="mztol")

parser.add_argument("--mz_tol_wrap", type=float, default=5, help="mz_tol_wrap")


parser.add_argument("--mz_unit", type=str, default="ppm", help="mz_unit")  # Da


parser.add_argument("--output", type=str, help="the path to the input directory containing the TSV files")


massrange = []

args = parser.parse_args()


with open(args.input) as f:
    next(f)
    for line in f:
        massrange.append(float(line))

massrange.sort()

max_mz_tol = max(args.mz_tol, args.mz_tol_wrap)

pts_per_partition = len(massrange) / args.nr_partitions

mz_ppm_ = args.mz_unit == "ppm"

partition_boundaries = []
partition_boundaries.append(massrange[0])

for j in range(len(massrange) - 1):
    # minimal differences between two m/z values
    massrange_diff = max_mz_tol * 1e-6 * massrange[j + 1] if mz_ppm_ else max_mz_tol

    if abs(massrange[j] - massrange[j + 1]) > massrange_diff:
        if j >= len(partition_boundaries) * pts_per_partition:
            partition_boundaries.append((massrange[j] + massrange[j + 1]) / 2.0)

# add last partition (a bit more since we use "smaller than" below)
partition_boundaries.append(massrange[-1] + 1.0)

with open(args.output, "a") as tsv_file:
    tsv_file.write("mz\n")
    for i in range(len(partition_boundaries)):
        tsv_file.write(str(partition_boundaries[i]) + "\n")
