import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../models/injury_detection.dart';
import '../models/measurement_data.dart';
import 'image_processor.dart';
import 'logging_service.dart';
import 'severity_analyzer.dart';

class ClassificationService {
  ClassificationService({
    SeverityAnalyzer? severityAnalyzer,
    ImageProcessor? imageProcessor,
    LoggingService? logger,
  })  : _severityAnalyzer = severityAnalyzer ?? SeverityAnalyzer(),
        _imageProcessor = imageProcessor ?? ImageProcessor(),
        _logger = logger ?? LoggingService();

  final SeverityAnalyzer _severityAnalyzer;
  final ImageProcessor _imageProcessor;
  final LoggingService _logger;

  static const String _modelPath = 'assets/ml/wound_classifier.tflite';

  Future<InjuryDetection> classifyInjury(
    String imagePath,
    MeasurementData measurements, {
    bool skipPreprocess = false,
  }) async {
    String? topLabel;
    var confidence = 0.5;

    ImageLabeler? labeler;

    try {
      final pathForMl = skipPreprocess
          ? imagePath
          : (await _imageProcessor.preprocess(imagePath)).processedPath;

      final options = LocalLabelerOptions(
        modelPath: _modelPath,
        confidenceThreshold: 0.40,
      );

      labeler = ImageLabeler(options: options);
      final inputImage = InputImage.fromFilePath(pathForMl);
      final labels = await labeler.processImage(inputImage);

      if (labels.isNotEmpty) {
        topLabel = labels.first.label;
        confidence = labels.first.confidence;
        _logger.info('ML label: $topLabel (${confidence.toStringAsFixed(2)})');
      }
    } catch (e, stack) {
      _logger.error('Classification engine error — using visual analysis', e, stack);
    } finally {
      await labeler?.close();
    }

    final metrics = await _severityAnalyzer.analyzeRegion(
      imagePath,
      measurements.boundingBox,
    );

    return _severityAnalyzer.buildDetection(
      mlLabel: topLabel,
      mlConfidence: confidence,
      metrics: metrics,
      measurements: measurements,
    );
  }
}
