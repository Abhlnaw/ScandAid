import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/injury_record.dart';
import '../providers/history_provider.dart';
import '../widgets/healing_indicators_card.dart';
import '../widgets/injury_summary_card.dart';
import '../widgets/measurement_overlay.dart';

class ResultsScreen extends StatelessWidget {
  final InjuryRecord record;

  const ResultsScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final detection = record.detection;
    final measurements = record.measurements;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Scan Results', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: MeasurementOverlay(
                  imagePath: record.imagePath,
                  measurements: measurements,
                ),
              ),
            ),
            if (measurements.isEstimated)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Estimated region — add ML models for precise contour detection.',
                        style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: InjurySummaryCard(detection: detection),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: HealingIndicatorsCard(detection: detection),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    Text('Length: ${measurements.lengthCm} cm',
                        style: TextStyle(fontSize: 12, color: Colors.teal.shade800)),
                    Text('Width: ${measurements.widthCm} cm',
                        style: TextStyle(fontSize: 12, color: Colors.teal.shade800)),
                    Text(
                      'Area: ${measurements.areaSqCm} cm²',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _ComparisonSection(record: record),
          ],
        ),
      ),
    );
  }
}

class _ComparisonSection extends StatelessWidget {
  final InjuryRecord record;

  const _ComparisonSection({required this.record});

  @override
  Widget build(BuildContext context) {
    return Consumer<HistoryProvider>(
      builder: (context, history, _) {
        final previous = history.records
            .where((r) => r.id != record.id && r.timestamp.isBefore(record.timestamp))
            .fold<InjuryRecord?>(null, (prev, r) {
          if (prev == null || r.timestamp.isAfter(prev.timestamp)) return r;
          return prev;
        });

        if (previous == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'This is your first scan. Future scans will show healing progress here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          );
        }

        final change = history.areaChangePercent(record, previous);
        final improved = change != null && change < 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Healing Progress',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    change == null
                        ? 'Compared to previous scan'
                        : '${change.abs().toStringAsFixed(1)}% area ${improved ? 'reduction' : 'increase'} since last scan',
                    style: TextStyle(
                      color: improved ? Colors.green.shade700 : Colors.orange.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Previous: ${previous.timestamp.toString().substring(0, 16)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
