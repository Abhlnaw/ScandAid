"""Coordinate validation and pixel-center polygon rasterization."""

import base64
import io
import json
import math

import numpy as np
from PIL import Image


def parse_box(raw: str, width: int, height: int) -> tuple[int, int, int, int]:
    values = json.loads(raw)
    if not isinstance(values, list) or len(values) != 4:
        raise ValueError("Box must contain four normalized coordinates.")
    if any(
        type(v) not in (float, int) or not math.isfinite(v) or not 0 <= v <= 1
        for v in values
    ):
        raise ValueError("Box coordinates must be finite values between 0 and 1.")
    x0, y0, x1, y1 = values
    if x1 <= x0 or y1 <= y0:
        raise ValueError("Box corners must have positive width and height.")
    result = (
        math.floor(x0 * width),
        math.floor(y0 * height),
        math.ceil(x1 * width),
        math.ceil(y1 * height),
    )
    if result[2] - result[0] < 3 or result[3] - result[1] < 3:
        raise ValueError("Select a region at least three pixels wide and tall.")
    return result


def polygon_mask(raw: str, width: int, height: int) -> np.ndarray | None:
    vertices = json.loads(raw)
    if vertices == []:
        return None
    if not isinstance(vertices, list) or not 3 <= len(vertices) <= 300:
        raise ValueError("An outline needs between 3 and 300 points.")
    if any(not isinstance(p, list) or len(p) != 2 for p in vertices):
        raise ValueError("Each outline point needs x and y coordinates.")
    if any(
        type(v) not in (int, float) or not math.isfinite(v) or not 0 <= v <= 1
        for p in vertices
        for v in p
    ):
        raise ValueError("Outline coordinates must be between 0 and 1.")
    if has_crossings(vertices):
        raise ValueError(
            "The outline crosses or repeats itself. Trace the perimeter in order."
        )
    # Same even-odd, pixel-center convention as the Flutter offline rasterizer.
    xs = np.arange(width, dtype=np.float32)[None, :] + 0.5
    ys = np.arange(height, dtype=np.float32)[:, None] + 0.5
    mask = np.zeros((height, width), dtype=bool)
    points = [(p[0] * width, p[1] * height) for p in vertices]
    for i, (ax, ay) in enumerate(points):
        bx, by = points[i - 1]
        if ay == by:
            continue
        mask ^= ((ay > ys) != (by > ys)) & (xs < (bx - ax) * (ys - ay) / (by - ay) + ax)
    return mask


def has_crossings(vertices):
    def cross(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])

    def touches(a, b, p):
        return (
            abs(cross(a, b, p)) < 1e-9
            and min(a[0], b[0]) <= p[0] <= max(a[0], b[0])
            and min(a[1], b[1]) <= p[1] <= max(a[1], b[1])
        )

    for i, a in enumerate(vertices):
        b = vertices[(i + 1) % len(vertices)]
        if a == b:
            return True
        for j in range(i + 1, len(vertices)):
            if j == i + 1 or (i == 0 and j == len(vertices) - 1):
                continue
            c, d = vertices[j], vertices[(j + 1) % len(vertices)]
            if (
                (
                    cross(a, b, c) * cross(a, b, d) < 0
                    and cross(c, d, a) * cross(c, d, b) < 0
                )
                or touches(a, b, c)
                or touches(a, b, d)
                or touches(c, d, a)
                or touches(c, d, b)
            ):
                return True
    return False


def encode_mask(mask: np.ndarray) -> str:
    # Transparent background is needed for the app's colored overlay.
    rgba = np.zeros((*mask.shape, 4), dtype=np.uint8)
    rgba[mask] = 255
    output = io.BytesIO()
    Image.fromarray(rgba).save(output, format="PNG")
    return base64.b64encode(output.getvalue()).decode("ascii")


def mask_metrics(mask: np.ndarray) -> dict:
    ys, xs = np.nonzero(mask)
    if len(xs) < 9:
        raise ValueError(
            "No usable region found. Refine the selection or use a manual outline."
        )
    return {
        "areaPixels": int(mask.sum()),
        "bounds": [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1],
    }
