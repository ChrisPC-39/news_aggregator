import 'package:hive/hive.dart';

import '../globals.dart';

/// Tracks which news sources the user has turned off. Disabled sources are
/// skipped entirely during a crawl (see [CrawlerService.fetchAllSources])
/// instead of just being filtered out after the fact, so turning off a
/// noisy or slow source also speeds up refreshes.
///
/// Backed by a plain untyped Hive box holding a single `List<String>` of
/// disabled source domains — no HiveType/adapter or code-gen needed for
/// something this small.
class SourceSettingsService {
  static const _boxName = 'appSettings';
  static const _disabledKey = 'disabledSources';

  Box get _box => Hive.box(_boxName);

  String domainFor(String url) => Uri.parse(url).host.replaceFirst('www.', '');

  /// Domains (e.g. "digi24.ro") the user has disabled.
  Set<String> getDisabledSources() {
    final raw = _box.get(_disabledKey, defaultValue: const <String>[]) as List;
    return raw.cast<String>().toSet();
  }

  bool isEnabled(String domain) => !getDisabledSources().contains(domain);

  Future<void> setEnabled(String domain, bool enabled) async {
    final disabled = getDisabledSources();
    if (enabled) {
      disabled.remove(domain);
    } else {
      disabled.add(domain);
    }
    await _box.put(_disabledKey, disabled.toList());
  }

  Future<void> enableAll() => _box.put(_disabledKey, const <String>[]);

  Future<void> disableAll() {
    final allDomains = Globals.sourceConfigs.values.map(domainFor).toList();
    return _box.put(_disabledKey, allDomains);
  }

  /// Same shape as [Globals.sourceConfigs], filtered down to sources the
  /// user hasn't disabled. This is what the crawler should actually fetch.
  Map<String, String> getEnabledSourceConfigs() {
    final disabled = getDisabledSources();
    return Map.fromEntries(
      Globals.sourceConfigs.entries.where(
        (entry) => !disabled.contains(domainFor(entry.value)),
      ),
    );
  }
}
