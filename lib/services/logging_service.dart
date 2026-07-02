import 'package:flutter/foundation.dart';

class LoggingService {
  static const String _tag = 'ScandAid';

  void info(String message) {
    debugPrint('[$_tag][INFO] $message');
  }

  void warning(String message) {
    debugPrint('[$_tag][WARN] $message');
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[$_tag][ERROR] $message');
    if (error != null) debugPrint('  Cause: $error');
    if (stackTrace != null) debugPrint('  Stack: $stackTrace');
  }
}
