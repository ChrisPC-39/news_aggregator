import 'package:hive/hive.dart';

import '../models/hive_models.dart';

/// Records source-crawl failures (timeouts, network/parse errors) so they
/// can be reviewed later from the Logs screen. Kept intentionally simple —
/// a capped, append-only Hive box, mirroring the other cache services.
class CrawlLogService {
  static const _boxName = 'crawlLogs';

  /// Oldest entries beyond this count are dropped so the box can't grow
  /// unbounded if a source is flaky for a long time.
  static const _maxEntries = 200;

  Box<CrawlLogHive> get _box => Hive.box<CrawlLogHive>(_boxName);

  Future<void> logTimeout({required String sourceName, required String url}) {
    return _log(
      sourceName: sourceName,
      url: url,
      status: 'Timeout',
      message: 'Timed out after 10s and was skipped',
    );
  }

  Future<void> logError({
    required String sourceName,
    required String url,
    required Object error,
  }) {
    return _log(
      sourceName: sourceName,
      url: url,
      status: 'Error',
      message: error.toString(),
    );
  }

  Future<void> _log({
    required String sourceName,
    required String url,
    required String status,
    required String message,
  }) async {
    await _box.add(
      CrawlLogHive(
        sourceName: sourceName,
        url: url,
        status: status,
        message: message,
        timestamp: DateTime.now(),
      ),
    );

    // Trim oldest entries once we exceed the cap.
    if (_box.length > _maxEntries) {
      final overflow = _box.length - _maxEntries;
      final keysToDelete = _box.keys.take(overflow).toList();
      await _box.deleteAll(keysToDelete);
    }
  }

  /// Newest first.
  List<CrawlLogHive> getLogs() {
    return _box.values.toList().reversed.toList();
  }

  /// Emits a refreshed, newest-first list whenever the log box changes.
  Stream<List<CrawlLogHive>> watchLogs() {
    return _box.watch().map((_) => getLogs());
  }

  Future<void> clear() => _box.clear();
}
