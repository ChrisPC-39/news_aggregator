import '../globals.dart';
import '../models/article_model.dart';
import '../models/news_story_model.dart';

class ScoreService {

  /// Optimized overlap using pre-computed tokens from the Article model
  double tokenOverlap(Article a, Article b) {
    final setA = a.normalizedTokens;
    final setB = b.normalizedTokens;

    if (setA.isEmpty || setB.isEmpty) return 0;

    // Fast intersection count without creating a new Set object
    int intersectionCount = 0;
    for (final token in setA) {
      if (setB.contains(token)) {
        intersectionCount++;
      }
    }

    final unionCount = setA.length + setB.length - intersectionCount;
    return intersectionCount / unionCount;
  }

  double similarityScore(Article a, Article b) {
    // Jaccard similarity of titles
    final titleScore = tokenOverlap(a, b);

    // We keep the logic simple for speed, but you could add description
    // overlap here if Article pre-calculates description tokens too.
    double score = titleScore;

    // Penalize same source to encourage diversity in groups
    if (a.sourceName == b.sourceName) {
      score *= 0.5;
    }

    return score;
  }

  /// Groups articles using an Inverted Index to avoid O(n^2) complexity
  List<NewsStory> groupArticles(List<Article> articles) {
    final List<NewsStory> stories = [];

    // Index: Word -> List of Stories containing that word in the title
    final Map<String, List<NewsStory>> wordIndex = {};

    for (final article in articles) {
      NewsStory? matchedStory;
      final tokens = article.normalizedTokens;

      // 1. Find candidate stories that share at least one word in the title
      final Set<NewsStory> candidates = {};
      for (final token in tokens) {
        if (wordIndex.containsKey(token)) {
          candidates.addAll(wordIndex[token]!);
        }
      }

      // 2. Only compare against candidates (usually < 1% of total stories)
      for (final story in candidates) {
        final representative = story.articles.first;

        if (similarityScore(article, representative) >= 0.25 &&
            representative.sourceName != article.sourceName) {
          matchedStory = story;
          break;
        }
      }

      if (matchedStory != null) {
        matchedStory.articles.add(article);
        // Update image if the story doesn't have one yet
        if (storyHasNoImage(matchedStory) && article.urlToImage != null) {
          matchedStory.imageUrl = article.urlToImage;
        }
      } else {
        // 3. Create a new story if no match found
        final newStory = NewsStory(
          canonicalTitle: article.title,
          summary: article.description,
          articles: [article],
          storyTypes: article.category != null ? [article.category!] : null,
          imageUrl: article.urlToImage,
        );
        stories.add(newStory);

        // 4. Index the new story's tokens
        for (final token in tokens) {
          wordIndex.putIfAbsent(token, () => []).add(newStory);
        }
      }
    }

    // Post-processing: Infer types and summaries
    for (final story in stories) {
      _finalizeStory(story);
    }

    return stories;
  }

  bool storyHasNoImage(NewsStory story) =>
      story.imageUrl == null || story.imageUrl!.isEmpty;

  void _finalizeStory(NewsStory story) {
    // Pick the best summary (longest description usually works well)
    story.summary = story.articles
        .map((a) => a.description)
        .firstWhere((d) => d.isNotEmpty, orElse: () => "");

    final existingTypes = story.storyTypes?.map((t) => t.toLowerCase()).toSet() ?? {};
    final inferred = inferStoryTypes(story)
        .map((e) => e.toLowerCase())
        .toSet()
        .difference(existingTypes)
        .toList();

    story.inferredStoryTypes = inferred.isEmpty ? null : inferred;
  }

  /// Fast type inference with optimized Romanian normalization
  List<String> inferStoryTypes(NewsStory story) {
    // 1. Pre-normalize the story text once
    final rawText = "${story.canonicalTitle} ${story.summary} ${story.articles.map((a) => a.title).join(' ')}".toLowerCase();

    final normalizedText = rawText
        .replaceAll('ă', 'a').replaceAll('â', 'a')
        .replaceAll('î', 'i').replaceAll('ș', 's')
        .replaceAll('ț', 't');

    final Map<String, int> categoryScores = {};

    for (final entry in Globals.storyTypeKeywords.entries) {
      final category = entry.key;

      // Check negative keywords (if any match, skip category)
      final negatives = Globals.storyTypeNegativeKeywords[category] ?? [];
      if (negatives.any((neg) => normalizedText.contains(neg))) continue;

      // Count keyword matches
      int score = 0;
      for (final keyword in entry.value) {
        if (normalizedText.contains(keyword)) {
          score++;
        }
      }

      if (score > 0) categoryScores[category] = score;
    }

    if (categoryScores.isEmpty) return ['General'];

    // Sort by score descending
    final sorted = categoryScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map((e) => e.key).toList();
  }

  List<NewsStory> groupArticlesIncremental(List<NewsStory> existing, List<Article> newArticles) {
    final existingTitles = existing.map((s) => s.canonicalTitle).toSet();
    final newStories = groupArticles(newArticles);
    final merged = [...existing];

    for (var story in newStories) {
      if (!existingTitles.contains(story.canonicalTitle)) {
        merged.add(story);
      } else {
        final idx = merged.indexWhere((s) => s.canonicalTitle == story.canonicalTitle);
        merged[idx].articles.addAll(story.articles);
      }
    }
    return merged;
  }
}