# Model sources and inference contract

## MedSAM

The backend uses the original MedSAM ViT-B architecture and authors' checkpoint. A user supplies a box. Inference follows the original square cubic resize to 1024, per-image min/max normalization, independent box-axis scaling, image/prompt encoding, single-mask decoding, sigmoid and bilinear resize with a 0.5 threshold. ScandAid intersects the mask with the selected maximum region; the user must review the result.

- [Official repository](https://github.com/bowang-lab/MedSAM)
- [Inference implementation](https://github.com/bowang-lab/MedSAM/blob/main/MedSAM_Inference.py)
- [Paper](https://www.nature.com/articles/s41467-024-44824-z)
- [Authors' checkpoint folder](https://drive.google.com/drive/folders/1ETWmi4AiniJeWOt6HAsYgTjYv_fkgzoN)

File ID: `1UAmWL88roYR7wKlnApw5Bcuzf2iQgk6_`. Verified SHA-256: `34b34b78c1d18cb8c6bf84cf9c00e135d6d6c965699f3c0e31ef1bc9dcb5be74`. Checkpoints load with tensor-only `torch.load(weights_only=True)`. Matching the checkpoint establishes reproducibility, not wound-specific accuracy. Upstream code/checkpoint licensing is Apache-2.0; weights are not redistributed here.

Absent weights, box mode uses explicitly labeled GrabCut. If segmentation fails, the user can use a manual outline. Errors never produce guessed rectangular measurements.

## Classification

[Hemgg/wound-image-classification](https://huggingface.co/Hemgg/wound-image-classification) is a ten-label ViT fine-tune. Its model card leaves the training dataset unspecified; its reported evaluation is not ScandAid performance. Pinned revision: `a5b5b23a48c8cb669d1763039426c86c59eec8e0`. Safetensors SHA-256: `978096c4a7925df8cc207df6bcd7b389bae886e7f932298fcaccf07a89ee6595`. The runtime reads local model files, with remote code disabled.

The app maps labels to abrasion, bruise, burn, cut, laceration, diabetic wound appearance, no wound appearance, pressure wound appearance, surgical wound appearance and venous wound appearance. Etiologic categories are phrased as appearance because the cause requires clinical history. “No wound appearance” cannot rule out injury.

Inference compares the selected crop plus 15% context with the full photo and averages softmax scores. It abstains for disagreement, poor image quality, grayscale inputs, top score below 0.70 or margin below 0.15. These are uncalibrated engineering defaults, not validated operating thresholds or a reliable out-of-distribution detector. High scores can still be wrong. The app shows the top three scores and provenance, or an abstention reason. No score becomes severity or a treatment recommendation.

## API

`GET /health`: actual segmentation/classification sources, version, and `clinicalValidation: false`.

`POST /analyze`, multipart:

| Field | Content |
| --- | --- |
| `image` | JPEG/PNG/WebP; up to 12 MB; dimensions 32–4096 and at most 16 MP |
| `box` | Normalized JSON `[x0,y0,x1,y1]`, positive extent |
| `outline` | Optional normalized polygon; preserves the exact manual region instead of running automatic segmentation |

Response: base64 RGBA `maskPng`, pixel area/bounds and source; classification label/scores/source/abstention; and descriptive red-dominant pixel fraction. Flutter independently counts the returned mask pixels. Red-pixel fraction is not an inflammation score.

Complete request bodies are bounded before parsing; accepted photos remain in RAM and are not saved by the server. Inference is serialized with limited in-flight analysis. The launcher binds to loopback and disables access logs. There is no built-in authentication; remote use needs an authenticated HTTPS gateway and resource controls.

| Variable | Behavior |
| --- | --- |
| `MEDSAM_CHECKPOINT` | Original checkpoint path; defaults to `models/medsam_vit_b.pth` when present; empty disables |
| `CLASSIFIER_PATH` | Local Transformers folder; defaults to `models/classifier` when present; empty disables |
| `SCAN_DEVICE` | `cpu` default, or `cuda` when available |
| `SCAN_ALLOWED_ORIGINS` | Browser origins; defaults to localhost/127.0.0.1 port 5173 |

The API also serves `build/web` when available. For browser deployment, app and API can share the origin. An HTTPS page cannot call an HTTP inference server; use a local same-origin setup or HTTPS on both sides.
