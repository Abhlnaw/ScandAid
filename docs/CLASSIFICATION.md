# Improving classification

The baseline runs, but no new training or clinical accuracy is claimed. Improvement requires labeled examples, patient-separated splits, verified data rights and evaluation on the intended cameras, lighting and skin-tone population. Unknown pretraining provenance also prevents a claim that a test dataset is independent of pretraining.

The included tooling takes a local CSV:

```csv
path,label,patient_id,split
images/a.jpg,Cut,pseudonym-001,train
images/b.jpg,Burns,pseudonym-002,validation
images/c.jpg,Abrasions,pseudonym-003,test
```

This illustrates the format, not a sufficient dataset. Labels must match the ten original strings in `backend/classification.py`. Both training and validation must contain all classes. Use stable patient pseudonyms; all follow-ups for one person belong to the same split.

The audit rejects unknown labels, missing files, paths outside the dataset root, repeated paths, patient groups crossing splits and identical image bytes crossing splits. Hashes do not identify all near-duplicates or transformed copies; audit those separately. Private images, manifests and reports belong in ignored `private_data/`.

## Fine-tune

```bash
python -m backend.train_classifier \
  --manifest private_data/manifest.csv \
  --data-root private_data \
  --output models/custom-classifier \
  --device cuda
```

The trainer uses class-weighted cross entropy, AdamW, small augmentations, a fixed seed, gradient clipping, validation-loss checkpoint selection and early stopping. It saves safetensors, the processor and provenance, retaining the reviewed taxonomy. CPU training works but is slow. Test images are not used for model selection. The training entry point has been import/syntax checked; its manifest and metrics are tested. A full training run requires the missing labeled dataset.

## Evaluate

```bash
python -m backend.evaluate_classifier \
  --manifest private_data/manifest.csv \
  --data-root private_data \
  --model models/custom-classifier \
  --split test \
  --output private_data/evaluation.json
```

Reports include coverage, accepted-only accuracy, accuracy including abstentions as misses, balanced accuracy, present-class macro F1, per-class metrics and a confusion matrix with an abstention column. Report accepted-only accuracy together with coverage. Evaluation uses whole photos; app region-selection and segmentation accuracy require separate annotated evaluation. It does not establish confidence calibration, sensitivity guarantees, prospective validation or regulatory qualification.

Compare against the pinned baseline on the same untouched test set. Tune thresholds only on validation data. Investigate errors by skin tone, camera, wound type and lighting, with sufficient examples per group. To serve a reviewed custom model, set `CLASSIFIER_PATH=models/custom-classifier`; provenance appears in the app. Keep the pinned baseline unchanged.
