//worry about like consumer privacy later, this should all be stored locally I think

import 'injury_detection.dart';
import 'measurement_data.dart';

class InjuryRecord {
  final String id;              
  final String imagePath;      // path on phone, check if differs between android/IOS  
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
}