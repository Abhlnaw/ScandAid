"""Local inference API. Launch with python -m uvicorn backend.app:app."""

import asyncio
import io
import logging
import os
import threading
import warnings
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Annotated

import cv2
import numpy as np
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image, ImageOps, UnidentifiedImageError
from starlette.concurrency import run_in_threadpool
from starlette.formparsers import MultiPartParser

from backend.classification import Classifier, abstention
from backend.geometry import encode_mask, mask_metrics, parse_box, polygon_mask
from backend.limits import RequestSizeLimit
from backend.segmentation import Segmenter

ROOT = Path(__file__).resolve().parent.parent
MAX_BYTES = 12 * 1024 * 1024
# Total request size is bounded before parsing, so uploaded photos stay in RAM.
MultiPartParser.spool_max_size = MAX_BYTES + 65536
Image.MAX_IMAGE_PIXELS = 16_000_000
logger = logging.getLogger(__name__)


class Engine:
    def __init__(self):
        device = os.environ.get("SCAN_DEVICE", "cpu")
        checkpoint = os.environ.get("MEDSAM_CHECKPOINT")
        default_checkpoint = ROOT / "models" / "medsam_vit_b.pth"
        if checkpoint is None and default_checkpoint.is_file():
            checkpoint = str(default_checkpoint)
        classifier_path = os.environ.get("CLASSIFIER_PATH")
        default_classifier = ROOT / "models" / "classifier"
        if (
            classifier_path is None
            and (default_classifier / "model.safetensors").is_file()
        ):
            classifier_path = str(default_classifier)
        self.segmenter = Segmenter(checkpoint, device)
        self.classifier = Classifier(classifier_path, device)
        self.lock = threading.Lock()

    def analyze(self, image, box, outline):
        with self.lock:
            mask = polygon_mask(outline, image.shape[1], image.shape[0])
            source = "Manual outline"
            if mask is None:
                mask = self.segmenter.predict(image, box)
                source = self.segmenter.source
            metrics = mask_metrics(mask)
            # Classify the region actually retained by the segmentation.
            b = metrics["bounds"]
            try:
                classification = self.classifier.predict(image, b)
            except Exception:
                logger.exception(
                    "Classifier inference failed; returning an explicit abstention."
                )
                classification = abstention(
                    "Classification failed. The reviewed segmentation can still be saved.",
                    self.classifier.source,
                )
            red = (
                (image[:, :, 0] > image[:, :, 1].astype(float) * 1.25)
                & (image[:, :, 0] > image[:, :, 2].astype(float) * 1.25)
                & (image[:, :, 0] > 60)
            )
            return {
                "version": 1,
                "segmentation": {
                    **metrics,
                    "source": source,
                    "maskPng": encode_mask(mask),
                },
                "classification": classification,
                "redPixelFraction": float(red[mask].mean()),
            }


@asynccontextmanager
async def lifespan(app):
    if not hasattr(app.state, "engine"):
        app.state.engine = await run_in_threadpool(Engine)
    app.state.gate = asyncio.Semaphore(2)
    yield


app = FastAPI(title="ScandAid local inference", version="1.0.0", lifespan=lifespan)
app.add_middleware(RequestSizeLimit, max_bytes=MAX_BYTES + 65536)
origins = os.environ.get(
    "SCAN_ALLOWED_ORIGINS", "http://localhost:5173,http://127.0.0.1:5173"
).split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)


@app.get("/health")
def health():
    engine = app.state.engine
    return {
        "status": "ok",
        "version": 1,
        "segmentation": engine.segmenter.source,
        "classification": engine.classifier.source,
        "clinicalValidation": False,
    }


def decode_image(data):
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(data)) as original:
                if original.format not in {"JPEG", "PNG", "WEBP"}:
                    raise ValueError("Use a JPEG, PNG or WebP photo.")
                image = ImageOps.exif_transpose(original).convert("RGB")
                if min(image.size) < 32 or max(image.size) > 4096:
                    raise ValueError(
                        "Photo dimensions must be between 32 and 4096 pixels."
                    )
                return np.asarray(image).copy()
    except (
        UnidentifiedImageError,
        Image.DecompressionBombError,
        Image.DecompressionBombWarning,
        OSError,
    ) as exc:
        raise ValueError(
            "Photo could not be decoded or exceeds the image size limit."
        ) from exc


@app.post("/analyze")
async def analyze(
    image: Annotated[UploadFile, File()],
    box: Annotated[str, Form()],
    outline: Annotated[str, Form()] = "[]",
):
    if len(box) > 256 or len(outline) > 30000:
        raise HTTPException(422, "Region selection is too large.")
    try:
        data = await image.read(MAX_BYTES + 1)
    finally:
        await image.close()
    if len(data) > MAX_BYTES:
        raise HTTPException(413, "Photo exceeds the 12 MB upload limit.")
    if app.state.gate.locked():
        raise HTTPException(429, "Inference server is busy. Try again shortly.")
    async with app.state.gate:
        try:
            rgb = await run_in_threadpool(decode_image, data)
            bounds = parse_box(box, rgb.shape[1], rgb.shape[0])
            return await run_in_threadpool(
                app.state.engine.analyze, rgb, bounds, outline
            )
        except (ValueError, TypeError, IndexError) as exc:
            raise HTTPException(422, str(exc)) from exc
        except cv2.error as exc:
            raise HTTPException(
                422,
                "Could not isolate this region. Use a manual outline or a tighter box.",
            ) from exc
        except Exception as exc:
            logger.exception("Segmentation failed.")
            raise HTTPException(
                503,
                "Segmentation is unavailable. Use an offline manual outline or retry.",
            ) from exc


# Serve the built Flutter app from the same origin; API routes above take precedence.
web_build = ROOT / "build" / "web"
if (web_build / "index.html").is_file():
    from fastapi.staticfiles import StaticFiles

    app.mount("/", StaticFiles(directory=web_build, html=True), name="web")
