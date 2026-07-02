import 'package:flutter/material.dart';

import '../models/injury_enums.dart';

class SeverityGauge extends StatelessWidget {
  final SeverityLevel severity;
  final double confidence;

  const SeverityGauge({
    super.key,
    required this.severity,
    required this.confidence,
  });

  Color get _color => switch (severity) {
        SeverityLevel.minor => Colors.green,
        SeverityLevel.mild => Colors.lightGreen,
        SeverityLevel.moderate => Colors.orange,
        SeverityLevel.severe => Colors.deepOrange,
        SeverityLevel.critical => Colors.red,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Severity: ${severity.shortLabel}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              'Level ${severity.score}/5',
              style: TextStyle(color: _color, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: severity.score / 5,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            color: _color,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              severity.displayName,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            Text(
              '${(confidence * 100).toStringAsFixed(0)}% confidence',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}
