#!/usr/bin/env python

# Written for nf-core/metaboigniter and released under the MIT license.

"""Insert accepted requantification fills into the authoritative consensus map.

The initial consensus map is never relinked: each accepted fill becomes one
feature handle in exactly the consensus row that requested it, and nothing
else changes. The task also writes the requantification mask, the provenance
table (one row per requested sample/target) and a per-sample summary.
"""

import argparse
import csv
import hashlib
import struct
from collections import Counter

import pyopenms as po

FILL_UID_NAMESPACE = "metaboigniter-requant"
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
MASK_STATES = (
    "observed",
    "requantified",
    "missing_no_candidate",
    "missing_failed_qc",
    "missing_existing_signal_overlap",
)
SUMMARY_COLUMNS = [
    "sample",
    "consensus_rows",
    "observed",
    "targets_requested",
    "candidates_recovered",
    "accepted",
    "rejected",
    "no_candidate",
    *(f"rejected_{reason}" for reason in CHECK_ORDER),
    "missing_after",
]
PROCESSING_NAME = "nf-core/metaboigniter requantification gap filling"


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--consensus", required=True, help="initial consensusXML")
    parser.add_argument(
        "--sample-tables",
        nargs=4,
        action="append",
        required=True,
        metavar=("SAMPLE", "SAMPLE_MAP_TSV", "CANDIDATES_TSV", "FILLS_TSV"),
        help="per-sample outputs of lib_generator.py and requantification_qc.py",
    )
    parser.add_argument("--output-consensus", required=True)
    parser.add_argument("--mask", required=True)
    parser.add_argument("--provenance", required=True)
    parser.add_argument("--summary", required=True)
    return parser.parse_args(argv)


def fill_uid(sample, consensus_uid):
    """Deterministic, non-zero 64-bit UID of the fill of (sample, consensus row)."""
    key = f"{FILL_UID_NAMESPACE}|{sample}|{consensus_uid}".encode()
    value = int.from_bytes(hashlib.blake2b(key, digest_size=8).digest(), "big")
    return value or 1


def as_float32(value):
    """Feature-handle intensities are stored as 32-bit floats."""
    return struct.unpack("f", struct.pack("f", value))[0]


