"""Fine-tune the reviewed 10-label ViT on locally supplied, patient-separated data."""

import argparse
import json
import random
from collections import Counter
from pathlib import Path

import numpy as np
import torch
from PIL import Image, ImageOps
from torch.utils.data import DataLoader, Dataset
from torchvision.transforms import (
    ColorJitter,
    Compose,
    RandomHorizontalFlip,
    RandomRotation,
)
from transformers import AutoImageProcessor, AutoModelForImageClassification

from backend.classification import LABELS, MODEL_ID, MODEL_REVISION
from backend.dataset import read_manifest


class Images(Dataset):
    def __init__(self, rows, processor, label2id, augment=False):
        self.rows, self.processor, self.label2id = rows, processor, label2id
        self.augment = (
            Compose(
                [
                    RandomHorizontalFlip(),
                    RandomRotation(10),
                    ColorJitter(brightness=0.1, contrast=0.1),
                ]
            )
            if augment
            else None
        )

    def __len__(self):
        return len(self.rows)

    def __getitem__(self, index):
        row = self.rows[index]
        with Image.open(row["path"]) as source:
            image = ImageOps.exif_transpose(source).convert("RGB")
        if self.augment:
            image = self.augment(image)
        pixels = self.processor(images=image, return_tensors="pt")["pixel_values"][0]
        return pixels, self.label2id[row["label"]]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--data-root", required=True, type=Path)
    parser.add_argument("--base", default="models/classifier")
    parser.add_argument("--output", default=Path("models/custom-classifier"), type=Path)
    parser.add_argument("--epochs", default=15, type=int)
    parser.add_argument("--batch-size", default=8, type=int)
    parser.add_argument("--learning-rate", default=2e-5, type=float)
    parser.add_argument("--device", default="cpu")
    args = parser.parse_args()
    if args.output.resolve() == Path(args.base).resolve():
        parser.error(
            "Use a separate output folder; the baseline must remain reproducible."
        )
    if args.epochs < 1 or args.batch_size < 1 or not 0 < args.learning_rate < 1:
        parser.error("Use positive epochs, batch size, and a learning rate below 1.")
    rows = read_manifest(args.manifest, args.data_root)
    train = [r for r in rows if r["split"] == "train"]
    validation = [r for r in rows if r["split"] == "validation"]
    for subset in [train, validation]:
        if {r["label"] for r in subset} != set(LABELS):
            parser.error(
                "Both train and validation must contain every reviewed class. Do not invent or silently omit labels."
            )
    random.seed(42)
    np.random.seed(42)
    torch.manual_seed(42)
    processor = AutoImageProcessor.from_pretrained(
        args.base, local_files_only=True, use_fast=False
    )
    model = AutoModelForImageClassification.from_pretrained(
        args.base, local_files_only=True, use_safetensors=True
    ).to(args.device)
    label2id = {label: int(index) for index, label in model.config.id2label.items()}
    if set(label2id) != set(LABELS):
        parser.error("Base model must use the reviewed 10-label taxonomy.")
    counts = Counter(r["label"] for r in train)
    weights = torch.tensor(
        [
            len(train) / (len(LABELS) * counts[model.config.id2label[i]])
            for i in range(len(LABELS))
        ],
        device=args.device,
    )
    loss_fn = torch.nn.CrossEntropyLoss(weight=weights)
    optimizer = torch.optim.AdamW(
        model.parameters(), lr=args.learning_rate, weight_decay=0.01
    )
    train_loader = DataLoader(
        Images(train, processor, label2id, augment=True),
        batch_size=args.batch_size,
        shuffle=True,
    )
    val_loader = DataLoader(
        Images(validation, processor, label2id), batch_size=args.batch_size
    )
    best, stale, history = float("inf"), 0, []
    args.output.mkdir(parents=True, exist_ok=True)
    for epoch in range(args.epochs):
        model.train()
        train_loss = 0.0
        for pixels, targets in train_loader:
            optimizer.zero_grad(set_to_none=True)
            logits = model(pixel_values=pixels.to(args.device)).logits
            loss = loss_fn(logits, targets.to(args.device))
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1)
            optimizer.step()
            train_loss += loss.item() * len(targets)
        model.eval()
        total_loss = 0.0
        with torch.inference_mode():
            for pixels, targets in val_loader:
                logits = model(pixel_values=pixels.to(args.device)).logits
                # Unweighted validation loss keeps model selection comparable across runs.
                total_loss += torch.nn.functional.cross_entropy(
                    logits, targets.to(args.device), reduction="sum"
                ).item()
        val_loss = total_loss / len(validation)
        history.append(
            {
                "epoch": epoch + 1,
                "trainLoss": train_loss / len(train),
                "validationLoss": val_loss,
            }
        )
        print(json.dumps(history[-1]))
        if val_loss < best:
            best, stale = val_loss, 0
            model.save_pretrained(args.output, safe_serialization=True)
            processor.save_pretrained(args.output)
        else:
            stale += 1
        if stale >= 3:
            break
    provenance = {
        "source": "Locally fine-tuned wound ViT (experimental)",
        "baseRepository": MODEL_ID,
        "baseRevision": MODEL_REVISION,
        "seed": 42,
        "trainImages": len(train),
        "validationImages": len(validation),
        "patientSeparated": True,
        "clinicalValidation": False,
        "history": history,
    }
    (args.output / "scandaid_model.json").write_text(json.dumps(provenance, indent=2))
    print(
        "Saved best validation checkpoint. Evaluate the untouched test split before using it."
    )


if __name__ == "__main__":
    main()
