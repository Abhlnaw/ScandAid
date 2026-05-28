import 'injury_enums.dart';

class InjuryDetection {
  final InjuryType type;
  final SeverityLevel severity;
  final double confidenceScore; // decimals, multiply by 100 on display end
  final String clinicalRecommendation;

  InjuryDetection({
    required this.type,
    required this.severity,
    required this.confidenceScore,
    required this.clinicalRecommendation,
  });
}