def read_tsv(path):
    with open(path, newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        return list(reader.fieldnames or []), list(reader)


def read_sample_tables(sample_tables):
    """Read the per-sample tables; return a list of dicts in argument order."""
    samples = []
    seen = set()
    candidate_columns = None
    for sample, sample_map_path, candidates_path, fills_path in sample_tables:
        if sample in seen:
            raise ValueError(f"Sample {sample} is given more than once")
        seen.add(sample)
        _, sample_map = read_tsv(sample_map_path)
        if len(sample_map) != 1 or sample_map[0]["sample"] != sample:
            raise ValueError(f"{sample_map_path} must describe exactly sample {sample}")
        columns, candidates = read_tsv(candidates_path)
        if candidate_columns is None:
            candidate_columns = columns
        elif columns != candidate_columns:
            raise ValueError(f"{candidates_path} has different columns")
        _, fills = read_tsv(fills_path)
        map_index = int(sample_map[0]["map_index"])
        for row in candidates + fills:
            if row["sample"] != sample or int(row["map_index"]) != map_index:
                raise ValueError(
                    f"Row for {row['sample']}/{row['map_index']} in the tables of {sample}"
                )
        if int(sample_map[0]["n_targets"]) != len(candidates):
            raise ValueError(f"{sample}: candidate table does not cover every target")
        samples.append(
            {
                "sample": sample,
                "map_index": map_index,
                "header_filename": sample_map[0]["header_filename"],
                "candidates": candidates,
                "fills": fills,
            }
        )
    return samples, candidate_columns


def resolve_sample_indices(consensus_map, samples):
    """Check that the samples cover every consensus column exactly once."""
    headers = consensus_map.getColumnHeaders()
    index_by_sample = {sample["sample"]: sample["map_index"] for sample in samples}
    indices = list(index_by_sample.values())
    if len(set(indices)) != len(indices):
        raise ValueError("Two samples resolve to the same map index")
    if sorted(indices) != sorted(headers):
        raise ValueError(
            f"Sample map indexes {sorted(indices)} differ from the consensus columns "
            f"{sorted(headers)}"
        )
    filenames = [str(headers[index].filename) for index in sorted(headers)]
    if len(set(filenames)) != len(filenames):
        raise ValueError("Consensus column headers have duplicate file names")
    for sample in samples:
        if str(headers[sample["map_index"]].filename) != sample["header_filename"]:
            raise ValueError(
                f"{sample['sample']}: column header changed since targeting"
            )
    return index_by_sample


def metas(obj):
    keys = []
    obj.getKeys(keys)
    return tuple(
        sorted(
            (
                key.decode() if isinstance(key, bytes) else key,
                repr(obj.getMetaValue(key)),
            )
            for key in keys
        )
    )


def peptide_signature(peptide):
    return (
        peptide.getIdentifier(),
        peptide.getRT(),
        peptide.getMZ(),
        peptide.getScoreType(),
        metas(peptide),
        tuple(
            (
                hit.getScore(),
                hit.getRank(),
                hit.getCharge(),
                str(hit.getSequence()),
                metas(hit),
            )
            for hit in peptide.getHits()
        ),
    )


def handle_signature(handle):
    return (
        handle.getMapIndex(),
        handle.getUniqueId(),
        handle.getRT(),
        handle.getMZ(),
        handle.getIntensity(),
        handle.getCharge(),
    )


def snapshot_consensus(consensus_map):
    """Everything that gap filling must leave unchanged."""
    rows = [snapshot_consensus_row(feature) for feature in consensus_map]
    headers = consensus_map.getColumnHeaders()
    return {
        "rows": rows,
        "headers": {
            index: (
                str(header.filename),
                str(header.label),
                header.size,
                header.unique_id,
            )
            for index, header in headers.items()
        },
        "map_uid": consensus_map.getUniqueId(),
        "proteins": [
            p.getIdentifier() for p in consensus_map.getProteinIdentifications()
        ],
        "unassigned": [
            peptide_signature(p)
            for p in consensus_map.getUnassignedPeptideIdentifications()
        ],
        "processing": len(consensus_map.getDataProcessing()),
    }


def insert_fills(consensus_map, samples):
    """Insert every accepted fill into its requesting row.

    Returns {(sample, consensus_uid): fill_uid or None}; None marks a fill whose
    deterministic UID collides with an existing handle (duplicate_feature_identity).
    """
    row_by_uid = {}
    present = []
    handle_uids = set()
    for row_index, feature in enumerate(consensus_map):
        uid = feature.getUniqueId()
        if uid in row_by_uid:
            raise ValueError(f"Consensus UID {uid} occurs twice")
        row_by_uid[uid] = row_index
        indices = set()
        for handle in feature.getFeatureList():
            if handle.getMapIndex() in indices:
                raise ValueError(f"Consensus row {uid} has two handles for one map")
            indices.add(handle.getMapIndex())
            if handle.getUniqueId() in handle_uids:
                raise ValueError(
                    f"Feature UID {handle.getUniqueId()} is in several rows"
                )
            handle_uids.add(handle.getUniqueId())
        present.append(indices)

    for sample in samples:
        map_index = sample["map_index"]
        lacking = {
            uid
            for uid, row_index in row_by_uid.items()
            if map_index not in present[row_index]
        }
        targets = set()
        for row in sample["candidates"]:
            consensus_uid = int(row["consensus_uid"])
            if consensus_uid in targets:
                raise ValueError(
                    f"{sample['sample']}: target {consensus_uid} occurs twice"
                )
            targets.add(consensus_uid)
            if row_by_uid.get(consensus_uid) != int(row["consensus_index"]):
                raise ValueError(
                    f"{sample['sample']}: consensus UID {consensus_uid} is not at "
                    f"index {row['consensus_index']}"
                )
        if targets != lacking:
            raise ValueError(
                f"{sample['sample']}: {len(targets)} targets but {len(lacking)} rows "
                "lack this sample"
            )
        accepted = {
            int(row["consensus_uid"])
            for row in sample["candidates"]
            if row["status"] == "accepted"
        }
        if {int(row["consensus_uid"]) for row in sample["fills"]} != accepted or len(
            sample["fills"]
        ) != len(accepted):
            raise ValueError(
                f"{sample['sample']}: fill table differs from accepted targets"
            )

    inserted = {}
    for sample in samples:
        map_index = sample["map_index"]
        for row in sample["fills"]:
            consensus_uid = int(row["consensus_uid"])
            row_index = row_by_uid[consensus_uid]
            if map_index in present[row_index]:
                raise ValueError(
                    f"Row {consensus_uid} already has map index {map_index}"
                )
            uid = fill_uid(sample["sample"], consensus_uid)
            if uid in handle_uids:
                inserted[(sample["sample"], consensus_uid)] = None
                continue
            handle_uids.add(uid)
            handle = po.FeatureHandle()
            handle.setMapIndex(map_index)
            handle.setUniqueId(uid)
            handle.setRT(float(row["rt"]))
            handle.setMZ(float(row["mz"]))
            handle.setIntensity(float(row["intensity"]))
            handle.setCharge(int(row["charge"]))
            feature = consensus_map[row_index]
            feature.insert(handle)
            consensus_map[row_index] = feature
            present[row_index].add(map_index)
            inserted[(sample["sample"], consensus_uid)] = uid
    return inserted


def verify_gapfilled(snapshot, consensus_map, samples, inserted):
    """Raise RuntimeError unless only the inserted fills were added."""
    if consensus_map.getUniqueId() != snapshot["map_uid"]:
        raise RuntimeError("Consensus map UID changed")
    headers = consensus_map.getColumnHeaders()
    if {
        index: (str(header.filename), str(header.label), header.size, header.unique_id)
        for index, header in headers.items()
    } != snapshot["headers"]:
        raise RuntimeError("Column headers changed")
    if [
        p.getIdentifier() for p in consensus_map.getProteinIdentifications()
    ] != snapshot["proteins"] or [
        peptide_signature(p)
        for p in consensus_map.getUnassignedPeptideIdentifications()
    ] != snapshot["unassigned"]:
        raise RuntimeError("Map-level identifications changed")
    if consensus_map.size() != len(snapshot["rows"]):
        raise RuntimeError("Number of consensus rows changed")
    index_by_sample = {sample["sample"]: sample["map_index"] for sample in samples}
    expected = {}
    for sample in samples:
        for row in sample["fills"]:
            uid = inserted.get((sample["sample"], int(row["consensus_uid"])))
            if uid is not None:
                expected[int(row["consensus_uid"])] = expected.get(
                    int(row["consensus_uid"]), set()
                ) | {
                    (
                        index_by_sample[sample["sample"]],
                        uid,
                        float(row["rt"]),
                        float(row["mz"]),
                        as_float32(float(row["intensity"])),
                        int(row["charge"]),
                    )
                }
    added_total = 0
    for before, feature in zip(snapshot["rows"], consensus_map):
        after = snapshot_consensus_row(feature)
        if after[:8] != before[:8]:
            raise RuntimeError(f"Consensus row {before[0]} changed")
        if not before[8] <= after[8]:
            raise RuntimeError(f"An original handle of row {before[0]} changed")
        added = after[8] - before[8]
        added_total += len(added)
        indices = [signature[0] for signature in after[8]]
        if len(indices) != len(set(indices)) or not set(indices) <= set(headers):
            raise RuntimeError(f"Row {before[0]} has an invalid set of map indexes")
        observed = {(sig[0], sig[1], sig[2], sig[3], sig[4], sig[5]) for sig in added}
        if observed != expected.get(before[0], set()):
            raise RuntimeError(f"Row {before[0]} received unexpected handles")
    if added_total != sum(1 for uid in inserted.values() if uid is not None):
        raise RuntimeError("Number of inserted handles is wrong")


def digest(value):
    """Compact fingerprint of metadata and identifications (keeps memory low)."""
    return hashlib.blake2b(repr(value).encode(), digest_size=16).digest()


def snapshot_consensus_row(feature):
    return (
        feature.getUniqueId(),
        feature.getMZ(),
        feature.getRT(),
        feature.getIntensity(),
        feature.getQuality(),
        feature.getCharge(),
        digest(metas(feature)),
        digest([peptide_signature(p) for p in feature.getPeptideIdentifications()]),
        frozenset(handle_signature(h) for h in feature.getFeatureList()),
    )


def apply_duplicate_identity(samples, inserted):
    """Turn accepted targets whose fill UID collided into rejections."""
    for sample in samples:
        for row in sample["candidates"]:
            key = (sample["sample"], int(row["consensus_uid"]))
            if row["status"] != "accepted":
                row["fill_feature_uid"] = ""
                continue
            uid = inserted[key]
            if uid is None:
                row["status"] = "rejected"
                row["rejection_reason"] = "duplicate_feature_identity"
                row["failed_checks"] = "duplicate_feature_identity"
                row["exported_intensity"] = ""
                row["fill_feature_uid"] = ""
            else:
                row["fill_feature_uid"] = str(uid)


def cell_state(row):
    if row["status"] == "accepted":
        return "requantified"
    if row["status"] == "no_candidate":
        return "missing_no_candidate"
    if row["rejection_reason"] == "existing_signal_overlap":
        return "missing_existing_signal_overlap"
    return "missing_failed_qc"


def mask_rows(consensus_map, samples):
    """Header and rows of the requantification mask, in consensus order."""
    headers = consensus_map.getColumnHeaders()
    map_indices = sorted(headers)
    states = {}
    for sample in samples:
        for row in sample["candidates"]:
            states[(int(row["consensus_uid"]), sample["map_index"])] = cell_state(row)
    columns = ["consensus_index", "consensus_uid"] + [
        str(headers[index].filename) for index in map_indices
    ]
    rows = []
    for consensus_index, feature in enumerate(consensus_map):
        uid = feature.getUniqueId()
        present = {handle.getMapIndex() for handle in feature.getFeatureList()}
        cells = []
        for index in map_indices:
            state = states.get((uid, index), "observed")
            if (state in ("observed", "requantified")) != (index in present):
                raise RuntimeError(
                    f"Mask and handles disagree for row {uid}, map {index}"
                )
            cells.append(state)
        rows.append([consensus_index, uid, *cells])
    return columns, rows


def provenance_rows(samples):
    """All candidate rows sorted by (sample, consensus_index)."""
    rows = [row for sample in samples for row in sample["candidates"]]
    return sorted(rows, key=lambda row: (row["sample"], int(row["consensus_index"])))


def summary_rows(consensus_map, samples):
    rows = []
    total = Counter()
    for sample in sorted(samples, key=lambda item: item["sample"]):
        counts = Counter()
        for row in sample["candidates"]:
            counts[row["status"]] += 1
            if row["status"] == "rejected":
                counts[f"rejected_{row['rejection_reason']}"] += 1
        targets = len(sample["candidates"])
        row = {
            "sample": sample["sample"],
            "consensus_rows": consensus_map.size(),
            "observed": consensus_map.size() - targets,
            "targets_requested": targets,
            "candidates_recovered": targets - counts["no_candidate"],
            "accepted": counts["accepted"],
            "rejected": counts["rejected"],
            "no_candidate": counts["no_candidate"],
            "missing_after": targets - counts["accepted"],
        }
        for reason in CHECK_ORDER:
            row[f"rejected_{reason}"] = counts[f"rejected_{reason}"]
        rows.append(row)
        total.update({key: value for key, value in row.items() if key != "sample"})
    total_row = {"sample": "all", **total}
    total_row["consensus_rows"] = consensus_map.size()
    rows.append(total_row)
    return rows


def add_processing_entry(consensus_map):
    processing = po.DataProcessing()
    software = po.Software()
    software.setName(PROCESSING_NAME)
    processing.setSoftware(software)
    processing.setProcessingActions({po.DataProcessing.ProcessingAction.QUANTITATION})
    processing.setCompletionTime(po.DateTime.now())
    consensus_map.setDataProcessing([*consensus_map.getDataProcessing(), processing])


def write_rows(path, columns, rows):
    with open(path, "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
        writer.writerow(columns)
        writer.writerows(rows)


def write_dicts(path, columns, rows):
    with open(path, "w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle, fieldnames=columns, delimiter="\t", lineterminator="\n"
        )
        writer.writeheader()
        writer.writerows(rows)


def main(argv=None):
    args = parse_args(argv)
    samples, candidate_columns = read_sample_tables(args.sample_tables)
    consensus_map = po.ConsensusMap()
    po.ConsensusXMLFile().load(args.consensus, consensus_map)
    resolve_sample_indices(consensus_map, samples)

    snapshot = snapshot_consensus(consensus_map)
    inserted = insert_fills(consensus_map, samples)
    verify_gapfilled(snapshot, consensus_map, samples, inserted)
    apply_duplicate_identity(samples, inserted)
    add_processing_entry(consensus_map)
    if len(consensus_map.getDataProcessing()) != snapshot["processing"] + 1:
        raise RuntimeError("Data processing entries changed unexpectedly")
    po.ConsensusXMLFile().store(args.output_consensus, consensus_map)

    mask_columns, mask = mask_rows(consensus_map, samples)
    write_rows(args.mask, mask_columns, mask)
    write_dicts(args.provenance, candidate_columns, provenance_rows(samples))
    write_dicts(args.summary, SUMMARY_COLUMNS, summary_rows(consensus_map, samples))
    filled = sum(1 for uid in inserted.values() if uid is not None)
    print(f"Inserted {filled} fills into {consensus_map.size()} consensus rows")


if __name__ == "__main__":
    main()
