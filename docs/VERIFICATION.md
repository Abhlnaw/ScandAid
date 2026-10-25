# Verification and release status

## Completed locally

| Check | Result |
| --- | --- |
| Flutter analyzer | No issues |
| Flutter tests | 18 passing |
| Backend tests | 35 passing |
| Python lint and formatting | Passing |
| Flutter release web build | Built successfully |
| Android debug APK | Built successfully |
| Real MedSAM checkpoint | Loaded and ran on the authors' public demo |
| Real wound classifier | Safetensors loaded and model forward pass exercised |
| Local HTTP integration | `/`, `/health` and `/analyze` returned HTTP 200 |
| Visual review | Desktop overview rendered and inspected; narrow-screen layouts tested |

The official 512×512 MedSAM demo with box `[95,255,190,350]` produced 4,888 foreground pixels, with bounds `[104,264,186,339]`. The classifier now explicitly abstains on that grayscale medical image. This checks runtime integration and provenance, not wound accuracy. The initial model experiment also demonstrated why quality rejection is necessary: a closed-set classifier can assign a wound label to unrelated medical imagery.

Flutter tests exercise polygon pixel counts, per-image scale conversion, invalid geometry, photo orientation/EXIF removal, actual returned-mask measurements, server failures, snapshot recovery, failed disk writes, backup restoration/deduplication, screen layouts, and the complete manual measure–review–save workflow. Backend tests cover coordinate validation, masks, GrabCut, upload limits, abstention, inference errors, dataset leakage and evaluation metrics.

Tested environment: Windows, Flutter 3.44.0, Dart 3.12.0, CPython 3.12.10, CPU PyTorch 2.15.0, Transformers 4.57.6. Flutter dependencies are recorded in `pubspec.lock`; downloaded model revisions and SHA-256 fingerprints are checked by the downloader. Local model fingerprints are also recorded in ignored `models/manifest.json`.

The GitHub Actions workflow is configured but has not been run on GitHub as part of this work. No push is needed to use the local application.

## Artifacts

- `build/web/`: deployable web bundle, served by the included backend when present.
- `build/app/outputs/flutter-apk/app-debug.apk`: installable development APK; not an app-store release.
- `.tools/qa/`: local visual/runtime evidence, excluded from Git.

## Remaining release requirements

- A labeled, licensed, patient-separated dataset and independent clinical validation. No new accuracy, calibrated confidence, wound-specific segmentation score, fairness guarantee or clinical readiness is claimed.
- Physical-device camera/gallery, permissions, export and restore checks on the intended Android/iOS devices. Automated widget and API tests do not substitute for these.
- iOS/macOS builds and signing require macOS/Xcode and were not performed here. Windows desktop compilation requires missing Visual Studio C++/CMake components and plugin symlink support; the verified local delivery path is the web app.
- An app-store application identifier, icons/branding review, store metadata, privacy review and owner-controlled signing credentials.

Android release tasks intentionally require `android/key.properties`; the project no longer signs release builds with the debug key. Copy `android/key.properties.example` and fill it locally with your own upload key. `key.properties` and keystores are ignored by Git. After configuring the final application ID and signing, build with `flutter build appbundle --release`.

The Android build currently reports an upstream image-picker Kotlin migration warning. The debug APK builds with the tested Flutter/Gradle versions; recheck plugin compatibility before upgrading the toolchain.
