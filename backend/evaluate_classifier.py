"""Evaluate actual predictions and abstention on a patient-separated held-out split."""

import argparse
import json
from pathlib import Path

import numpy as np

from backend.app import decode_image
from backend.classification import LABELS, Classifier
from backend.dataset import read_manifest


def metrics(truth: list[str], predictions: list[str], labels: list[str]) -> dict:
    if not truth or len(truth) != len(predictions):
        raise ValueError(
            "Evaluation requires matching, nonempty ground truth and predictions."
        )
    confusion = np.zeros((len(labels), len(labels) + 1), dtype=int)
    for target, predicted in zip(truth, predictions, strict=True):
        confusion[
            labels.index(target),
            labels.index(predicted) if predicted in labels else len(labels),
        ] += 1
    accepted = confusion[:, :-1].sum()
    correct = np.trace(confusion[:, :-1])
    per_class = {}
    for i, label in enumerate(labels):
        tp = int(confusion[i, i])
        support = int(confusion[i].sum())
        recall = tp / support if support else None
        predicted = int(confusion[:, i].sum())
        precision = tp / predicted if predicted else None
        f1 = 2 * tp / (support + predicted) if support + predicted else None
        per_class[label] = {
            "support": support,
            "precision": precision,
            "recall": recall,
            "f1": f1,
        }
    recalls = [m["recall"] for m in per_class.values() if m["recall"] is not None]
    f1s = [m["f1"] for m in per_class.values() if m["support"] > 0]
    return {
        "count": len(truth),
        "accuracyIncludingAbstentions": float(correct / len(truth)),
        "coverage": float(accepted / len(truth)),
        "accuracyWhenAccepted": float(correct / accepted) if accepted else None,
        "balancedAccuracy": float(np.mean(recalls)),
        "macroF1PresentClasses": float(np.mean(f1s)),
        "labels": labels,
        "confusionColumns": [*labels, "Unclassified"],
        "confusionMatrix": confusion.tolist(),
        "perClass": per_class,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--model", default="models/classifier")
    parser.add_argument("--split", choices=["validation", "test"], default="test")
    parser.add_argument("--device", default="cpu")
    parser.add_argument(
        "--output", type=Path, default=Path("private_data/evaluation.json")
    )
    args = parser.parse_args()
    rows = [
        row
        for row in read_manifest(args.manifest, args.data_root)
        if row["split"] == args.split
    ]
    if not rows:
        parser.error("No images in requested split.")
    classifier = Classifier(args.model, args.device)
    truth, predicted = [], []
    for index, row in enumerate(rows, 1):
        image = decode_image(row["path"].read_bytes())
        result = classifier.predict(image, (0, 0, image.shape[1], image.shape[0]))
        truth.append(LABELS[row["label"]])
        predicted.append(result["label"])
        print(f"Evaluated {index}/{len(rows)}", end="\r")
    report = metrics(truth, predicted, list(LABELS.values()))
    report.update(
        {
            "source": classifier.source,
            "split": args.split,
            "clinicalValidation": False,
            "protocol": "Full-image inputs; app ROI selection and segmentation require separate evaluation. Pretraining dataset overlap is unknown.",
        }
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
