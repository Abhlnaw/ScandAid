# ScandAid

A local-first wound photo journal built with Flutter. Capture a photo, trace a wound or request an assisted mask, mark a known ruler distance, and compare calibrated area across follow-ups. Photos and notes stay on the device unless you enable your own inference server or export a backup.

The tracking workflow is implemented. AI is an **experimental research feature**, with real MedSAM segmentation and a pretrained wound classifier. It is not clinically validated and does not infer infection, severity, depth, treatment, or urgency.

## Features

- Camera on supported mobile/web platforms; gallery/file import elsewhere.
- Orientation correction, bounded resizing, explicit EXIF removal.
- Offline manual outlines, with crossing/repeated edges rejected.
- Optional box-prompted MedSAM; explicitly named GrabCut when weights are absent.
- Ten-label ViT classifier with quality gates, score/margin thresholds, crop/full-image agreement and abstention.
- Actual mask-pixel area. Centimeters require a reference marked in **each** photo.
- Persistent history, notes, grouped follow-ups, calibrated comparisons, deletion, JSON backup and restore.
- Local operation by default; no accounts, telemetry or automatic uploads.

## Run this workspace

Flutter 3.44 / Dart 3.12, a repository-local Python runtime and downloaded model weights were used to verify this workspace. Runtime and model files are excluded from Git.

```powershell
.\scripts\start.ps1
```

Open **http://127.0.0.1:8000**. In Settings, enter that same server origin, test the connection, enable sending photos, and save settings. In a new entry, select **Assisted box** to use MedSAM. Manual outlines can also be sent for classification while retaining the exact outline. Use `scripts/start.ps1 -NoBuild` to reuse the web build on later starts.

## Fresh checkout

Install Flutter 3.44+ / Dart 3.12+ and 64-bit CPython 3.12, then run from the repository root:

```powershell
flutter pub get
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu
.\.venv\Scripts\python.exe -m pip install -r backend/requirements.txt
.\.venv\Scripts\python.exe -m backend.download_models
.\scripts\start.ps1
```

macOS/Linux:

```bash
flutter pub get
python3.12 -m venv .venv
.venv/bin/python -m pip install -r backend/requirements.txt
.venv/bin/python -m backend.download_models
flutter build web --release
.venv/bin/python -m uvicorn backend.app:app --host 127.0.0.1 --port 8000 --no-access-log
```

The classifier is about 343 MB; MedSAM about 375 MB. Revision and SHA-256 checks pin the tested baseline. Downloads never upload photos. Without weights, manual tracking works and the API provides GrabCut with classification unavailable. Model inference is local; initial loading and CPU inference take several seconds.

## Other platforms

```bash
flutter run -d chrome --web-port 5173
flutter build apk --debug
flutter run -d windows
```

Android emulator server: `http://10.0.2.2:8000`. USB Android phone: run `adb reverse tcp:8000 tcp:8000`, then use `http://127.0.0.1:8000`. Android cleartext exceptions are restricted to loopback/emulator hosts; use HTTPS otherwise. Windows native builds need Visual Studio's C++ workload, CMake, Windows SDK and plugin symlink support. iOS/macOS need macOS and Xcode.

Signing, physical-device verification and clinical validation remain separate release requirements. See [verification](docs/VERIFICATION.md) for checks actually completed.

## Development

Install `backend/requirements-dev.txt`, then run `scripts/check.ps1`, or:

```bash
flutter analyze
flutter test
python -m ruff check backend
python -m pytest backend/tests -q
```

CI also checks formatting and builds the web bundle. [Model notes](docs/MODELS.md) cover sources, configuration and the API. [Classification development](docs/CLASSIFICATION.md) covers patient-separated training/evaluation. [Privacy](docs/PRIVACY.md) explains storage and deployment.

| Path | Purpose |
| --- | --- |
| `lib/models/scan.dart` | Scan, classification and scale data |
| `lib/screens/scan_editor.dart` | Region selection, calibration and review |
| `lib/services/` | Photos, measurements, inference and persistence |
| `lib/widgets/` | Photo overlays |
| `backend/` | API, MedSAM, GrabCut, ViT, model downloads and dataset tools |
| `test/`, `backend/tests/` | Workflow, geometry, persistence, API and evaluation tests |

No labeled patient dataset was supplied, so no new classifier accuracy, calibrated confidence, wound-specific MedSAM accuracy or clinical readiness is claimed. The baseline classifier's training provenance is incomplete; thresholding cannot guarantee detection of arbitrary non-wound inputs or performance across skin tones.
