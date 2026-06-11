import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import '../models/measurement_data.dart';

class MlService {
  Future<MeasurementData?> analyzeInjuryContours(String imagePath) async {
    final modelPath = 'assets/ml/wound_detector.tflite';
    
    final options = LocalObjectDetectorOptions(
      modelPath: modelPath,
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: false,
      maximumLabelsPerObject: 1,
      confidenceThreshold: 0.2, // Lowered threshold to catch subtle tissue boundaries
    );

    final objectDetector = ObjectDetector(options: options);

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final List<DetectedObject> detectedObjects = await objectDetector.processImage(inputImage);

      // NO FAKING: If the model doesn't see a distinct boundary, return null
      if (detectedObjects.isEmpty) {
        return null; 
      }

      final primaryObject = detectedObjects.first;
      return _calculateRealWorldDimensions(primaryObject.boundingBox);

    } catch (e) {
      print('Vision Engine Error: $e');
      return null;
    } finally {
      objectDetector.close();
    }
  }

  MeasurementData _calculateRealWorldDimensions(Rect bounds) {
    const double pixelToCmRatio = 0.026; 
    double lengthCm = bounds.height * pixelToCmRatio;
    double widthCm = bounds.width * pixelToCmRatio;
    double areaSqCm = lengthCm * widthCm;

    return MeasurementData(
      lengthCm: double.parse(lengthCm.toStringAsFixed(2)),
      widthCm: double.parse(widthCm.toStringAsFixed(2)),
      areaSqCm: double.parse(areaSqCm.toStringAsFixed(2)),
      boundingBox: bounds,
    );
  }
}