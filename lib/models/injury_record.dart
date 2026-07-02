import 'injury_detection.dart';
import 'measurement_data.dart';

class InjuryRecord {
  final String id;
  final String imagePath;
  final DateTime timestamp;
  final InjuryDetection detection;
  final MeasurementData measurements;

  InjuryRecord({
    required this.id,
    required this.imagePath,
    required this.timestamp,
    required this.detection,
    required this.measurements,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        'timestamp': timestamp.toIso8601String(),
        'detection': detection.toJson(),
        'measurements': measurements.toJson(),
      };

  factory InjuryRecord.fromJson(Map<String, dynamic> json) => InjuryRecord(
        id: json['id'] as String,
        imagePath: json['imagePath'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        detection: InjuryDetection.fromJson(json['detection'] as Map<String, dynamic>),
        measurements:
            MeasurementData.fromJson(json['measurements'] as Map<String, dynamic>),
      );
}
