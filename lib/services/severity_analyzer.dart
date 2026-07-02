import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/injury_detection.dart';
import '../models/injury_enums.dart';
import '../models/measurement_data.dart';
import 'logging_service.dart';

class VisualMetrics {
  final double erythemaScore;
  final double structuralDisruption;
  final String primaryTissueColor;

  VisualMetrics({
    required this.erythemaScore,
    required this.structuralDisruption,
    required this.primaryTissueColor,
  });
}

class SeverityAnalyzer {
  SeverityAnalyzer({LoggingService? logger}) : _logger = logger ?? LoggingService();

  final LoggingService _logger;

  Future<VisualMetrics> analyzeRegion(String imagePath, Rect region) async {
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return VisualMetrics(
        erythemaScore: 0.2,
        structuralDisruption: 0.2,
        primaryTissueColor: 'Epithelial Maturation (Pinkish-Skin)',
      );
    }

    final oriented = img.bakeOrientation(decoded);
    final left = region.left.clamp(0, oriented.width - 1).toInt();
    final top = region.top.clamp(0, oriented.height - 1).toInt();
    final width = region.width.clamp(1, oriented.width - left).toInt();
    final height = region.height.clamp(1, oriented.height - top).toInt();

    double rednessSum = 0;
    double edgeVarianceSum = 0;
    double yellowSum = 0;
    double pinkSum = 0;
    int count = 0;

    for (var y = top; y < top + height; y += 2) {
      for (var x = left; x < left + width; x += 2) {
        final pixel = oriented.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();

        final redness = ((r - g) + (r - b)) / 510.0;
        rednessSum += redness.clamp(0, 1);

        if (x > left && y > top) {
          final prev = oriented.getPixel(x - 2, y - 2);
          final delta = (r - prev.r).abs() + (g - prev.g).abs() + (b - prev.b).abs();
          edgeVarianceSum += (delta / 765.0).clamp(0, 1);
        }

        if (r > 180 && g > 120 && b < 100) yellowSum++;
        if (r > 150 && g > 80 && b > 80) pinkSum++;
        count++;
      }
    }

    if (count == 0) {
      return VisualMetrics(
        erythemaScore: 0.2,
        structuralDisruption: 0.2,
        primaryTissueColor: 'Epithelial Maturation (Pinkish-Skin)',
      );
    }

    final erythema = (rednessSum / count).clamp(0.0, 1.0);
    final disruption = (edgeVarianceSum / count).clamp(0.0, 1.0);
    final tissueColor = _classifyTissueColor(yellowSum / count, pinkSum / count, erythema);

    _logger.info(
      'Visual analysis — erythema: ${erythema.toStringAsFixed(2)}, '
      'disruption: ${disruption.toStringAsFixed(2)}',
    );

    return VisualMetrics(
      erythemaScore: erythema,
      structuralDisruption: disruption,
      primaryTissueColor: tissueColor,
    );
  }

  InjuryDetection buildDetection({
    required String? mlLabel,
    required double mlConfidence,
    required VisualMetrics metrics,
    required MeasurementData measurements,
  }) {
    final type = _mapLabelToType(mlLabel);
    final severity = _computeSeverity(
      type: type,
      erythema: metrics.erythemaScore,
      disruption: metrics.structuralDisruption,
      areaSqCm: measurements.areaSqCm,
      mlConfidence: mlConfidence,
    );

    return InjuryDetection(
      type: type,
      severity: severity,
      confidenceScore: mlConfidence.clamp(0.0, 1.0),
      clinicalRecommendation: _recommendation(severity, type),
      patientSummary: _patientSummary(severity, metrics),
      erythemaScore: metrics.erythemaScore,
      structuralDisruption: metrics.structuralDisruption,
      primaryTissueColor: metrics.primaryTissueColor,
    );
  }

  InjuryType _mapLabelToType(String? label) {
    if (label == null) return InjuryType.unknown;
    final lower = label.toLowerCase();
    if (lower.contains('burn')) return InjuryType.burn;
    if (lower.contains('bruise')) return InjuryType.bruise;
    if (lower.contains('abrasion') || lower.contains('scrape')) {
      return InjuryType.abrasion;
    }
    if (lower.contains('cut') ||
        lower.contains('laceration') ||
        lower.contains('incision')) {
      return InjuryType.cut;
    }
    return InjuryType.unknown;
  }

  SeverityLevel _computeSeverity({
    required InjuryType type,
    required double erythema,
    required double disruption,
    required double areaSqCm,
    required double mlConfidence,
  }) {
    var score = 1.0;

    score += erythema * 1.5;
    score += disruption * 1.2;
    score += min(areaSqCm / 10.0, 1.5);

    if (type == InjuryType.burn) score += 0.8;
    if (type == InjuryType.cut && disruption > 0.5) score += 0.5;

    if (mlConfidence < 0.4) score -= 0.3;

    if (score <= 1.5) return SeverityLevel.minor;
    if (score <= 2.5) return SeverityLevel.mild;
    if (score <= 3.5) return SeverityLevel.moderate;
    if (score <= 4.5) return SeverityLevel.severe;
    return SeverityLevel.critical;
  }

  String _classifyTissueColor(double yellowRatio, double pinkRatio, double erythema) {
    if (yellowRatio > 0.15) return 'Slough Tissue (Yellow)';
    if (pinkRatio > 0.3 || erythema > 0.45) {
      return 'Granulation Tissue (Vibrant Red/Pink)';
    }
    return 'Epithelial Maturation (Pinkish-Skin)';
  }

  String _patientSummary(SeverityLevel severity, VisualMetrics metrics) {
    if (severity.index >= SeverityLevel.severe.index) {
      return 'Significant inflammation or tissue disruption detected. Professional evaluation recommended.';
    }
    if (metrics.erythemaScore > 0.5) {
      return 'Mild redness detected near the injury borders. Keep the area clean and monitor.';
    }
    return 'Structural margins appear stable. Continue tracking healing progress.';
  }

  String _recommendation(SeverityLevel severity, InjuryType type) {
    return switch (severity) {
      SeverityLevel.minor =>
        'Keep wound clean and dry. Apply basic first aid and monitor daily.',
      SeverityLevel.mild =>
        'Clean gently, cover if needed, and watch for increased redness or warmth.',
      SeverityLevel.moderate =>
        'Periwound changes detected. Consider consulting a healthcare provider within 24–48 hours.',
      SeverityLevel.severe =>
        'Seek professional medical evaluation promptly.',
      SeverityLevel.critical =>
        'This may require urgent care. Contact emergency services or go to the nearest clinic.',
    };
  }
}
