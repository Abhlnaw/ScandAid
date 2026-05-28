import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import '../models/measurement_data.dart';

class MlService {
  Future<MeasurementData?> analyzeInjuryContours(String imagePath) async {
    final options = ObjectDetectorOptions(
      mode: DetectionMode.single, 
      classifyObjects: false,     
      multipleObjects: false,     
    );

    final objectDetector = ObjectDetector(options: options);

    try {
      final inputImage = InputImage.fromFilePath(imagePath);

      final List<DetectedObject> detectedObjects = await objectDetector.processImage(inputImage);

      if (detectedObjects.isEmpty) {
        print('ML Kit: No specific object boundary detected.');
        return null;
      }

      final primaryObject = detectedObjects.first;
      final Rect boundingBox = primaryObject.boundingBox;

      print('🎯 ML Kit found object bounds: Width=${boundingBox.width}, Height=${boundingBox.height}');

      return _calculateRealWorldDimensions(boundingBox);

    } catch (e) {
      print('ML Service Processing Error: $e');
      return null;
    } finally {
      objectDetector.close();
    }
  }

  MeasurementData _calculateRealWorldDimensions(Rect bounds) {
    const double pixelToCmRatio = 0.0264583333; 

    double lengthCm = bounds.height * pixelToCmRatio;
    double widthCm = bounds.width * pixelToCmRatio;
    double areaSqCm = lengthCm * widthCm;

    return MeasurementData(
      lengthCm: double.parse(lengthCm.toStringAsFixed(2)),
      widthCm: double.parse(widthCm.toStringAsFixed(2)),
      areaSqCm: double.parse(areaSqCm.toStringAsFixed(2)),
      depthMm: null,   // for p1 impl
      volumeCuCm: null // for p2 impl
    );
  }
}