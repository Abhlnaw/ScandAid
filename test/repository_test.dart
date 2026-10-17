import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:scandaid/services/scan_repository.dart';
import 'package:scandaid/services/storage_native.dart';
import 'support.dart';

void main() {
  test(
    'saved scans, calibration and server preferences survive reload',
    () async {
      final storage = MemoryStorage();
      final repo = ScanRepository(storage: storage);
      await repo.settings('http://127.0.0.1:8000', true);
      await repo.saveScan(testScan());
      final restored = ScanRepository(storage: storage);
      await restored.load();
      expect(restored.scans.single.areaCm2, 20);
      expect(restored.scans.single.notes, 'Test note');
      expect(restored.serverEnabled, isTrue);
      expect(restored.forWound(' left KNEE '), hasLength(1));
    },
  );
  test('a failed disk write leaves in-memory records intact', () async {
    final storage = MemoryStorage();
    final repo = ScanRepository(storage: storage);
    await repo.saveScan(testScan());
    storage.fail = true;
    await expectLater(repo.delete('test'), throwsStateError);
    expect(repo.scans, hasLength(1));
    expect(repo.writing, isFalse);
  });
  test(
    'exports restore without duplicate ids or changing inference settings',
    () async {
      final source = ScanRepository(storage: MemoryStorage());
      await source.saveScan(testScan());
      final restored = ScanRepository(storage: MemoryStorage());
      expect(await restored.importExport(source.export()), 1);
      expect(await restored.importExport(source.export()), 0);
      expect(restored.serverEnabled, isFalse);
      expect(restored.scans.single.areaCm2, 20);
    },
  );
  test('invalid import cannot overwrite existing scans', () async {
    final repo = ScanRepository(storage: MemoryStorage());
    await repo.saveScan(testScan());
    final broken = testScan(id: 'bad').toJson()..['areaPixels'] = -1;
    await expectLater(
      repo.importExport(
        jsonEncode({
          'format': 'scandaid-export',
          'version': 1,
          'scans': [broken],
        }),
      ),
      throwsFormatException,
    );
    expect(repo.scans.single.id, 'test');
  });
  test(
    'native snapshots are replaced and deletion does not leave an old backup',
    () async {
      final directory = await Directory.systemTemp.createTemp('scandaid-test-');
      addTearDown(() => directory.delete(recursive: true));
      final storage = StorageBackend(directory: directory);
      await storage.write('first');
      await storage.write('second');
      expect(await storage.read(), 'second');
      expect(
        await File('${directory.path}/scandaid.json.bak').exists(),
        isFalse,
      );
    },
  );
  test('interrupted rename recovers previous snapshot', () async {
    final directory = await Directory.systemTemp.createTemp('scandaid-test-');
    addTearDown(() => directory.delete(recursive: true));
    await File('${directory.path}/scandaid.json.bak').writeAsString('previous');
    expect(await StorageBackend(directory: directory).read(), 'previous');
  });
}
