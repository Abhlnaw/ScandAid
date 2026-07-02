import 'package:flutter/material.dart';

import '../models/injury_record.dart';
import '../services/history_service.dart';
import '../services/logging_service.dart';
import '../services/storage_service.dart';

class HistoryProvider extends ChangeNotifier {
  HistoryProvider({
    HistoryService? historyService,
    StorageService? storageService,
    LoggingService? logger,
  })  : _historyService = historyService ?? HistoryService(),
        _storageService = storageService ?? StorageService(),
        _logger = logger ?? LoggingService();

  final HistoryService _historyService;
  final StorageService _storageService;
  final LoggingService _logger;

  List<InjuryRecord> records = [];
  bool isLoading = false;
  InjuryRecord? selectedRecord;

  Future<void> loadRecords() async {
    isLoading = true;
    notifyListeners();

    try {
      records = await _historyService.getAllRecords();
    } catch (e, stack) {
      _logger.error('Failed to load history', e, stack);
    }

    isLoading = false;
    notifyListeners();
  }

  void selectRecord(InjuryRecord record) {
    selectedRecord = record;
    notifyListeners();
  }

  Future<void> deleteRecord(String id) async {
    final record = records.firstWhere((r) => r.id == id);
    await _historyService.deleteRecord(id);
    await _storageService.deleteImage(record.imagePath);
    records.removeWhere((r) => r.id == id);
    if (selectedRecord?.id == id) selectedRecord = null;
    notifyListeners();
  }

  /// Compares two records — positive area delta means the injury grew.
  double? areaChangePercent(InjuryRecord newer, InjuryRecord older) {
    if (older.measurements.areaSqCm == 0) return null;
    final delta = newer.measurements.areaSqCm - older.measurements.areaSqCm;
    return (delta / older.measurements.areaSqCm) * 100;
  }

  InjuryRecord? get previousRecord {
    if (selectedRecord == null || records.length < 2) return null;
    final index = records.indexWhere((r) => r.id == selectedRecord!.id);
    if (index < 0 || index >= records.length - 1) return null;
    return records[index + 1];
  }
}
