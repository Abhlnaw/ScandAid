import 'package:flutter/material.dart';

class MeasurementData {
  final double lengthCm;
  final double widthCm;
  final double areaSqCm;
  final Rect boundingBox; // to store the pixel coordinates of the detected contour for future reference
  final double? depthMm;   // lack lidar cameras so nullable
  final double? volumeCuCm; // to do : calculate volume based off cross-section area & depth; figure if this is needed

  MeasurementData({
    required this.lengthCm,
    required this.widthCm,
    required this.areaSqCm,
    required this.boundingBox,
    this.depthMm,
    this.volumeCuCm,
  });
}