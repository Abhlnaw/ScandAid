import json

import pytest

from backend.dataset import read_manifest
from backend.evaluate_classifier import metrics


def manifest(tmp_path, rows):
    path = tmp_path / "labels.csv"
    path.write_text("path,label,patient_id,split\n" + "\n".join(rows))
    return path


def test_manifest_rejects_patient_leakage(tmp_path):
    (tmp_path / "a.jpg").write_bytes(b"image one")
    (tmp_path / "b.jpg").write_bytes(b"image two")
    path = manifest(tmp_path, ["a.jpg,Cut,p1,train", "b.jpg,Cut,p1,test"])
    with pytest.raises(ValueError, match="multiple splits"):
        read_manifest(path, tmp_path)


def test_manifest_rejects_duplicate_images_across_splits(tmp_path):
    for name in ["a.jpg", "b.jpg"]:
        (tmp_path / name).write_bytes(b"identical image bytes")
    path = manifest(tmp_path, ["a.jpg,Cut,p1,train", "b.jpg,Cut,p2,test"])
    with pytest.raises(ValueError, match="Identical image bytes"):
        read_manifest(path, tmp_path)


def test_manifest_accepts_separated_patients_and_valid_taxonomy(tmp_path):
    (tmp_path / "a.jpg").write_bytes(b"one")
    (tmp_path / "b.jpg").write_bytes(b"two")
    path = manifest(tmp_path, ["a.jpg,Cut,p1,train", "b.jpg,Burns,p2,test"])
    assert len(read_manifest(path, tmp_path)) == 2


def test_metrics_count_abstention_as_missed_ground_truth():
    report = metrics(
        ["Cut", "Cut", "Burn"], ["Cut", "Unclassified", "Cut"], ["Cut", "Burn"]
    )
    assert report["coverage"] == pytest.approx(2 / 3)
    assert report["accuracyWhenAccepted"] == 0.5
    assert report["accuracyIncludingAbstentions"] == pytest.approx(1 / 3)
    assert report["confusionMatrix"] == [[1, 0, 1], [1, 0, 0]]
    assert report["perClass"]["Cut"]["recall"] == 0.5
    assert json.loads(json.dumps(report))["count"] == 3


def test_all_abstentions_do_not_report_perfect_accuracy():
    report = metrics(["Cut"], ["Unclassified"], ["Cut", "Burn"])
    assert report["accuracyWhenAccepted"] is None
    assert report["accuracyIncludingAbstentions"] == 0
    assert report["coverage"] == 0
