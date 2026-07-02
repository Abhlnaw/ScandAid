import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'logging_service.dart';

class StorageService {
  StorageService({LoggingService? logger}) : _logger = logger ?? LoggingService();

  final LoggingService _logger;
  final Uuid _uuid = const Uuid();

  Future<String> getScansDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${appDir.path}/scans');
    if (!await scansDir.exists()) {
      await scansDir.create(recursive: true);
    }
    return scansDir.path;
  }

  Future<String> saveImage(String sourcePath) async {
    final scansDir = await getScansDirectory();
    final fileName = '${_uuid.v4()}.jpg';
    final destination = '$scansDir/$fileName';
    await File(sourcePath).copy(destination);
    _logger.info('Saved scan image to $destination');
    return destination;
  }

  Future<void> deleteImage(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      _logger.info('Deleted image at $path');
    }
  }

  Future<bool> imageExists(String path) => File(path).exists();
}
