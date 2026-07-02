import 'package:flutter/material.dart';

import '../models/measurement_data.dart';
import 'logging_service.dart';

class AnalysisEngine {
  AnalysisEngine({LoggingService? logger}) : _logger = logger ?? LoggingService();

  final LoggingService _logger;

  /// Relative pixel-to-cm ratio for proportional sizing without a reference object.
  static const double pixelToCmRatio = 0.026;

  MeasurementData fromBoundingBox(
    Rect bounds, {
    double confidence = 0.85,
    bool isEstimated = false,
  }) {
    final validated = validateBounds(bounds);
    final lengthCm = validated.height * pixelToCmRatio;
    final widthCm = validated.width * pixelToCmRatio;
    final areaSqCm = lengthCm * widthCm;

    return MeasurementData(
      lengthCm: _round(lengthCm),
      widthCm: _round(widthCm),
      areaSqCm: _round(areaSqCm),
      boundingBox: validated,
      confidence: confidence,
      isEstimated: isEstimated,
    );
  }

  /// Estimates a central region when ML detection fails — marked as estimated.
  MeasurementData estimateCentralRegion(Size imageSize) {
    final boxWidth = imageSize.width * 0.50;
    final boxHeight = imageSize.height * 0.60;
    final left = (imageSize.width - boxWidth) / 2;
    final top = (imageSize.height - boxHeight) / 2;

    _logger.warning('Using estimated central region — no ML contour detected');

    return fromBoundingBox(
      Rect.fromLTWH(left, top, boxWidth, boxHeight),
      confidence: 0.35,
      isEstimated: true,
    );
  }

  Rect validateBounds(Rect bounds) {
    final left = bounds.left.clamp(0.0, double.infinity);
    final top = bounds.top.clamp(0.0, double.infinity);
    final width = bounds.width.clamp(1.0, double.infinity);
    final height = bounds.height.clamp(1.0, double.infinity);
    return Rect.fromLTWH(left, top, width, height);
  }

  bool isValidMeasurement(MeasurementData data) {
    return data.lengthCm > 0 &&
        data.widthCm > 0 &&
        data.areaSqCm > 0 &&
        data.boundingBox.width > 1 &&
        data.boundingBox.height > 1;
  }

  double _round(double value) => double.parse(value.toStringAsFixed(2));
}
