import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/injury_record.dart';
import '../models/measurement_data.dart';
import '../services/analysis_engine.dart';
import '../services/camera_service.dart';
import '../services/classification_service.dart';
import '../services/history_service.dart';
import '../services/image_processor.dart';
import '../services/logging_service.dart';
import '../services/ml_service.dart';
import '../services/storage_service.dart';

enum AnalysisStatus { idle, processing, complete, error }

class AnalysisProvider extends ChangeNotifier {
  AnalysisProvider({
    CameraService? cameraService,
    StorageService? storageService,
    ImageProcessor? imageProcessor,
    MlService? mlService,
    AnalysisEngine? analysisEngine,
    ClassificationService? classificationService,
    HistoryService? historyService,
    LoggingService? logger,
  })  : _cameraService = cameraService ?? CameraService(),
        _storageService = storageService ?? StorageService(),
        _imageProcessor = imageProcessor ?? ImageProcessor(),
        _mlService = mlService ?? MlService(),
        _analysisEngine = analysisEngine ?? AnalysisEngine(),
        _classificationService = classificationService ?? ClassificationService(),
        _historyService = historyService ?? HistoryService(),
        _logger = logger ?? LoggingService();

  final CameraService _cameraService;
  final StorageService _storageService;
  final ImageProcessor _imageProcessor;
  final MlService _mlService;
  final AnalysisEngine _analysisEngine;
  final ClassificationService _classificationService;
  final HistoryService _historyService;
  final LoggingService _logger;
  final Uuid _uuid = const Uuid();

  AnalysisStatus status = AnalysisStatus.idle;
  String? errorMessage;
  InjuryRecord? currentRecord;
  bool showGridOverlay = true;

  bool get isProcessing => status == AnalysisStatus.processing;

  Future<void> captureFromCamera() => _runPipeline(fromCamera: true);

  Future<void> selectFromGallery() => _runPipeline(fromCamera: false);

  Future<void> _runPipeline({required bool fromCamera}) async {
    status = AnalysisStatus.processing;
    errorMessage = null;
    currentRecord = null;
    notifyListeners();

    try {
      final rawPath = fromCamera
          ? await _cameraService.captureInjuryPhoto()
          : await _cameraService.selectPhotoFromGallery();

      if (rawPath == null) {
        status = AnalysisStatus.idle;
        notifyListeners();
        return;
      }

      final savedPath = await _storageService.saveImage(rawPath);
      final scansDir = await _storageService.getScansDirectory();
      final processedPath = '$scansDir/processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final processed = await _imageProcessor.preprocess(savedPath, outputPath: processedPath);

      var measurements = await _mlService.analyzeInjuryContours(
        processed.processedPath,
        skipPreprocess: true,
      );

      measurements ??= _analysisEngine.estimateCentralRegion(processed.dimensions);

      final detection = await _classificationService.classifyInjury(
        processed.processedPath,
        measurements,
        skipPreprocess: true,
      );

      final record = InjuryRecord(
        id: _uuid.v4(),
        imagePath: savedPath,
        timestamp: DateTime.now(),
        detection: detection,
        measurements: measurements,
      );

      await _historyService.saveRecord(record);

      currentRecord = record;
      status = AnalysisStatus.complete;
      _logger.info('Analysis complete in pipeline for ${record.id}');
    } catch (e, stack) {
      _logger.error('Analysis pipeline failed', e, stack);
      status = AnalysisStatus.error;
      errorMessage = 'Analysis failed. Please try again with a clearer photo.';
    }

    notifyListeners();
  }

  void toggleGridOverlay() {
    showGridOverlay = !showGridOverlay;
    notifyListeners();
  }

  void reset() {
    status = AnalysisStatus.idle;
    errorMessage = null;
    currentRecord = null;
    notifyListeners();
  }

  Future<MeasurementData?> reanalyze(String imagePath) async {
    return _mlService.analyzeInjuryContours(imagePath);
  }
}
