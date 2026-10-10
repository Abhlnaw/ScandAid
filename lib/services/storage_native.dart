import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageBackend {
  final Directory? directory;
  StorageBackend({this.directory});
  Future<File> _file() async {
    final dir = directory ?? await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}/scandaid.json');
  }

  Future<String?> read() async {
    final file = await _file();
    if (await file.exists()) return file.readAsString();
    // Restore the previous snapshot if interrupted between rename operations.
    final backup = File('${file.path}.bak');
    return await backup.exists() ? backup.readAsString() : null;
  }

  Future<void> write(String content) async {
    final file = await _file();
    final pending = File('${file.path}.pending');
    await pending.writeAsString(content, flush: true);
    final backup = File('${file.path}.bak');
    if (await file.exists()) {
      if (await backup.exists()) await backup.delete();
      await file.rename(backup.path);
    }
    await pending.rename(file.path);
    // A deleted photo must not remain in a stale backup after a successful save.
    if (await backup.exists()) await backup.delete();
  }
}
