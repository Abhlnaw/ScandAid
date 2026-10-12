"""Real ViT inference with quality checks and explicit abstention. No severity inference."""

import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

MODEL_ID = "Hemgg/wound-image-classification"
MODEL_REVISION = "a5b5b23a48c8cb669d1763039426c86c59eec8e0"
LABELS = {
    "Abrasions": "Abrasion",
    "Bruises": "Bruise",
    "Burns": "Burn",
    "Cut": "Cut",
    "Laseration": "Laceration",
    "Diabetic Wounds": "Diabetic wound appearance",
    "Normal": "No wound appearance",
    "Pressure Wounds": "Pressure wound appearance",
    "Surgical Wounds": "Surgical wound appearance",
    "Venous Wounds": "Venous wound appearance",
}


def abstention(
    reason: str, source: str = "No classification model", scores: dict | None = None
):
    return {
        "label": "Unclassified",
        "scores": scores or {},
        "source": source,
        "reason": reason,
        "abstained": True,
    }


def rank_prediction(
    probabilities, labels, source, minimum=0.70, margin=0.15, reason=None
):
    values = np.asarray(probabilities, dtype=float)
    if (
        len(values) != len(labels)
        or len(values) < 2
        or not np.all(np.isfinite(values))
        or np.any(values < 0)
        or not np.isclose(values.sum(), 1, atol=0.001)
    ):
        raise ValueError("Invalid classifier probabilities.")
    ranked = np.argsort(values)[::-1]
    scores = {labels[int(i)]: float(values[i]) for i in ranked}
    if (
        reason
        or values[ranked[0]] < minimum
        or values[ranked[0]] - values[ranked[1]] < margin
    ):
        return abstention(
            reason
            or "The model could not distinguish a wound type reliably. No diagnosis can be made from this result.",
            source,
            scores,
        )
    label = labels[int(ranked[0])]
    # Etiology depends on clinical history; the model can only suggest appearance.
    return {
        "label": label,
        "scores": scores,
        "source": source,
        "reason": "Experimental visual prediction. A clinician must establish wound type and cause.",
        "abstained": False,
    }


def quality_issue(image: np.ndarray) -> str | None:
    if min(image.shape[:2]) < 32:
        return "The selected region is too small. Retake the photo closer to the wound."
    gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
    channel_range = image.max(axis=2).astype(float) - image.min(axis=2).astype(float)
    if np.percentile(channel_range, 95) < 8:
        return "This looks like a grayscale image. The classifier expects a color photograph of skin."
    if gray.mean() < 20 or gray.mean() > 240:
        return "The selected region is underexposed or overexposed. Use even lighting."
    if gray.std() < 4 or cv2.Laplacian(gray, cv2.CV_64F).var() < 6:
        return "The selected region has insufficient detail. Refocus the camera and retake the photo."
    return None


class Classifier:
    def __init__(self, model_path: str | None = None, device: str = "cpu"):
        self.model = None
        self.source = "No classification model"
        self.device = device
        if model_path:
            if not Path(model_path).is_dir():
                raise FileNotFoundError(f"Classifier folder not found: {model_path}")
            from transformers import AutoImageProcessor, AutoModelForImageClassification

            self.processor = AutoImageProcessor.from_pretrained(
                model_path,
                local_files_only=True,
                trust_remote_code=False,
                use_fast=False,
            )
            self.model = (
                AutoModelForImageClassification.from_pretrained(
                    model_path,
                    local_files_only=True,
                    trust_remote_code=False,
                    use_safetensors=True,
                )
                .to(device)
                .eval()
            )
            raw_labels = [
                self.model.config.id2label[i]
                for i in range(self.model.config.num_labels)
            ]
            if any(label not in LABELS for label in raw_labels):
                raise ValueError(
                    "Classifier label map is unsupported. Supply an explicitly reviewed taxonomy."
                )
            self.labels = [LABELS[label] for label in raw_labels]
            self.source = f"{MODEL_ID}@{MODEL_REVISION[:12]} (experimental)"
            metadata = Path(model_path) / "scandaid_model.json"
            if metadata.is_file():
                self.source = json.loads(metadata.read_text())["source"]

    def predict(self, image: np.ndarray, box) -> dict:
        if self.model is None:
            return abstention(
                "No classifier weights loaded. Run backend.download_models, then restart the server."
            )
        import torch

        x0, y0, x1, y1 = box
        # Include context around the selection; do not black out skin and create a new image distribution.
        margin_x, margin_y = round((x1 - x0) * 0.15), round((y1 - y0) * 0.15)
        crop = image[
            max(0, y0 - margin_y) : min(image.shape[0], y1 + margin_y),
            max(0, x0 - margin_x) : min(image.shape[1], x1 + margin_x),
        ]
        issue = quality_issue(crop)
        if issue:
            return abstention(issue, self.source)
        # Agreement between full-image and selected-region predictions is a conservative
        # rejection rule, not a calibrated out-of-distribution detector.
        inputs = self.processor(
            images=[Image.fromarray(crop), Image.fromarray(image)], return_tensors="pt"
        ).to(self.device)
        with torch.inference_mode():
            predictions = self.model(**inputs).logits.softmax(dim=-1).cpu().numpy()
        disagreement = int(predictions[0].argmax()) != int(predictions[1].argmax())
        return rank_prediction(
            predictions.mean(axis=0),
            self.labels,
            self.source,
            reason="Full photo and selected-region predictions disagree. Refine the selection or seek professional assessment."
            if disagreement
            else None,
        )
