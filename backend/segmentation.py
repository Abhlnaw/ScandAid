"""Prompted masks using original MedSAM preprocessing, or explicitly named GrabCut."""

from pathlib import Path

import cv2
import numpy as np


class Segmenter:
    def __init__(self, checkpoint: str | None = None, device: str = "cpu"):
        self.model = None
        self.device = device
        self.source = "GrabCut (classical, not MedSAM)"
        if checkpoint:
            if not Path(checkpoint).is_file():
                raise FileNotFoundError(f"MedSAM checkpoint not found: {checkpoint}")
            import torch
            from segment_anything import sam_model_registry

            # Load tensor-only state dictionaries. Do not execute checkpoint pickle code.
            model = sam_model_registry["vit_b"]()
            model.load_state_dict(
                torch.load(checkpoint, map_location="cpu", weights_only=True)
            )
            self.model = model.to(device).eval()
            self.source = "MedSAM ViT-B"

    def predict(self, image: np.ndarray, box: tuple[int, int, int, int]) -> np.ndarray:
        if self.model is not None:
            return self._medsam(image, box)
        return self._grabcut(image, box)

    def _medsam(self, image, box):
        import torch
        from skimage.transform import resize
        from torch.nn import functional

        height, width = image.shape[:2]
        # MedSAM_Inference.py uses a square cubic resize, min/max normalization,
        # and independently scaled x/y box coordinates (not SAM's padded resize).
        resized = resize(
            image, (1024, 1024), order=3, preserve_range=True, anti_aliasing=True
        ).astype(np.uint8)
        normalized = (resized - resized.min()) / max(
            float(resized.max()) - float(resized.min()), 1e-8
        )
        pixels = torch.as_tensor(
            normalized, dtype=torch.float32, device=self.device
        ).permute(2, 0, 1)[None]
        coords = (
            np.asarray(box, dtype=np.float32) / [width, height, width, height] * 1024
        )
        boxes = torch.as_tensor(coords, dtype=torch.float32, device=self.device)[
            None, None, :
        ]
        with torch.inference_mode():
            embedding = self.model.image_encoder(pixels)
            sparse, dense = self.model.prompt_encoder(
                points=None, boxes=boxes, masks=None
            )
            logits, _ = self.model.mask_decoder(
                image_embeddings=embedding,
                image_pe=self.model.prompt_encoder.get_dense_pe(),
                sparse_prompt_embeddings=sparse,
                dense_prompt_embeddings=dense,
                multimask_output=False,
            )
            probability = functional.interpolate(
                logits.sigmoid(), (height, width), mode="bilinear", align_corners=False
            )
        mask = probability.squeeze().cpu().numpy() > 0.5
        # The prompt is the user's maximum region of interest.
        roi = np.zeros((height, width), dtype=bool)
        x0, y0, x1, y1 = box
        roi[y0:y1, x0:x1] = True
        return mask & roi

    @staticmethod
    def _grabcut(image, box):
        height, width = image.shape[:2]
        x0, y0, x1, y1 = box
        # Downscale for bounded CPU time, pad so even edge-touching boxes have background.
        scale = min(1.0, 640 / max(width, height))
        small = cv2.resize(
            image, (max(3, round(width * scale)), max(3, round(height * scale)))
        )
        small = cv2.copyMakeBorder(small, 2, 2, 2, 2, cv2.BORDER_REPLICATE)
        sx0, sy0 = round(x0 * scale) + 2, round(y0 * scale) + 2
        sx1, sy1 = round(x1 * scale) + 2, round(y1 * scale) + 2
        mask = np.zeros(small.shape[:2], np.uint8)
        background = np.zeros((1, 65), np.float64)
        foreground = np.zeros((1, 65), np.float64)
        cv2.setRNGSeed(42)
        cv2.grabCut(
            small,
            mask,
            (sx0, sy0, max(1, sx1 - sx0), max(1, sy1 - sy0)),
            background,
            foreground,
            5,
            cv2.GC_INIT_WITH_RECT,
        )
        binary = np.isin(mask[2:-2, 2:-2], [cv2.GC_FGD, cv2.GC_PR_FGD]).astype(np.uint8)
        binary = cv2.resize(
            binary, (width, height), interpolation=cv2.INTER_NEAREST
        ).astype(bool)
        roi = np.zeros((height, width), dtype=bool)
        roi[y0:y1, x0:x1] = True
        return binary & roi
