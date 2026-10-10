import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../models/scan.dart';
import 'storage_backend.dart';

class ScanRepository extends ChangeNotifier {
  final StorageBackend storage;
  ScanRepository({StorageBackend? storage})
    : storage = storage ?? StorageBackend();
  List<Scan> _scans = [];
  List<Scan> get scans => List.unmodifiable(_scans);
  String server = '';
  bool serverEnabled = false;
  bool _writing = false;
  bool get writing => _writing;

  Future<void> load() async {
    final raw = await storage.read();
    if (raw == null) return;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['version'] != 1) {
      throw const FormatException('Unsupported saved data version.');
    }
    final scans = (j['scans'] as List)
        .map((v) => Scan.fromJson(v as Map<String, dynamic>))
        .toList();
    _scans = scans..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    server = j['server'] as String? ?? '';
    serverEnabled = j['serverEnabled'] as bool? ?? false;
    notifyListeners();
  }

  Future<void> _save(List<Scan> next, String nextServer, bool enabled) async {
    if (_writing) throw StateError('A save is already in progress.');
    _writing = true;
    notifyListeners();
    try {
      await storage.write(
        jsonEncode({
          'version': 1,
          'scans': next.map((s) => s.toJson()).toList(),
          'server': nextServer,
          'serverEnabled': enabled,
        }),
      );
      _scans = next;
      server = nextServer;
      serverEnabled = enabled;
    } finally {
      _writing = false;
      notifyListeners();
    }
  }

  Future<void> saveScan(Scan scan) async {
    if (_scans.length >= 100) {
      throw StateError(
        'Export and remove older scans before adding more (100 scan limit).',
      );
    }
    await _save([scan, ..._scans], server, serverEnabled);
  }

  Future<void> delete(String id) =>
      _save(_scans.where((s) => s.id != id).toList(), server, serverEnabled);
  Future<void> settings(String url, bool enabled) =>
      _save(_scans, url, enabled);
  List<Scan> forWound(String name) => _scans
      .where((s) => s.woundName.toLowerCase() == name.trim().toLowerCase())
      .toList();
  String export() => const JsonEncoder.withIndent('  ').convert({
    'format': 'scandaid-export',
    'version': 1,
    'scans': _scans.map((s) => s.toJson()).toList(),
  });
  Future<int> importExport(String content) async {
    final imported = await compute(parseImport, content);
    final existing = _scans.map((s) => s.id).toSet();
    final additions = imported.where((s) => existing.add(s.id)).toList();
    if (_scans.length + additions.length > 100) {
      throw const FormatException('A journal can contain at most 100 scans.');
    }
    final merged = [..._scans, ...additions]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _save(merged, server, serverEnabled);
    return additions.length;
  }
}

List<Scan> parseImport(String content) {
  if (content.length > 160 * 1024 * 1024) {
    throw const FormatException('Backup exceeds the 160 MB limit.');
  }
  final j = jsonDecode(content);
  if (j is! Map ||
      j['version'] != 1 ||
      j['format'] != 'scandaid-export' ||
      j['scans'] is! List ||
      (j['scans'] as List).length > 100) {
    throw const FormatException(
      'Choose a ScandAid version 1 JSON export (at most 100 scans).',
    );
  }
  final result = <Scan>[];
  for (final raw in j['scans'] as List) {
    final s = Scan.fromJson(raw as Map<String, dynamic>);
    if (s.id.isEmpty ||
        s.id.length > 100 ||
        s.woundName.trim().isEmpty ||
        s.woundName.length > 60 ||
        s.notes.length > 2000 ||
        s.width < 32 ||
        s.height < 32 ||
        s.width > 1600 ||
        s.height > 1600 ||
        s.areaPixels < 9 ||
        s.areaPixels > s.width * s.height ||
        s.outline.length < 2 ||
        s.outline.length > 300 ||
        s.outline.any((p) => !_validPoint(p.dx, p.dy)) ||
        !s.bounds.left.isFinite ||
        !s.bounds.top.isFinite ||
        !s.bounds.width.isFinite ||
        !s.bounds.height.isFinite ||
        s.bounds.left < 0 ||
        s.bounds.top < 0 ||
        s.bounds.width <= 0 ||
        s.bounds.height <= 0 ||
        s.bounds.right > s.width ||
        s.bounds.bottom > s.height) {
      throw const FormatException(
        'A scan in this backup has invalid measurements or metadata.',
      );
    }
    if (s.imageBase64.length > 6 * 1024 * 1024) {
      throw const FormatException('An image in this backup is too large.');
    }
    final bytes = base64Decode(s.imageBase64);
    final info = img.JpegDecoder().startDecode(bytes);
    if (info == null || info.width != s.width || info.height != s.height) {
      throw const FormatException(
        'A backup photo has incorrect dimensions or format.',
      );
    }
    if (s.calibration != null) {
      final c = s.calibration!;
      if (!_validPoint(c.start.dx, c.start.dy) ||
          !_validPoint(c.end.dx, c.end.dy)) {
        throw const FormatException('Invalid scale reference.');
      }
      c.pixelsPerCm(s.width, s.height);
    }
    if (s.maskBase64 != null) {
      if (s.maskBase64!.length > 8 * 1024 * 1024) {
        throw const FormatException('A backup mask is too large.');
      }
      final info = img.PngDecoder().startDecode(base64Decode(s.maskBase64!));
      if (info == null || info.width != s.width || info.height != s.height) {
        throw const FormatException('A backup mask has incorrect dimensions.');
      }
    }
    final scores = s.classification.scores.values;
    if (scores.any((v) => !v.isFinite || v < 0 || v > 1) ||
        (scores.isNotEmpty &&
            (scores.reduce((a, b) => a + b) - 1).abs() > .01)) {
      throw const FormatException('A backup contains invalid model scores.');
    }
    result.add(s);
  }
  return result;
}

bool _validPoint(double x, double y) =>
    x.isFinite && y.isFinite && x >= 0 && x <= 1 && y >= 0 && y <= 1;
