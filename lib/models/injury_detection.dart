import 'injury_enums.dart';

class InjuryDetection {
  final InjuryType type;
  final SeverityLevel severity;
  final double confidenceScore;
  final String clinicalRecommendation;
  final String patientSummary;
  final double erythemaScore;
  final double structuralDisruption;
  final String primaryTissueColor;

  InjuryDetection({
    required this.type,
    required this.severity,
    required this.confidenceScore,
    required this.clinicalRecommendation,
    required this.patientSummary,
    required this.erythemaScore,
    required this.structuralDisruption,
    required this.primaryTissueColor,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'severity': severity.name,
        'confidenceScore': confidenceScore,
        'clinicalRecommendation': clinicalRecommendation,
        'patientSummary': patientSummary,
        'erythemaScore': erythemaScore,
        'structuralDisruption': structuralDisruption,
        'primaryTissueColor': primaryTissueColor,
      };

  factory InjuryDetection.fromJson(Map<String, dynamic> json) => InjuryDetection(
        type: InjuryType.values.byName(json['type'] as String),
        severity: SeverityLevel.values.byName(json['severity'] as String),
        confidenceScore: (json['confidenceScore'] as num).toDouble(),
        clinicalRecommendation: json['clinicalRecommendation'] as String,
        patientSummary: json['patientSummary'] as String,
        erythemaScore: (json['erythemaScore'] as num).toDouble(),
        structuralDisruption: (json['structuralDisruption'] as num).toDouble(),
        primaryTissueColor: json['primaryTissueColor'] as String,
      );
}
