import base64
import io
import json

import numpy as np
import pytest
from fastapi.testclient import TestClient
from PIL import Image

from backend.app import Engine, app, decode_image
from backend.classification import Classifier, quality_issue, rank_prediction
from backend.geometry import encode_mask, mask_metrics, parse_box, polygon_mask
from backend.segmentation import Segmenter


def photo():
    image = Image.new("RGB", (120, 80), (195, 150, 120))
    for x in range(40, 80):
        for y in range(25, 55):
            image.putpixel((x, y), (125, 30, 35))
    buf = io.BytesIO()
    image.save(buf, format="PNG")
    return buf.getvalue()


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv("CLASSIFIER_PATH", "")
    monkeypatch.setenv("MEDSAM_CHECKPOINT", "")
    app.state.engine = Engine()
    with TestClient(app) as client:
        yield client
    del app.state.engine


def test_manual_area_matches_offline_pixel_center_rule():
    outline = json.dumps([[0.25, 0.25], [0.75, 0.25], [0.75, 0.75], [0.25, 0.75]])
    mask = polygon_mask(outline, 120, 80)
    assert mask_metrics(mask) == {"areaPixels": 2400, "bounds": [30, 20, 90, 60]}
    decoded = np.asarray(Image.open(io.BytesIO(base64.b64decode(encode_mask(mask)))))
    assert int((decoded[:, :, 3] > 0).sum()) == 2400
    assert (decoded[~mask] == 0).all()


@pytest.mark.parametrize(
    "raw",
    [
        "null",
        "{}",
        "[0,0,1]",
        "[0,0,0,1]",
        "[-1,0,1,1]",
        '[0,0,"x",1]',
        "[0,0,NaN,1]",
        "[false,0,1,1]",
    ],
)
def test_rejects_invalid_box(raw):
    with pytest.raises((ValueError, TypeError)):
        parse_box(raw, 120, 80)


@pytest.mark.parametrize(
    "raw",
    [
        "[[0,0],[1,1]]",
        "[[0,0],[1,1],[NaN,0]]",
        '{"a": 1}',
        "[[0,0],[1,1],[-1,0]]",
        "[[0,0],[1,1],[1,0],[0,1]]",
    ],
)
def test_rejects_invalid_outline(raw):
    with pytest.raises(ValueError):
        polygon_mask(raw, 100, 100)


def test_missing_weights_never_produces_fake_classification():
    result = Classifier().predict(np.zeros((100, 100, 3), np.uint8), (0, 0, 100, 100))
    assert (
        result["abstained"]
        and result["scores"] == {}
        and result["label"] == "Unclassified"
    )


def test_low_confidence_and_ambiguous_predictions_abstain():
    assert rank_prediction([0.51, 0.49], ["Cut", "Burn"], "test")["abstained"]
    assert rank_prediction([0.69, 0.31], ["Cut", "Burn"], "test")["abstained"]
    assert not rank_prediction([0.85, 0.15], ["Cut", "Burn"], "test")["abstained"]
    assert rank_prediction(
        [0.99, 0.01], ["Cut", "Burn"], "test", reason="View disagreement"
    )["abstained"]


def test_invalid_scores_are_rejected():
    with pytest.raises(ValueError):
        rank_prediction([float("nan"), 0], ["Cut", "Burn"], "test")


def test_quality_gate_rejects_blank_and_tiny_inputs():
    assert quality_issue(np.full((100, 100, 3), 255, np.uint8))
    assert quality_issue(np.full((100, 100, 3), 100, np.uint8))
    assert quality_issue(np.zeros((10, 10, 3), np.uint8))


def test_decode_rejects_invalid_and_large_dimensions():
    with pytest.raises(ValueError):
        decode_image(b"not an image")
    stream = io.BytesIO()
    Image.new("RGB", (5000, 40)).save(stream, "PNG")
    with pytest.raises(ValueError):
        decode_image(stream.getvalue())


def test_classical_segmentation_tracks_foreground_pixels():
    rgb = decode_image(photo())
    mask = Segmenter().predict(rgb, (30, 15, 90, 65))
    assert 800 < mask.sum() < 1600
    assert not mask[:15].any() and not mask[:, :30].any()


def test_health_reports_actual_model_availability(client):
    data = client.get("/health").json()
    assert "GrabCut" in data["segmentation"]
    assert data["classification"] == "No classification model"
    assert data["clinicalValidation"] is False


def test_api_manual_outline_and_empty_classification(client):
    response = client.post(
        "/analyze",
        files={"image": ("photo.png", photo(), "image/png")},
        data={
            "box": "[0.25,0.25,0.75,0.75]",
            "outline": "[[0.25,0.25],[0.75,0.25],[0.75,0.75],[0.25,0.75]]",
        },
    )
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["segmentation"]["areaPixels"] == 2400
    assert data["classification"]["abstained"]
    assert data["segmentation"]["source"] == "Manual outline"
    assert 0 < data["redPixelFraction"] <= 1


def test_api_assisted_box(client):
    response = client.post(
        "/analyze",
        files={"image": ("photo.png", photo(), "image/png")},
        data={"box": "[0.25,0.2,0.75,0.8]"},
    )
    assert response.status_code == 200, response.text
    assert "GrabCut" in response.json()["segmentation"]["source"]


@pytest.mark.parametrize("box", ["not json", "[0,0,0,0]", "[0,0,NaN,1]"])
def test_api_returns_clear_selection_errors(client, box):
    response = client.post(
        "/analyze",
        files={"image": ("photo.png", photo(), "image/png")},
        data={"box": box},
    )
    assert response.status_code == 422


def test_api_unreadable_image(client):
    response = client.post(
        "/analyze",
        files={"image": ("bad.png", b"bad", "image/png")},
        data={"box": "[0,0,1,1]"},
    )
    assert response.status_code == 422


def test_api_rejects_oversized_upload_before_parsing(client):
    response = client.post("/analyze", content=b"x" * (12 * 1024 * 1024 + 65537))
    assert response.status_code == 413


def test_api_grayscale_images_abstain_before_classifier(client):
    image = np.zeros((100, 100, 3), dtype=np.uint8)
    image[25:75] = 190
    assert "grayscale" in quality_issue(image)


def test_classification_failure_preserves_segmentation(client, monkeypatch):
    def fail(*args):
        raise RuntimeError("Simulated model failure")

    monkeypatch.setattr(app.state.engine.classifier, "predict", fail)
    response = client.post(
        "/analyze",
        files={"image": ("photo.png", photo(), "image/png")},
        data={"box": "[0.25,0.2,0.75,0.8]"},
    )
    assert response.status_code == 200
    assert response.json()["classification"]["abstained"]
    assert response.json()["classification"]["scores"] == {}
