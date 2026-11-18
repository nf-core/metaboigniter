#!/usr/bin/env python

# Written for nf-core/metaboigniter and released under the MIT license.

"""Quality-control FeatureFinderMetaboIdent candidates of one sample.

Every requested target gets exactly one row: accepted, rejected (with the first
failing check and the list of all failing checks) or no_candidate. Accepted
targets are also written to a compact fill table that the global gap-filling
step inserts into the requesting consensus row. Problems that indicate a
pipeline fault rather than a bad candidate abort the task.
"""

import argparse
import bisect
import csv
import math
import re

import pyopenms as po

VALID_MODEL_STATUS = "0 (valid)"
KNOWN_MODEL_STATUS = frozenset(
    [
        "0 (valid)",
        "1 (invalid area)",
        "2 (center out of bounds)",
        "3 (left side out of bounds)",
        "4 (right side out of bounds)",
        "5 (width too large)",
        "6 (width too small)",
        "7 (asymmetry too high)",
        "8 (asymmetry too low)",
    ]
)
# Evaluation precedence: the first failing check is the rejection reason.
CHECK_ORDER = (
    "malformed_qc_metadata",
    "existing_signal_overlap",
    "no_peak_at_apex",
    "apex_outside_target_window",
    "model_status_not_valid",
    "low_apex_signal_fraction",
    "shared_candidate_signal",
    "duplicate_feature_identity",
)
APEX_HALF_WINDOW_SECONDS = 3.0
RELATIVE_TOLERANCE = 1e-6
LABEL_RE = re.compile(r"^requant_(\d+)_(\d+)$")
CANDIDATE_COLUMNS = [
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
    "n_observed",
    "charge",
    "status",
    "rejection_reason",
    "failed_checks",
    "fill_feature_uid",
    "candidate_rt",
    "candidate_apex_rt",
    "rt_error_s",
    "ffmi_masserror_ppm",
    "model_status",
    "model_area",
    "raw_intensity",
    "exported_intensity",
    "left_width",
    "right_width",
    "apex_signal_fraction",
    "peak_apex_int",
    "overlapping_original_uids",
]
FILL_COLUMNS = [
    "sample",
    "map_index",
    "consensus_index",
    "consensus_uid",
    "target_id",
    "rt",
    "mz",
    "intensity",
    "charge",
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
    "n_observed",
    "charge",
]


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sample", required=True)
    parser.add_argument("--targets", required=True, help="targets TSV of this sample")
    parser.add_argument("--originals", required=True, help="original-feature TSV")
    parser.add_argument(
        "--candidates", help="FeatureFinderMetaboIdent featureXML (absent: no targets)"
    )
    parser.add_argument(
        "--mz-window",
        type=float,
        default=10.0,
        help="FFMI extract:mz_window (ppm if >= 1, else Th); overlap uses half of it",
    )
    parser.add_argument("--min-apex-signal-fraction", type=float, default=0.3)
    parser.add_argument("--output-candidates", required=True)
    parser.add_argument("--output-fills", required=True)
    args = parser.parse_args(argv)
    if not (math.isfinite(args.mz_window) and args.mz_window > 0):
        parser.error("--mz-window must be a finite number greater than zero")
    if not 0.0 <= args.min_apex_signal_fraction <= 1.0:
        parser.error("--min-apex-signal-fraction must be between 0 and 1")
    return args


def is_finite_number(value):
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(value)
    )


def relative_equal(left, right, tolerance=RELATIVE_TOLERANCE):
    return abs(left - right) <= tolerance * max(abs(left), abs(right), 1e-300)


def half_window(target_mz, mz_window):
    """Half width (Th) of the FFMI extraction window around `target_mz`."""
    if mz_window >= 1:
        return target_mz * mz_window * 1e-6 / 2.0
    return mz_window / 2.0


