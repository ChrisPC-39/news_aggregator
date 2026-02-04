import 'package:hive/hive.dart';

import '../models/hive_models.dart';
import '../models/news_story_model.dart';

class GroupedStoriesCacheService {
  static const _boxName = 'groupedStories';

  Box<NewsStoryHive> get _box => Hive.box<NewsStoryHive>(_boxName);

  List<NewsStory> load() {
    return _box.values.map((e) => e.toNewsStory()).toList();
  }

  Future<void> save(List<NewsStory> stories) async {
    await _box.clear(); // optional: clear old cache
    for (var story in stories) {
      await _box.add(NewsStoryHive.fromNewsStory(story));
    }
  }

  /// Merge new stories into cache
  Future<void> merge(List<NewsStory> newStories) async {
    final cached = _box.values.map((e) => e.toNewsStory()).toList();

    // Simple merging: add only if canonicalTitle is new
    final existingTitles = cached.map((s) => s.canonicalTitle).toSet();
    final toAdd = newStories.where((s) => !existingTitles.contains(s.canonicalTitle)).toList();

    for (var story in toAdd) {
      await _box.add(NewsStoryHive.fromNewsStory(story));
    }
  }
}
