#!/usr/bin/env python

# Written by Payam Emami and Axel Walter and released under the MIT license.

"""Map MS2 precursors onto consensus features and record which mzML file
each mapped spectrum came from.

This reproduces the spectra branch of OpenMS IDMapper::annotate() for
consensus maps. IDMapper compares every precursor with every consensus
feature (and every sub-feature), and it was called once per mzML file,
followed by a Python pass that copied the identifications of every
consensus feature. On real data that is hours of work. Here the
sub-features are indexed by m/z once, so each precursor only checks the
few candidates inside its m/z window, and spectra are read without
their peak data because only RT, precursors and native IDs are needed.
"""

import argparse
import os

import numpy as np
import pyopenms as py

UNKNOWN_SEARCH_RUN_IDENTIFIER = "UNKNOWN_SEARCH_RUN_IDENTIFIER"

# Widens the m/z search window slightly so that floating point rounding
# never drops a candidate; the exact tolerance check happens afterwards.
MZ_WINDOW_SAFETY_FACTOR = 1.0 + 1e-6


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Maps MS2 to consensusXML including names"
    )
    parser.add_argument(
        "--consensus_input", type=str, help="The path to the consensus file"
    )
    parser.add_argument(
        "--mzml_file_paths", type=str, nargs="+", help="The paths to the mzML files"
    )
    parser.add_argument("--output", type=str, help="The path for output")
    parser.add_argument(
        "--rt_tolerance",
        type=float,
        default=5.0,
        help="The retention time tolerance (seconds)",
    )
    parser.add_argument(
        "--mz_tolerance", type=float, default=20.0, help="The m/z tolerance (ppm)"
    )
    parser.add_argument(
        "--annotate_ids_with_subelements",
        action="store_true",
        help="Annotate IDs with sub-elements",
    )
    parser.add_argument(
        "--measure_from_subelements",
        action="store_true",
        help="Measure from sub-elements",
    )
    parser.add_argument(
        "--ignore_charge",
        action="store_true",
        help="For feature/consensus maps: Assign an ID independently of whether its charge state matches that of the (consensus) feature.",
    )
    return parser.parse_args()


class MappingTargets:
    """The positions precursors are matched against, sorted by m/z.

    With measure_from_subelements every sub-feature is a target, otherwise
    every consensus feature centroid is.
    """

    def __init__(self, consensus_map, measure_from_subelements):
        consensus_indices = []
        handle_positions = []
        retention_times = []
        mz_values = []
        charges = []
        map_indices = []

        for consensus_index, consensus_feature in enumerate(consensus_map):
            if measure_from_subelements:
                for handle_position, handle in enumerate(
                    consensus_feature.getFeatureList()
                ):
                    consensus_indices.append(consensus_index)
                    handle_positions.append(handle_position)
                    retention_times.append(handle.getRT())
                    mz_values.append(handle.getMZ())
                    charges.append(handle.getCharge())
                    map_indices.append(handle.getMapIndex())
            else:
                consensus_indices.append(consensus_index)
                handle_positions.append(0)
                retention_times.append(consensus_feature.getRT())
                mz_values.append(consensus_feature.getMZ())
                charges.append(consensus_feature.getCharge())
                map_indices.append(-1)

        mz_order = np.argsort(np.asarray(mz_values, dtype=np.float64), kind="stable")
        self.consensus_indices = np.asarray(consensus_indices, dtype=np.int64)[mz_order]
        self.handle_positions = np.asarray(handle_positions, dtype=np.int64)[mz_order]
        self.retention_times = np.asarray(retention_times, dtype=np.float64)[mz_order]
        self.mz_values = np.asarray(mz_values, dtype=np.float64)[mz_order]
        self.charges = np.asarray(charges, dtype=np.int64)[mz_order]
        self.map_indices = np.asarray(map_indices, dtype=np.int64)[mz_order]

    def find_matches(
        self,
        precursor_rt,
        precursor_mz,
        precursor_charge,
        rt_tolerance,
        mz_tolerance_ppm,
        ignore_charge,
    ):
        """Return the target rows that IDMapper would accept for one precursor."""
        mz_window = abs(precursor_mz) * mz_tolerance_ppm / 1e6 * MZ_WINDOW_SAFETY_FACTOR
        first = np.searchsorted(self.mz_values, precursor_mz - mz_window, side="left")
        last = np.searchsorted(self.mz_values, precursor_mz + mz_window, side="right")
        candidates = np.arange(first, last)

        # Same arithmetic as IDMapper::isMatch_ with Math::getPPMAbs(observed, theoretical)
        ppm_error = np.abs(
            (self.mz_values[candidates] - precursor_mz) / precursor_mz * 1e6
        )
        rt_error = np.abs(precursor_rt - self.retention_times[candidates])
        accepted = (ppm_error <= mz_tolerance_ppm) & (rt_error <= rt_tolerance)

        if not ignore_charge:
            candidate_charges = self.charges[candidates]
            accepted &= (candidate_charges == precursor_charge) | (
                candidate_charges == 0
            )

        return candidates[accepted]


def load_spectra_without_peaks(mzml_path):
    options = py.PeakFileOptions()
    options.setFillData(False)

    mzml_file = py.MzMLFile()
    mzml_file.setOptions(options)

    experiment = py.MSExperiment()
    mzml_file.load(mzml_path, experiment)
    return experiment


