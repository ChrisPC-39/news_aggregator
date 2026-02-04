import 'package:hive/hive.dart';

import '../models/hive_models.dart';
import '../models/news_story_model.dart';

class GroupedStoriesCacheService {
  static const _boxName = 'groupedStories';

  Box<NewsStoryHive> get _box => Hive.box<NewsStoryHive>(_boxName);

  List<NewsStory> load() {
    return _box.values.map((e) => e.toNewsStory()).toList();
  }

  /// Load only saved stories
  List<NewsStory> loadSaved() {
    return _box.values
        .where((e) => e.isSaved)
        .map((e) => e.toNewsStory())
        .toList();
  }

  Future<void> save(List<NewsStory> stories) async {
    // Get all saved stories before clearing
    final savedStories = _box.values
        .where((e) => e.isSaved)
        .map((e) => e.toNewsStory())
        .toList();

    await _box.clear();

    // Re-add saved stories first
    for (var story in savedStories) {
      await _box.add(NewsStoryHive.fromNewsStory(story));
    }

    // Add new stories (but skip if they're already saved)
    final savedTitles = savedStories.map((s) => s.canonicalTitle).toSet();
    for (var story in stories) {
      if (!savedTitles.contains(story.canonicalTitle)) {
        await _box.add(NewsStoryHive.fromNewsStory(story));
      }
    }
  }

  /// Merge new stories into cache
  Future<void> merge(List<NewsStory> newStories) async {
    final cached = _box.values.map((e) => e.toNewsStory()).toList();

    // Simple merging: add only if canonicalTitle is new
    final existingTitles = cached.map((s) => s.canonicalTitle).toSet();
    final toAdd = newStories
        .where((s) => !existingTitles.contains(s.canonicalTitle))
        .toList();

    for (var story in toAdd) {
      await _box.add(NewsStoryHive.fromNewsStory(story));
    }
  }

  /// Toggle bookmark status for a story
  Future<void> toggleBookmark(String canonicalTitle, bool isSaved) async {
    // Find the story in the box
    final key = _box.keys.firstWhere(
          (k) {
        final story = _box.get(k);
        return story?.canonicalTitle == canonicalTitle;
      },
      orElse: () => null,
    );

    if (key != null) {
      final story = _box.get(key);
      if (story != null) {
        story.isSaved = isSaved;
        await _box.put(key, story);
      }
    }
  }

  /// Save a new story as bookmarked
  Future<void> saveBookmarkedStory(NewsStory story) async {
    // Check if story already exists
    final existingKey = _box.keys.firstWhere(
          (k) {
        final s = _box.get(k);
        return s?.canonicalTitle == story.canonicalTitle;
      },
      orElse: () => null,
    );

    story.isSaved = true;

    if (existingKey != null) {
      // Update existing story
      await _box.put(existingKey, NewsStoryHive.fromNewsStory(story));
    } else {
      // Add new story
      await _box.add(NewsStoryHive.fromNewsStory(story));
    }
  }

  /// Remove bookmark (but keep story in cache if it's recent)
  Future<void> removeBookmark(String canonicalTitle) async {
    final key = _box.keys.firstWhere(
          (k) {
        final story = _box.get(k);
        return story?.canonicalTitle == canonicalTitle;
      },
      orElse: () => null,
    );

    if (key != null) {
      final story = _box.get(key);
      if (story != null) {
        story.isSaved = false;
        await _box.put(key, story);
      }
    }
  }

  /// Update summary for a saved story
  Future<void> updateSummary(String canonicalTitle, String summary) async {
    final key = _box.keys.firstWhere(
          (k) {
        final story = _box.get(k);
        return story?.canonicalTitle == canonicalTitle;
      },
      orElse: () => null,
    );

    if (key != null) {
      final story = _box.get(key);
      if (story != null) {
        story.summary = summary;
        await _box.put(key, story);
      }
    }
  }
}