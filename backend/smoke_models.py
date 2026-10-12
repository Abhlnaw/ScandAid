"""Exercise real local models; output is a runtime check, not clinical validation."""

import argparse
import base64
import json
import time
from pathlib import Path

from backend.app import Engine, decode_image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", required=True, type=Path)
    parser.add_argument(
        "--box", required=True, nargs=4, type=int, metavar=("X0", "Y0", "X1", "Y1")
    )
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    started = time.perf_counter()
    engine = Engine()
    image = decode_image(args.image.read_bytes())
    result = engine.analyze(image, tuple(args.box), "[]")
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "mask.png").write_bytes(
        base64.b64decode(result["segmentation"].pop("maskPng"))
    )
    result["elapsedSeconds"] = round(time.perf_counter() - started, 2)
    result["modelAvailability"] = {
        "segmentation": engine.segmenter.source,
        "classification": engine.classifier.source,
    }
    (args.output / "result.json").write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
