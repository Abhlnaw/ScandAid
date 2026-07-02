import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import '../models/measurement_data.dart';
import 'analysis_engine.dart';
import 'image_processor.dart';
import 'logging_service.dart';

class MlService {
  MlService({
    AnalysisEngine? analysisEngine,
    ImageProcessor? imageProcessor,
    LoggingService? logger,
  })  : _analysisEngine = analysisEngine ?? AnalysisEngine(),
        _imageProcessor = imageProcessor ?? ImageProcessor(),
        _logger = logger ?? LoggingService();

  final AnalysisEngine _analysisEngine;
  final ImageProcessor _imageProcessor;
  final LoggingService _logger;

  static const String _modelPath = 'assets/ml/wound_detector.tflite';

  Future<MeasurementData?> analyzeInjuryContours(
    String imagePath, {
    bool skipPreprocess = false,
  }) async {
    ObjectDetector? objectDetector;

    try {
      final pathForMl = skipPreprocess
          ? imagePath
          : (await _imageProcessor.preprocess(imagePath)).processedPath;

      final options = LocalObjectDetectorOptions(
        modelPath: _modelPath,
        mode: DetectionMode.single,
        classifyObjects: true,
        multipleObjects: false,
        maximumLabelsPerObject: 1,
        confidenceThreshold: 0.2,
      );

      objectDetector = ObjectDetector(options: options);
      final inputImage = InputImage.fromFilePath(pathForMl);
      final detectedObjects = await objectDetector.processImage(inputImage);

      if (detectedObjects.isEmpty) {
        _logger.warning('No injury contour detected by ML model');
        return null;
      }

      final primaryObject = detectedObjects.first;
      final confidence = primaryObject.labels.isNotEmpty
          ? primaryObject.labels.first.confidence
          : 0.7;

      final measurements = _analysisEngine.fromBoundingBox(
        primaryObject.boundingBox,
        confidence: confidence,
      );

      if (!_analysisEngine.isValidMeasurement(measurements)) {
        _logger.warning('ML measurements failed validation');
        return null;
      }

      return measurements;
    } catch (e, stack) {
      _logger.error('Vision engine error — model may be missing', e, stack);
      return null;
    } finally {
      await objectDetector?.close();
    }
  }
}
