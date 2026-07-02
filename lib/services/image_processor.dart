import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'logging_service.dart';

/// Standard ML input size used across detection and classification pipelines.
const int kMlInputSize = 640;

class ProcessedImage {
  final String originalPath;
  final String processedPath;
  final int width;
  final int height;
  final Size dimensions;

  ProcessedImage({
    required this.originalPath,
    required this.processedPath,
    required this.width,
    required this.height,
  }) : dimensions = Size(width.toDouble(), height.toDouble());
}

class ImageProcessor {
  ImageProcessor({LoggingService? logger}) : _logger = logger ?? LoggingService();

  final LoggingService _logger;

  Future<ProcessedImage> preprocess(String imagePath, {String? outputPath}) async {
    final bytes = await File(imagePath).readAsBytes();
    img.Image? decoded = img.decodeImage(bytes);

    if (decoded == null) {
      throw FormatException('Unable to decode image at $imagePath');
    }

    decoded = img.bakeOrientation(decoded);
    decoded = _resizeToStandard(decoded);
    decoded = _normalizePixels(decoded);

    final outPath = outputPath ?? imagePath;
    await File(outPath).writeAsBytes(img.encodeJpg(decoded, quality: 92));

    _logger.info(
      'Preprocessed image ${decoded.width}x${decoded.height} -> $outPath',
    );

    return ProcessedImage(
      originalPath: imagePath,
      processedPath: outPath,
      width: decoded.width,
      height: decoded.height,
    );
  }

  img.Image _resizeToStandard(img.Image source) {
    if (source.width == kMlInputSize && source.height == kMlInputSize) {
      return source;
    }
    return img.copyResize(
      source,
      width: kMlInputSize,
      height: kMlInputSize,
      interpolation: img.Interpolation.linear,
    );
  }

  /// Scales pixel values toward 0–255 range for consistent ML input.
  img.Image _normalizePixels(img.Image source) {
    final normalized = img.Image.from(source);
    for (var y = 0; y < normalized.height; y++) {
      for (var x = 0; x < normalized.width; x++) {
        final pixel = normalized.getPixel(x, y);
        final r = pixel.r.toInt().clamp(0, 255);
        final g = pixel.g.toInt().clamp(0, 255);
        final b = pixel.b.toInt().clamp(0, 255);
        normalized.setPixelRgba(x, y, r, g, b, pixel.a.toInt());
      }
    }
    return normalized;
  }

  Future<Uint8List> readRegionBytes(String imagePath, Rect region) async {
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final oriented = img.bakeOrientation(decoded);
    final left = region.left.clamp(0, oriented.width - 1).toInt();
    final top = region.top.clamp(0, oriented.height - 1).toInt();
    final width = region.width.clamp(1, oriented.width - left).toInt();
    final height = region.height.clamp(1, oriented.height - top).toInt();

    final crop = img.copyCrop(oriented, x: left, y: top, width: width, height: height);
    return Uint8List.fromList(img.encodeJpg(crop));
  }
}
