import 'package:hive/hive.dart';
import '../models/hive_models.dart';

class SimilaritySettingsService {
  static const _boxName = 'similaritySettings';
  static const _settingsKey = 'threshold';

  Box<SimilaritySettings> get _box => Hive.box<SimilaritySettings>(_boxName);

  /// Get current similarity threshold (default: 0.25)
  double getThreshold() {
    final settings = _box.get(_settingsKey);
    return settings?.threshold ?? 0.25;
  }

  /// Update similarity threshold
  Future<void> setThreshold(double threshold) async {
    // Validate range (typically 0.0 to 1.0)
    if (threshold < 0.0 || threshold > 1.0) {
      throw ArgumentError('Threshold must be between 0.0 and 1.0');
    }

    await _box.put(_settingsKey, SimilaritySettings(threshold: threshold));
  }

  /// Reset to default
  // Future<void> resetToDefault() async {
  //   await _box.put(_settingsKey, SimilaritySettings(threshold: 0.25));
  // }
}