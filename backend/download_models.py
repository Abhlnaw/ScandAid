"""Download public model weights only; never upload user images."""

import argparse
import hashlib
import json
from pathlib import Path

from backend.classification import MODEL_ID, MODEL_REVISION

ROOT = Path(__file__).resolve().parent.parent
MEDSAM_FILE_ID = "1UAmWL88roYR7wKlnApw5Bcuzf2iQgk6_"
MEDSAM_SHA256 = "34b34b78c1d18cb8c6bf84cf9c00e135d6d6c965699f3c0e31ef1bc9dcb5be74"
CLASSIFIER_SHA256 = "978096c4a7925df8cc207df6bcd7b389bae886e7f932298fcaccf07a89ee6595"


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--classifier-only", action="store_true")
    parser.add_argument("--medsam-only", action="store_true")
    args = parser.parse_args()
    if args.classifier_only and args.medsam_only:
        parser.error("Choose at most one model-only option.")
    target = ROOT / "models"
    target.mkdir(exist_ok=True)
    manifest_path = target / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    if not args.medsam_only:
        from huggingface_hub import snapshot_download

        folder = target / "classifier"
        snapshot_download(
            repo_id=MODEL_ID,
            revision=MODEL_REVISION,
            local_dir=str(folder),
            allow_patterns=[
                "config.json",
                "preprocessor_config.json",
                "model.safetensors",
                "README.md",
            ],
        )
        fingerprint = sha256(folder / "model.safetensors")
        if fingerprint != CLASSIFIER_SHA256:
            raise RuntimeError(
                "Classifier checkpoint fingerprint differs from the verified release."
            )
        manifest["classifier"] = {
            "repository": MODEL_ID,
            "revision": MODEL_REVISION,
            "sha256": fingerprint,
            "license": "Apache-2.0",
        }
        manifest_path.write_text(json.dumps(manifest, indent=2))
        print("Classifier downloaded and pinned to", MODEL_REVISION)
    if not args.classifier_only:
        import gdown

        checkpoint = target / "medsam_vit_b.pth"
        if not checkpoint.exists():
            partial = target / "medsam_vit_b.pth.partial"
            result = gdown.download(
                id=MEDSAM_FILE_ID, output=str(partial), quiet=False, resume=True
            )
            if result is None:
                raise RuntimeError(
                    "MedSAM download failed. See the official checkpoint link in docs/MODELS.md."
                )
            partial.replace(checkpoint)
        fingerprint = sha256(checkpoint)
        if fingerprint != MEDSAM_SHA256:
            raise RuntimeError(
                "MedSAM checkpoint fingerprint differs from the verified release. Do not load these weights."
            )
        manifest["medsam"] = {
            "source": "https://github.com/bowang-lab/MedSAM",
            "driveFileId": MEDSAM_FILE_ID,
            "sha256": fingerprint,
            "license": "Apache-2.0",
        }
        manifest_path.write_text(json.dumps(manifest, indent=2))
        print("MedSAM downloaded; fingerprint:", manifest["medsam"]["sha256"])


if __name__ == "__main__":
    main()
