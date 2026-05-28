class MeasurementData {
  final double lengthCm;
  final double widthCm;
  final double areaSqCm;
  final double? depthMm;   // lack lidar cameras so nullable
  final double? volumeCuCm; // to do : calculate volume based off cross-section area & depth; figure if this is needed

  MeasurementData({
    required this.lengthCm,
    required this.widthCm,
    required this.areaSqCm,
    this.depthMm,
    this.volumeCuCm,
  });
}