import 'package:flutter/material.dart';

import '../models/injury_detection.dart';
import 'severity_gauge.dart';

class InjurySummaryCard extends StatelessWidget {
  final InjuryDetection detection;

  const InjurySummaryCard({super.key, required this.detection});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blueGrey.shade900,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    detection.patientSummary,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Colors.white10, height: 1),
            ),
            Text(
              'Type: ${detection.type.displayName}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SeverityGauge(
              severity: detection.severity,
              confidence: detection.confidenceScore,
            ),
            const SizedBox(height: 12),
            Text(
              'Care Step: ${detection.clinicalRecommendation}',
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
