#!/usr/bin/env python

# Written by Payam Emami and Axel Walter and released under the MIT license.

"""Build the per-sample FeatureFinderMetaboIdent library for requantification.

The initial consensus map is authoritative. A sample's map index is the single
map index whose consensus handles are exactly this sample's features (matched
by feature UID). A sample without features has no handles; its map index is the
single column header that records both its feature map's unique ID and its
primary MS run path. Every consensus row without a handle at that map index
becomes one target, identified by its consensus UID, so that an accepted fill
can later be inserted into exactly the row that requested it.
"""

import argparse
import csv
import math
import sys
from pathlib import Path

import pyopenms as po

PROTON_MASS_U = 1.007276466621
LIBRARY_COLUMNS = [
    "CompoundName",
    "SumFormula",
    "Mass",
    "Charge",
    "RetentionTime",
    "RetentionTimeRange",
    "IsoDistribution",
]
TARGET_COLUMNS = [
    "sample",
    "map_index",
    "consensus_index",
    "consensus_uid",
    "target_id",
    "target_mz",
    "target_rt",
    "consensus_rt",
    "window_min",
    "window_max",
    "handle_rt_min",
    "handle_rt_max",
    "n_observed",
    "charge",
]
ORIGINAL_COLUMNS = ["uid", "mz", "rt", "fwhm", "intensity", "masstrace_centroid_mz"]
SAMPLE_MAP_COLUMNS = [
    "sample",
    "map_index",
    "n_features",
    "n_targets",
    "header_filename",
    "header_filename_matches_sample",
]


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--consensus", required=True, help="initial consensusXML")
    parser.add_argument(
        "--features", required=True, help="featureXML of this sample that was linked"
    )
    parser.add_argument("--sample", required=True, help="sample identifier (meta.id)")
    parser.add_argument("--polarity", choices=["positive", "negative"], required=True)
    parser.add_argument(
        "--rt-margin",
        type=float,
        default=30.0,
        help="seconds added on each side of the RT span of the consensus handles",
    )
    parser.add_argument("--library", required=True, help="output FFMI library TSV")
    parser.add_argument("--targets", required=True, help="output target TSV")
    parser.add_argument(
        "--originals", required=True, help="output compact original-feature TSV"
    )
    parser.add_argument(
        "--sample-map", required=True, help="output sample/map-index TSV"
    )
    args = parser.parse_args(argv)
    if not (math.isfinite(args.rt_margin) and args.rt_margin > 0):
        # FFMI replaces a zero RetentionTimeRange with extract:rt_window
        parser.error("--rt-margin must be a finite number greater than zero")
    return args


def header_stem(filename):
    name = str(filename)
    if name.startswith("file://"):
        name = name[len("file://") :]
    return Path(name).stem


def load_light_features(path):
    feature_file = po.FeatureXMLFile()
    options = feature_file.getOptions()
    options.setLoadConvexHull(False)
    options.setLoadSubordinates(False)
    feature_file.setOptions(options)
    feature_map = po.FeatureMap()
    feature_file.load(str(path), feature_map)
    return feature_map


def resolve_map_index(consensus_map, feature_map, sample):
    """Return the map index whose handles are exactly the features of this sample.

    Fails if a feature UID is duplicated in the featureXML, if any feature UID
    does not occur exactly once in the consensus, if the features span zero or
    several map indexes, or if any handle at the resolved map index is not a
    feature of this sample. A sample without features is resolved by
    resolve_empty_map_index().
    """
    sample_uids = set()
    for feature in feature_map:
        uid = feature.getUniqueId()
        if uid in sample_uids:
            raise ValueError(
                f"Feature UID {uid} occurs twice in the features of {sample}"
            )
        sample_uids.add(uid)
    if not sample_uids:
        return resolve_empty_map_index(consensus_map, feature_map, sample)

    occurrences = {}
    handles_by_index = {}
    for consensus_feature in consensus_map:
        for handle in consensus_feature.getFeatureList():
            uid = handle.getUniqueId()
            handles_by_index.setdefault(handle.getMapIndex(), set()).add(uid)
            if uid in sample_uids:
                occurrences.setdefault(uid, []).append(handle.getMapIndex())

    not_once = [uid for uid in sample_uids if len(occurrences.get(uid, [])) != 1]
    if not_once:
        raise ValueError(
            f"{len(not_once)} feature UIDs of {sample} do not occur exactly once in the "
            f"consensus map (first: {sorted(not_once)[:5]})"
        )
    map_indices = {indices[0] for indices in occurrences.values()}
    if len(map_indices) != 1:
        raise ValueError(
            f"Features of {sample} belong to map indexes {sorted(map_indices)}; "
            "expected exactly one"
        )
    map_index = map_indices.pop()
    foreign = handles_by_index[map_index] - sample_uids
    if foreign:
        raise ValueError(
            f"Map index {map_index} contains {len(foreign)} handles that are not "
            f"features of {sample}"
        )
    return map_index


