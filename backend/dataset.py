"""Audit a user-supplied labeled manifest before training or evaluation."""

import csv
import hashlib
from pathlib import Path

from backend.classification import LABELS


def read_manifest(manifest: Path, root: Path) -> list[dict]:
    root = root.resolve()
    rows = []
    groups, images, paths = {}, {}, set()
    with manifest.open(newline="", encoding="utf-8-sig") as stream:
        reader = csv.DictReader(stream)
        if not {"path", "label", "patient_id", "split"} <= set(reader.fieldnames or []):
            raise ValueError("Manifest needs path,label,patient_id,split columns.")
        for line, row in enumerate(reader, 2):
            label, group, split = (
                row["label"].strip(),
                row["patient_id"].strip(),
                row["split"].strip(),
            )
            if (
                label not in LABELS
                or split not in {"train", "validation", "test"}
                or not group
            ):
                raise ValueError(f"Invalid label, patient_id or split on line {line}.")
            path = (root / row["path"]).resolve()
            if not path.is_relative_to(root) or not path.is_file():
                raise ValueError(
                    f"Image on line {line} must exist inside the dataset root."
                )
            if path in paths:
                raise ValueError(f"Duplicate image path on line {line}.")
            paths.add(path)
            if group in groups and groups[group] != split:
                raise ValueError(f"Patient group {group} appears in multiple splits.")
            groups[group] = split
            fingerprint = hashlib.sha256(path.read_bytes()).hexdigest()
            if fingerprint in images and images[fingerprint] != split:
                raise ValueError(
                    "Identical image bytes occur across splits. Remove duplicated or leaked images."
                )
            images[fingerprint] = split
            rows.append(
                {
                    "path": path,
                    "label": label,
                    "patient_id": group,
                    "split": split,
                    "sha256": fingerprint,
                }
            )
    if not rows:
        raise ValueError("Dataset manifest is empty.")
    return rows
