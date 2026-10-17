import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:scandaid/models/scan.dart';
import 'package:scandaid/services/analysis_service.dart';
import 'package:scandaid/services/photo_service.dart';
import 'package:scandaid/services/storage_backend.dart';

class MemoryStorage extends StorageBackend {
  String? content;
  bool fail = false;
  @override
  Future<String?> read() async => content;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('Disk full');
    content = value;
  }
}

PreparedPhoto testPhoto({int width = 100, int height = 80}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(180, 120, 95));
  return preparePhoto(img.encodeJpg(image));
}

const rectangle = [
  Offset(.25, .25),
  Offset(.75, .25),
  Offset(.75, .75),
  Offset(.25, .75),
];
Scan testScan({
  String id = 'test',
  String woundName = 'Left knee',
  DateTime? date,
}) {
  final photo = testPhoto();
  final measured = measureOutline(photo, rectangle);
  return Scan(
    id: id,
    woundName: woundName,
    createdAt: date ?? DateTime.utc(2026, 10, 28),
    imageBase64: base64Encode(photo.bytes),
    width: photo.width,
    height: photo.height,
    outline: rectangle,
    areaPixels: measured.areaPixels,
    bounds: measured.bounds,
    calibration: const Calibration(Offset(.1, .1), Offset(.6, .1), 5),
    classification: measured.classification,
    segmentationSource: measured.source,
    notes: 'Test note',
  );
}
