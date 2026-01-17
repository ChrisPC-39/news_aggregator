import '../globals.dart';
import '../models/article_model.dart';
import '../models/news_story_model.dart';

class ScoreService {
  String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double tokenOverlap(String a, String b) {
    final setA = normalize(a).split(' ').toSet();
    final setB = normalize(b).split(' ').toSet();

    if (setA.isEmpty || setB.isEmpty) return 0;

    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;

    return intersection / union;
  }

  String? pickRepresentativeImage(List<Article> articles) {
    for (final article in articles) {
      if (article.urlToImage != null && article.urlToImage!.isNotEmpty) {
        return article.urlToImage;
      }
    }
    return null;
  }

  double similarityScore(Article a, Article b) {
    final titleTitle = tokenOverlap(a.title, b.title);
    final titleDesc = tokenOverlap(a.title, b.description);

    double score = (titleTitle * 0.7) + (titleDesc * 0.3);

    // Penalize same source
    if (a.sourceName == b.sourceName) {
      score *= 0.5;
    }

    return score;
  }

  List<String> inferStoryTypes(NewsStory story) {
    // Combine all relevant text (already lowercased)
    final text = [
      story.canonicalTitle.toLowerCase(),
      story.summary == null ? "" : story.summary!.toLowerCase(),
      ...story.articles.map((a) => a.title.toLowerCase()),
      ...story.articles.map((a) => a.description.toLowerCase()),
    ].join(' ');

    // Normalize Romanian diacritics
    final normalizedText = text.replaceAllMapped(RegExp(r'[ăâîșțĂÂÎȘȚ]'), (
      match,
    ) {
      final char = match.group(0)!.toLowerCase();
      switch (char) {
        case 'ă':
        case 'â':
          return 'a';
        case 'î':
          return 'i';
        case 'ș':
          return 's';
        case 'ț':
          return 't';
        default:
          return char;
      }
    });

    // Map to store category scores
    final Map<String, int> categoryScores = {};

    for (final entry in Globals.storyTypeKeywords.entries) {
      final categoryName = entry.key;

      // Check for negative keywords first - if found, skip this category
      final negativeKeywords =
          Globals.storyTypeNegativeKeywords[categoryName] ?? [];
      bool hasNegativeMatch = false;

      for (final negKeyword in negativeKeywords) {
        if (normalizedText.contains(negKeyword)) {
          hasNegativeMatch = true;
          break;
        }
      }

      // Skip this category if negative keyword found
      if (hasNegativeMatch) {
        continue;
      }

      // Sort keywords by length (longest first) to prioritize multi-word phrases
      final sortedKeywords =
          entry.value.toList()..sort((a, b) => b.length.compareTo(a.length));

      // Use a Set to avoid counting the same keyword twice
      final matchedKeywords = <String>{};

      for (final keyword in sortedKeywords) {
        if (normalizedText.contains(keyword)) {
          matchedKeywords.add(keyword);
        }
      }

      final score = matchedKeywords.length;

      if (score > 0) {
        categoryScores[categoryName] = score;
      }
    }

    // Adaptive threshold
    final threshold = 1;

    // Get all categories that meet the threshold, sorted by score
    final matchingTypes =
        categoryScores.entries
            .where((entry) => entry.value >= threshold)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    // Return the category names, or ['General'] if none match
    if (matchingTypes.isEmpty) {
      return ['General'];
    }

    return matchingTypes.map((e) => e.key).toList();
  }

  List<NewsStory> groupArticles(List<Article> articles) {
    final List<NewsStory> stories = [];

    for (final article in articles) {
      bool added = false;

      for (final story in stories) {
        final representative = story.articles.first;

        if (similarityScore(article, representative) >= 0.30 &&
            representative.sourceName != article.sourceName) {
          story.articles.add(article);

          // Pick a representative image if not set
          if (story.imageUrl == null &&
              article.urlToImage != null &&
              article.urlToImage!.isNotEmpty) {
            story.imageUrl = article.urlToImage;
          }

          added = true;
          break;
        }
      }

      if (!added) {
        final storyType = article.category == null ? null : [article.category!];

        stories.add(
          NewsStory(
            canonicalTitle: article.title,
            summary: article.description,
            articles: [article],
            storyTypes: storyType,
            imageUrl: article.urlToImage,
          ),
        );
      }
    }

    // After grouping, update summary and infer story types for each story
    for (final story in stories) {
      // Pick first non-empty description among all grouped articles
      story.summary =
          story.articles
              .firstWhere(
                (a) => a.description.isNotEmpty,
                orElse: () => story.articles.first,
              )
              .description;

      // Normalize existing story types for comparison
      final existingTypes =
          story.storyTypes?.map((t) => t.toLowerCase()).toSet() ?? {};

      final inferred = inferStoryTypes(story)
          .map((e) => e.toLowerCase())
          .toSet()
          .difference(existingTypes)
          .toList();

      story.inferredStoryTypes = inferred.isEmpty ? null : inferred;
    }

    return stories;
  }

  List<NewsStory> groupArticlesIncremental(
    List<NewsStory> existing,
    List<Article> newArticles,
  ) {
    // 1️⃣ Convert existing canonicalTitles to a set
    final existingTitles = existing.map((s) => s.canonicalTitle).toSet();

    // 2️⃣ Group only new articles
    final newStories = groupArticles(newArticles); // reuse your normal grouping

    // 3️⃣ Merge
    final merged = [...existing];

    for (var story in newStories) {
      if (!existingTitles.contains(story.canonicalTitle)) {
        merged.add(story);
      } else {
        // Optional: merge new articles into existing story
        final idx = merged.indexWhere(
          (s) => s.canonicalTitle == story.canonicalTitle,
        );
        merged[idx].articles.addAll(story.articles);
      }
    }

    return merged;
  }
}
