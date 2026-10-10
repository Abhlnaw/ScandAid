import 'package:shared_preferences/shared_preferences.dart';

class StorageBackend {
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString('scandaid.snapshot');
  Future<void> write(String content) async {
    if (!await (await SharedPreferences.getInstance()).setString(
      'scandaid.snapshot',
      content,
    )) {
      throw StateError(
        'Browser storage is full. Export and remove older scans.',
      );
    }
  }
}
