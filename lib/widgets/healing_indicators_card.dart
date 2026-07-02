import 'package:flutter/material.dart';

import '../models/injury_detection.dart';

class HealingIndicatorsCard extends StatelessWidget {
  final InjuryDetection detection;

  const HealingIndicatorsCard({super.key, required this.detection});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Healing Characteristics',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            _indicatorRow(
              label: 'Surrounding Redness',
              value: detection.erythemaScore > 0.5 ? 'Moderate' : 'Normal',
              progress: detection.erythemaScore,
              color: Colors.redAccent.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 16),
            _indicatorRow(
              label: 'Wound Edge Separation',
              value: detection.structuralDisruption > 0.5 ? 'Irregular' : 'Secure',
              progress: detection.structuralDisruption,
              color: Colors.teal.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Tissue: ${detection.primaryTissueColor}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _indicatorRow({
    required String label,
    required String value,
    required double progress,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress.clamp(0, 1),
          backgroundColor: Colors.grey.shade100,
          color: color,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }
}