def read_targets(path, sample):
    with open(path, newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        missing = set(TARGET_COLUMNS) - set(reader.fieldnames or [])
        if missing:
            raise ValueError(f"Target table {path} lacks columns {sorted(missing)}")
        targets = list(reader)
    by_id = {}
    map_indices = set()
    for target in targets:
        if target["sample"] != sample:
            raise ValueError(f"Target table {path} contains sample {target['sample']}")
        if target["target_id"] in by_id:
            raise ValueError(f"Duplicate target {target['target_id']} in {path}")
        by_id[target["target_id"]] = target
        map_indices.add(int(target["map_index"]))
    if len(map_indices) > 1:
        raise ValueError(f"Target table {path} has several map indexes")
    return targets, by_id


def read_originals(path):
    with open(path, newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def build_overlap_index(originals):
    """Sorted m/z values (monoisotopic and every mass trace) with their owner."""
    entries = []
    seen = set()
    for row in originals:
        uid = row["uid"]
        if uid in seen:
            raise ValueError(f"Original feature UID {uid} occurs twice")
        seen.add(uid)
        rt = float(row["rt"])
        trace_mz = [float(value) for value in row["masstrace_centroid_mz"].split(";")]
        for mz in {float(row["mz"]), *trace_mz}:
            entries.append((mz, rt, uid))
    entries.sort()
    return (
        [entry[0] for entry in entries],
        [entry[1] for entry in entries],
        [entry[2] for entry in entries],
    )


def find_overlapping_originals(index, target_mz, tolerance, left, right):
    """UIDs of originals with any m/z within `tolerance` Th of `target_mz` and
    an RT inside [left, right], in m/z order without duplicates."""
    sorted_mz, rts, uids = index
    low = bisect.bisect_left(sorted_mz, target_mz - tolerance)
    high = bisect.bisect_right(sorted_mz, target_mz + tolerance)
    found = []
    for position in range(low, high):
        if left <= rts[position] <= right and uids[position] not in found:
            found.append(uids[position])
    return found


def load_candidates(path):
    feature_map = po.FeatureMap()
    po.FeatureXMLFile().load(str(path), feature_map)
    return feature_map


def apex_signal_fraction(hull_points, apex_rt, half_window_s=APEX_HALF_WINDOW_SECONDS):
    """Fraction of extracted-ion-chromatogram points (one per MS1 scan, zero
    intensities included) within +-half_window_s of the apex that have signal."""
    near = [
        float(intensity)
        for rt, intensity in hull_points
        if abs(float(rt) - apex_rt) <= half_window_s
    ]
    if not near:
        return 0.0
    return sum(1 for intensity in near if intensity > 0) / len(near)


def meta(feature, key):
    return feature.getMetaValue(key) if feature.metaValueExists(key) else None


def candidate_metadata(feature):
    """Extract the QC metadata of a candidate; return (values, problems)."""
    problems = []
    values = {
        "rt": feature.getRT(),
        "mz": feature.getMZ(),
        "intensity": feature.getIntensity(),
    }
    status = meta(feature, "model_status")
    values["model_status"] = status
    if status not in KNOWN_MODEL_STATUS:
        problems.append("model_status")
    left, right = meta(feature, "leftWidth"), meta(feature, "rightWidth")
    values["left_width"], values["right_width"] = left, right
    if not (is_finite_number(left) and is_finite_number(right)) or left >= right:
        problems.append("leftWidth/rightWidth")
    traces = meta(feature, "num_of_masstraces")
    values["num_of_masstraces"] = traces
    if not isinstance(traces, int) or traces < 1:
        problems.append("num_of_masstraces")
    masserror = meta(feature, "masserror_ppm")
    values["masserror_ppm"] = masserror if isinstance(masserror, list) else None
    if (
        not isinstance(masserror, list)
        or not masserror
        or not all(is_finite_number(value) for value in masserror)
        or (isinstance(traces, int) and len(masserror) != traces)
    ):
        problems.append("masserror_ppm")
    precursor_mz = meta(feature, "PrecursorMZ")
    values["precursor_mz"] = precursor_mz
    if not is_finite_number(precursor_mz):
        problems.append("PrecursorMZ")
    if not is_finite_number(values["rt"]):
        problems.append("RT")

    subordinates = feature.getSubordinates()
    values["apex_signal_fraction"] = None
    values["peak_apex_position"] = None
    values["peak_apex_int"] = None
    if not subordinates or (isinstance(traces, int) and len(subordinates) != traces):
        problems.append("subordinates")
    else:
        mono = subordinates[0]
        apex = meta(mono, "peak_apex_position")
        values["peak_apex_position"] = apex
        values["peak_apex_int"] = meta(mono, "peak_apex_int")
        if not is_finite_number(apex):
            problems.append("peak_apex_position")
        hulls = mono.getConvexHulls()
        points = hulls[0].getHullPoints() if hulls else []
        if len(points) == 0:
            problems.append("hull")
        elif is_finite_number(apex):
            # only the fraction is kept: hull points of every candidate are large
            values["apex_signal_fraction"] = apex_signal_fraction(points, apex)

    values["raw_intensity"] = meta(feature, "raw_intensity")
    values["model_area"] = meta(feature, "model_area")
    if status == VALID_MODEL_STATUS:
        area = values["model_area"]
        if not (is_finite_number(area) and area > 0):
            problems.append("model_area")
        elif not relative_equal(values["intensity"], area):
            problems.append("intensity!=model_area")
        if not is_finite_number(values["raw_intensity"]):
            problems.append("raw_intensity")
    return values, problems


def parse_label(label):
    """Return the target ids of a candidate label ('/' joins shared targets)."""
    if not isinstance(label, str) or not label:
        raise ValueError("FeatureFinderMetaboIdent returned a feature without a label")
    return label.split("/")


def assign_candidates(feature_map, targets_by_id, map_index):
    """Map every candidate to its target(s); abort on pipeline faults."""
    assigned = {}
    for feature in feature_map:
        target_ids = parse_label(meta(feature, "label"))
        shared = len(target_ids) > 1 or feature.metaValueExists("alt_PeptideRef")
        for target_id in target_ids:
            match = LABEL_RE.match(target_id)
            if match is None:
                raise ValueError(f"Unexpected candidate label {target_id!r}")
            if int(match.group(1)) != map_index:
                raise ValueError(
                    f"Candidate {target_id} belongs to map index {match.group(1)}, "
                    f"not to this sample's map index {map_index}"
                )
            if target_id not in targets_by_id:
                raise ValueError(f"Candidate label {target_id} is not a target")
            if target_id in assigned:
                raise ValueError(f"Target {target_id} has more than one candidate")
            assigned[target_id] = (feature, shared)
    return assigned


def check_precursor_consistency(feature, values, target):
    """PrecursorMZ, feature m/z and target m/z must agree (mass/charge formulas)."""
    target_mz = float(target["target_mz"])
    if values["precursor_mz"] is None or not is_finite_number(values["precursor_mz"]):
        return
    if not (
        relative_equal(values["precursor_mz"], target_mz)
        and relative_equal(feature.getMZ(), target_mz)
    ):
        raise ValueError(
            f"Candidate of {target['target_id']}: PrecursorMZ {values['precursor_mz']} / "
            f"feature m/z {feature.getMZ()} differ from target m/z {target_mz}"
        )


def find_shared_candidate_signals(records, mz_window):
    """Target ids whose candidate shares its signal with another candidate:
    apexes inside each other's integration interval and target m/z within the
    overlap tolerance, or FFMI removed an overlapping candidate (overlap_removed)."""
    shared = set()
    usable = []
    for record in records:
        values = record["values"]
        if record["overlap_removed"]:
            shared.add(record["target_id"])
        if (
            is_finite_number(values["peak_apex_position"])
            and is_finite_number(values["left_width"])
            and is_finite_number(values["right_width"])
        ):
            usable.append(record)
    usable.sort(key=lambda record: record["target_mz"])
    target_mz = [record["target_mz"] for record in usable]
    for position, record in enumerate(usable):
        tolerance = half_window(record["target_mz"], mz_window)
        high = bisect.bisect_right(target_mz, record["target_mz"] + tolerance)
        for other in usable[position + 1 : high]:
            if other["feature_index"] == record["feature_index"]:
                continue
            first, second = record["values"], other["values"]
            if (
                second["left_width"]
                <= first["peak_apex_position"]
                <= second["right_width"]
                and first["left_width"]
                <= second["peak_apex_position"]
                <= first["right_width"]
            ):
                shared.add(record["target_id"])
                shared.add(other["target_id"])
    return shared


def evaluate_candidate(
    target, values, problems, shared_label, index, mz_window, min_fraction
):
    """Return (failed_checks, extra) for one candidate, in CHECK_ORDER order
    except shared_candidate_signal and duplicate_feature_identity, which need
    the other candidates or the consensus map."""
    failed = []
    extra = {"overlapping_original_uids": [], "apex_signal_fraction": None}
    if problems or shared_label:
        failed.append("malformed_qc_metadata")
    target_mz = float(target["target_mz"])
    left, right = values["left_width"], values["right_width"]
    if is_finite_number(left) and is_finite_number(right):
        overlapping = find_overlapping_originals(
            index, target_mz, half_window(target_mz, mz_window), left, right
        )
        extra["overlapping_original_uids"] = overlapping
        if overlapping:
            failed.append("existing_signal_overlap")
    masserror = values["masserror_ppm"] or []
    if any(value == -1 for value in masserror):
        failed.append("no_peak_at_apex")
    apex = values["peak_apex_position"]
    if is_finite_number(apex) and not (
        float(target["window_min"]) <= apex <= float(target["window_max"])
    ):
        failed.append("apex_outside_target_window")
    if values["model_status"] != VALID_MODEL_STATUS:
        failed.append("model_status_not_valid")
    fraction = values["apex_signal_fraction"]
    if fraction is not None:
        extra["apex_signal_fraction"] = fraction
        if fraction < min_fraction:
            failed.append("low_apex_signal_fraction")
    return failed, extra


def ordered(checks):
    return [check for check in CHECK_ORDER if check in checks]


def format_value(value):
    if value is None:
        return ""
    if isinstance(value, float):
        return repr(value)
    if isinstance(value, list):
        return ";".join(format_value(item) for item in value)
    return value


def write_tsv(path, columns, rows):
    with open(path, "w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle, fieldnames=columns, delimiter="\t", lineterminator="\n"
        )
        writer.writeheader()
        for row in rows:
            writer.writerow({key: format_value(row.get(key)) for key in columns})


def qc_sample(
    sample, targets, targets_by_id, originals, feature_map, mz_window, min_fraction
):
    """Return (candidate rows, fill rows) for one sample."""
    map_index = int(targets[0]["map_index"]) if targets else None
    assigned = (
        assign_candidates(feature_map, targets_by_id, map_index)
        if feature_map is not None and targets
        else {}
    )
    if feature_map is not None and feature_map.size() and not targets:
        raise ValueError(f"{sample} has candidates but no targets")
    index = build_overlap_index(originals)

    records = []
    feature_ids = {}
    for target in targets:
        entry = assigned.get(target["target_id"])
        if entry is None:
            continue
        feature, shared_label = entry
        values, problems = candidate_metadata(feature)
        check_precursor_consistency(feature, values, target)
        feature_index = feature_ids.setdefault(id(feature), len(feature_ids))
        records.append(
            {
                "target_id": target["target_id"],
                "target_mz": float(target["target_mz"]),
                "feature_index": feature_index,
                "values": values,
                "problems": problems,
                "shared_label": shared_label,
                "overlap_removed": bool(meta(feature, "overlap_removed")),
            }
        )
    shared_signal = find_shared_candidate_signals(records, mz_window)
    records_by_target = {record["target_id"]: record for record in records}

    rows, fills = [], []
    for target in targets:
        row = {column: target.get(column) for column in TARGET_COLUMNS}
        record = records_by_target.get(target["target_id"])
        if record is None:
            row.update(
                {
                    "status": "no_candidate",
                    "rejection_reason": "no_candidate",
                    "failed_checks": "no_candidate",
                }
            )
            rows.append(row)
            continue
        values = record["values"]
        failed, extra = evaluate_candidate(
            target,
            values,
            record["problems"],
            record["shared_label"],
            index,
            mz_window,
            min_fraction,
        )
        if target["target_id"] in shared_signal:
            failed.append("shared_candidate_signal")
        failed = ordered(failed)
        accepted = not failed
        apex = values["peak_apex_position"]
        row.update(
            {
                "status": "accepted" if accepted else "rejected",
                "rejection_reason": failed[0] if failed else "",
                "failed_checks": ";".join(failed),
                "candidate_rt": values["rt"],
                "candidate_apex_rt": apex,
                "rt_error_s": apex - float(target["target_rt"])
                if is_finite_number(apex)
                else None,
                "ffmi_masserror_ppm": values["masserror_ppm"],
                "model_status": values["model_status"],
                "model_area": values["model_area"],
                "raw_intensity": values["raw_intensity"],
                "exported_intensity": values["model_area"] if accepted else None,
                "left_width": values["left_width"],
                "right_width": values["right_width"],
                "apex_signal_fraction": extra["apex_signal_fraction"],
                "peak_apex_int": values["peak_apex_int"],
                "overlapping_original_uids": extra["overlapping_original_uids"],
            }
        )
        if record["problems"]:
            print(
                f"{sample} {target['target_id']}: malformed QC metadata "
                f"{record['problems']}"
            )
        rows.append(row)
        if accepted:
            fills.append(
                {
                    "sample": sample,
                    "map_index": target["map_index"],
                    "consensus_index": target["consensus_index"],
                    "consensus_uid": target["consensus_uid"],
                    "target_id": target["target_id"],
                    "rt": values["rt"],
                    "mz": float(target["target_mz"]),
                    "intensity": values["model_area"],
                    "charge": target["charge"],
                }
            )
    return rows, fills


def main(argv=None):
    args = parse_args(argv)
    targets, targets_by_id = read_targets(args.targets, args.sample)
    originals = read_originals(args.originals)
    if args.candidates:
        feature_map = load_candidates(args.candidates)
    elif targets:
        raise ValueError(f"{args.sample} has targets but no candidate featureXML")
    else:
        feature_map = None
    rows, fills = qc_sample(
        args.sample,
        targets,
        targets_by_id,
        originals,
        feature_map,
        args.mz_window,
        args.min_apex_signal_fraction,
    )
    if len(rows) != len(targets):
        raise RuntimeError("Candidate table does not have one row per target")
    write_tsv(args.output_candidates, CANDIDATE_COLUMNS, rows)
    write_tsv(args.output_fills, FILL_COLUMNS, fills)
    print(f"{args.sample}: {len(targets)} targets, {len(fills)} accepted")


if __name__ == "__main__":
    main()