def primary_ms_run_paths(feature_map):
    """The primary MS run paths stored in the featureXML ("spectra_data").

    The stored value is read directly: FeatureMap.getPrimaryMSRunPath() would
    substitute the placeholder 'UNKNOWN' for a missing path.
    """
    if not feature_map.metaValueExists("spectra_data"):
        return []
    paths = feature_map.getMetaValue("spectra_data")
    if not isinstance(paths, list):
        paths = [paths]
    return [path.decode() if isinstance(path, bytes) else str(path) for path in paths]


def resolve_empty_map_index(consensus_map, feature_map, sample):
    """Return the map index of a sample whose feature map is empty.

    Without features there are no handles to match. FeatureLinkerUnlabeledKD
    copies, for input map i, the feature map's unique ID and its single primary
    MS run path unchanged into column header i (parallel linking keeps both).
    The map index is accepted only if exactly one column header carries this
    unique ID, exactly one carries this path (compared exactly), both are the
    same header, that header records zero features and no consensus handle
    uses its map index. Anything else fails with a list of all column headers.
    """
    if not feature_map.hasValidUniqueId():
        raise ValueError(
            f"Sample {sample} has no features and its feature map has no unique "
            "ID; its consensus column cannot be identified"
        )
    map_uid = feature_map.getUniqueId()
    run_paths = primary_ms_run_paths(feature_map)
    if len(run_paths) != 1 or not run_paths[0]:
        raise ValueError(
            f"Sample {sample} has no features and its feature map has "
            f"{len(run_paths)} primary MS run paths {run_paths}; exactly one is "
            "needed to identify its consensus column"
        )
    run_path = run_paths[0]

    handle_counts = {}
    for consensus_feature in consensus_map:
        for handle in consensus_feature.getFeatureList():
            index = handle.getMapIndex()
            handle_counts[index] = handle_counts.get(index, 0) + 1

    headers = consensus_map.getColumnHeaders()
    indices = sorted(headers)
    uid_matches = [i for i in indices if headers[i].unique_id == map_uid]
    path_matches = [i for i in indices if str(headers[i].filename) == run_path]

    def diagnostic():
        title = (
            f"feature map unique ID {map_uid}, primary MS run path "
            f"'{run_path}'; consensus column headers:"
        )
        lines = [title]
        for index in indices:
            header = headers[index]
            lines.append(
                f"  map index {index}: filename '{header.filename}' "
                f"(path match: {index in path_matches}), "
                f"unique ID {header.unique_id} "
                f"(unique ID match: {index in uid_matches}), "
                f"size {header.size}, handles {handle_counts.get(index, 0)}"
            )
        return "\n".join(lines)

    if len(uid_matches) != 1 or uid_matches != path_matches:
        raise ValueError(
            f"Sample {sample} has no features; its feature map unique ID matches "
            f"map indexes {uid_matches} and its primary MS run path matches map "
            f"indexes {path_matches}, expected both to match the same single "
            f"column\n{diagnostic()}"
        )
    map_index = uid_matches[0]
    if headers[map_index].size != 0:
        raise ValueError(
            f"Sample {sample} has no features but the column header of map index "
            f"{map_index} records {headers[map_index].size} features\n{diagnostic()}"
        )
    if handle_counts.get(map_index, 0):
        raise ValueError(
            f"Sample {sample} has no features but map index {map_index} has "
            f"{handle_counts[map_index]} consensus handles\n{diagnostic()}"
        )
    return map_index


def neutral_mass(mz, charge, ion_sign):
    """Neutral mass of an ion with m/z `mz` and charge magnitude `charge`."""
    return mz * charge - ion_sign * charge * PROTON_MASS_U


def build_targets(consensus_map, map_index, sample, rt_margin, polarity):
    """One target per consensus row that has no handle at `map_index`."""
    if not (math.isfinite(rt_margin) and rt_margin > 0):
        raise ValueError("rt_margin must be a finite number greater than zero")
    ion_sign = 1 if polarity == "positive" else -1
    targets = []
    seen = set()
    for consensus_index, consensus_feature in enumerate(consensus_map):
        consensus_uid = consensus_feature.getUniqueId()
        if consensus_uid in seen:
            raise ValueError(f"Consensus UID {consensus_uid} occurs twice")
        seen.add(consensus_uid)
        handles = list(consensus_feature.getFeatureList())
        if any(handle.getMapIndex() == map_index for handle in handles):
            continue
        retention_times = [handle.getRT() for handle in handles]
        rt_min, rt_max = min(retention_times), max(retention_times)
        center = (rt_min + rt_max) / 2.0
        width = (rt_max - rt_min) + 2.0 * rt_margin
        targets.append(
            {
                "sample": sample,
                "map_index": map_index,
                "consensus_index": consensus_index,
                "consensus_uid": consensus_uid,
                "target_id": f"requant_{map_index}_{consensus_uid}",
                "target_mz": consensus_feature.getMZ(),
                "target_rt": center,
                "consensus_rt": consensus_feature.getRT(),
                "window_min": center - width / 2.0,
                "window_max": center + width / 2.0,
                "handle_rt_min": rt_min,
                "handle_rt_max": rt_max,
                "n_observed": len(handles),
                "charge": ion_sign * (abs(int(consensus_feature.getCharge())) or 1),
            }
        )
    return targets


