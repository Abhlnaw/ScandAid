import 'package:flutter/material.dart';

class MeasurementData {
  final double lengthCm;
  final double widthCm;
  final double areaSqCm;
  final Rect boundingBox;
  final double? depthMm;
  final double? volumeCuCm;
  final double confidence;
  final bool isEstimated;

  MeasurementData({
    required this.lengthCm,
    required this.widthCm,
    required this.areaSqCm,
    required this.boundingBox,
    this.depthMm,
    this.volumeCuCm,
    this.confidence = 1.0,
    this.isEstimated = false,
  });

  Map<String, dynamic> toJson() => {
        'lengthCm': lengthCm,
        'widthCm': widthCm,
        'areaSqCm': areaSqCm,
        'boundingBox': {
          'left': boundingBox.left,
          'top': boundingBox.top,
          'width': boundingBox.width,
          'height': boundingBox.height,
        },
        'depthMm': depthMm,
        'volumeCuCm': volumeCuCm,
        'confidence': confidence,
        'isEstimated': isEstimated,
      };

  factory MeasurementData.fromJson(Map<String, dynamic> json) {
    final box = json['boundingBox'] as Map<String, dynamic>;
    return MeasurementData(
      lengthCm: (json['lengthCm'] as num).toDouble(),
      widthCm: (json['widthCm'] as num).toDouble(),
      areaSqCm: (json['areaSqCm'] as num).toDouble(),
      boundingBox: Rect.fromLTWH(
        (box['left'] as num).toDouble(),
        (box['top'] as num).toDouble(),
        (box['width'] as num).toDouble(),
        (box['height'] as num).toDouble(),
      ),
      depthMm: json['depthMm'] != null ? (json['depthMm'] as num).toDouble() : null,
      volumeCuCm:
          json['volumeCuCm'] != null ? (json['volumeCuCm'] as num).toDouble() : null,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      isEstimated: json['isEstimated'] as bool? ?? false,
    );
  }
}