def collect_precursors(experiment):
    """One entry per precursor, in spectrum then precursor order."""
    precursors = []
    for spectrum_index in range(experiment.getNrSpectra()):
        spectrum = experiment.getSpectrum(spectrum_index)
        for precursor_index, precursor in enumerate(spectrum.getPrecursors()):
            precursors.append(
                {
                    "spectrum_index": spectrum_index,
                    "precursor_index": precursor_index,
                    "rt": spectrum.getRT(),
                    "mz": precursor.getMZ(),
                    "charge": precursor.getCharge(),
                    "native_id": spectrum.getNativeID(),
                }
            )
    return precursors


def resolve_search_identifier(consensus_map):
    """Pick the search run identifier the way IDMapper does, adding a
    placeholder protein identification when the map has none."""
    protein_identifications = consensus_map.getProteinIdentifications()
    if protein_identifications:
        return protein_identifications[0].getIdentifier()

    unassigned_identifications = consensus_map.getUnassignedPeptideIdentifications()
    if unassigned_identifications:
        return unassigned_identifications[0].getIdentifier()

    placeholder = py.ProteinIdentification()
    placeholder.setDateTime(py.DateTime.now())
    placeholder.setIdentifier(UNKNOWN_SEARCH_RUN_IDENTIFIER)
    consensus_map.setProteinIdentifications([placeholder])
    return UNKNOWN_SEARCH_RUN_IDENTIFIER


def build_precursor_identification(
    precursor, search_identifier, map_index, file_name, file_index
):
    identification = py.PeptideIdentification()
    identification.setRT(precursor["rt"])
    identification.setMZ(precursor["mz"])
    identification.setMetaValue("spectrum_index", precursor["spectrum_index"])
    if precursor["native_id"]:
        identification.setMetaValue("spectrum_reference", precursor["native_id"])
    identification.setIdentifier(search_identifier)
    if map_index is not None:
        identification.setMetaValue("map_index", map_index)
    identification.setMetaValue("id_file", file_name)
    identification.setMetaValue("id_file_index", file_index)
    return identification


def map_file_precursors(targets, precursors, arguments):
    """Return (consensus_index, sort_key, precursor, map_index) for every match of one file."""
    record_map_index = (
        arguments.measure_from_subelements and arguments.annotate_ids_with_subelements
    )
    matches = []
    for precursor in precursors:
        matched_rows = targets.find_matches(
            precursor["rt"],
            precursor["mz"],
            precursor["charge"],
            arguments.rt_tolerance,
            arguments.mz_tolerance,
            arguments.ignore_charge,
        )
        for row in matched_rows:
            map_index = int(targets.map_indices[row]) if record_map_index else None
            sort_key = (
                precursor["spectrum_index"],
                precursor["precursor_index"],
                int(targets.handle_positions[row]),
            )
            matches.append(
                (int(targets.consensus_indices[row]), sort_key, precursor, map_index)
            )
    return matches


def tag_existing_identifications(consensus_map, first_file_name):
    """The previous implementation tagged spectrum-derived identifications
    that already sat on the input map with the first mzML file; keep that."""
    for consensus_index in range(consensus_map.size()):
        consensus_feature = consensus_map[consensus_index]
        # pyopenms hands out copies of the identifications, so collect the edited ones and store them back
        identifications = []
        changed = False
        for identification in consensus_feature.getPeptideIdentifications():
            if identification.metaValueExists(
                "spectrum_index"
            ) and not identification.metaValueExists("id_file"):
                identification.setMetaValue("id_file", first_file_name)
                identification.setMetaValue("id_file_index", 0)
                changed = True
            identifications.append(identification)
        if changed:
            consensus_feature.setPeptideIdentifications(
                py.PeptideIdentificationList(identifications)
            )
            consensus_map[consensus_index] = consensus_feature


def main():
    arguments = parse_arguments()

    consensus_file = py.ConsensusXMLFile()
    consensus_map = py.ConsensusMap()
    consensus_file.load(arguments.consensus_input, consensus_map)

    tag_existing_identifications(
        consensus_map, os.path.basename(arguments.mzml_file_paths[0])
    )

    targets = MappingTargets(consensus_map, arguments.measure_from_subelements)
    new_identifications = {}
    search_identifier = None

    for file_index, mzml_path in enumerate(arguments.mzml_file_paths):
        file_name = os.path.basename(mzml_path)
        experiment = load_spectra_without_peaks(mzml_path)
        precursors = collect_precursors(experiment)
        if not precursors:
            continue

        if search_identifier is None:
            search_identifier = resolve_search_identifier(consensus_map)

        matches = map_file_precursors(targets, precursors, arguments)
        matches.sort(key=lambda match: (match[0], match[1]))
        for consensus_index, _sort_key, precursor, map_index in matches:
            identification = build_precursor_identification(
                precursor, search_identifier, map_index, file_name, file_index
            )
            new_identifications.setdefault(consensus_index, []).append(identification)

    for consensus_index, identifications_to_add in new_identifications.items():
        consensus_feature = consensus_map[consensus_index]
        identifications = consensus_feature.getPeptideIdentifications()
        identifications.extend(identifications_to_add)
        consensus_feature.setPeptideIdentifications(identifications)
        consensus_map[consensus_index] = consensus_feature

    consensus_file.store(arguments.output, consensus_map)


if __name__ == "__main__":
    main()