def library_rows(targets, polarity):
    """FeatureFinderMetaboIdent assay-library rows for the targets."""
    ion_sign = 1 if polarity == "positive" else -1
    rows = []
    for target in targets:
        charge = abs(int(target["charge"]))
        if charge < 1 or (target["charge"] > 0) != (ion_sign > 0):
            raise ValueError(f"Invalid charge for target {target['target_id']}")
        mass = neutral_mass(float(target["target_mz"]), charge, ion_sign)
        rt = float(target["target_rt"])
        rt_range = float(target["window_max"]) - float(target["window_min"])
        if not (math.isfinite(mass) and math.isfinite(rt) and math.isfinite(rt_range)):
            raise ValueError(f"Non-finite library value for {target['target_id']}")
        if rt_range <= 0:
            raise ValueError(f"Empty RT range for {target['target_id']}")
        rows.append(
            {
                "CompoundName": target["target_id"],
                # a blank formula gives a single (monoisotopic) transition
                "SumFormula": " ",
                "Mass": repr(mass),
                "Charge": f"{'+' if ion_sign > 0 else '-'}{charge}",
                "RetentionTime": repr(rt),
                "RetentionTimeRange": repr(rt_range),
                "IsoDistribution": 0,
            }
        )
    return rows


def original_rows(feature_map):
    """Compact table of the sample's original features sorted by m/z."""
    rows = []
    for feature in feature_map:
        if not feature.metaValueExists("masstrace_centroid_mz"):
            raise ValueError(
                f"Feature {feature.getUniqueId()} has no masstrace_centroid_mz meta value"
            )
        trace_mz = feature.getMetaValue("masstrace_centroid_mz")
        if not isinstance(trace_mz, list) or not trace_mz:
            raise ValueError(
                f"Feature {feature.getUniqueId()} has an empty masstrace_centroid_mz"
            )
        if not all(math.isfinite(value) for value in trace_mz):
            raise ValueError(
                f"Feature {feature.getUniqueId()} has a non-finite masstrace_centroid_mz"
            )
        rows.append(
            {
                "uid": feature.getUniqueId(),
                "mz": feature.getMZ(),
                "rt": feature.getRT(),
                "fwhm": feature.getWidth(),
                "intensity": feature.getIntensity(),
                "masstrace_centroid_mz": ";".join(repr(value) for value in trace_mz),
            }
        )
    rows.sort(key=lambda row: (row["mz"], row["rt"], row["uid"]))
    return rows


def format_value(value):
    return repr(value) if isinstance(value, float) else value


def write_tsv(path, columns, rows):
    with open(path, "w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle, fieldnames=columns, delimiter="\t", lineterminator="\n"
        )
        writer.writeheader()
        for row in rows:
            writer.writerow({key: format_value(value) for key, value in row.items()})


def main(argv=None):
    args = parse_args(argv)
    consensus_map = po.ConsensusMap()
    po.ConsensusXMLFile().load(args.consensus, consensus_map)
    feature_map = load_light_features(args.features)

    map_index = resolve_map_index(consensus_map, feature_map, args.sample)
    headers = consensus_map.getColumnHeaders()
    if map_index not in headers:
        raise ValueError(f"No column header for map index {map_index}")
    header_filename = str(headers[map_index].filename)
    # The file name is recorded for diagnostics only; UID membership decides.
    filename_matches = header_stem(header_filename) == args.sample
    if not filename_matches:
        print(
            f"WARNING: column header '{header_filename}' of map index {map_index} "
            f"does not match sample {args.sample}",
            file=sys.stderr,
        )

    targets = build_targets(
        consensus_map, map_index, args.sample, args.rt_margin, args.polarity
    )
    write_tsv(args.library, LIBRARY_COLUMNS, library_rows(targets, args.polarity))
    write_tsv(args.targets, TARGET_COLUMNS, targets)
    write_tsv(args.originals, ORIGINAL_COLUMNS, original_rows(feature_map))
    write_tsv(
        args.sample_map,
        SAMPLE_MAP_COLUMNS,
        [
            {
                "sample": args.sample,
                "map_index": map_index,
                "n_features": feature_map.size(),
                "n_targets": len(targets),
                "header_filename": header_filename,
                "header_filename_matches_sample": str(filename_matches).lower(),
            }
        ],
    )
    print(f"{args.sample}: map index {map_index}, {len(targets)} targets")


if __name__ == "__main__":
    main()
