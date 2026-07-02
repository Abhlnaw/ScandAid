import 'package:hive_flutter/hive_flutter.dart';

import '../models/injury_record.dart';
import 'logging_service.dart';

class HistoryService {
  HistoryService({LoggingService? logger}) : _logger = logger ?? LoggingService();

  static const String boxName = 'injury_records';

  final LoggingService _logger;
  Box<dynamic>? _box;

  Future<void> init() async {
    _box = await Hive.openBox(boxName);
    _logger.info('History database initialized (${_box!.length} records)');
  }

  Future<void> saveRecord(InjuryRecord record) async {
    await _box!.put(record.id, record.toJson());
    _logger.info('Saved injury record ${record.id}');
  }

  Future<List<InjuryRecord>> getAllRecords() async {
    final records = _box!.values
        .map((e) => InjuryRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return records;
  }

  Future<InjuryRecord?> getRecord(String id) async {
    final data = _box!.get(id);
    if (data == null) return null;
    return InjuryRecord.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> deleteRecord(String id) async {
    await _box!.delete(id);
    _logger.info('Deleted injury record $id');
  }

  Future<void> clearAll() async {
    await _box!.clear();
    _logger.info('Cleared all injury records');
  }

  int get recordCount => _box?.length ?? 0;
}
