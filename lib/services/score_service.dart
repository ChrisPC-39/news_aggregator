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

    // Penalize same source (but don't make it 0)
    if (a.sourceName == b.sourceName) {
      score *= 0.5;
    }

    return score;
  }

  /// Extract categories from articles and infer additional ones
  void categorizeStory(NewsStory story) {
    // 1. Get categories directly from articles
    final articleCategories = <String>{};
    for (final article in story.articles) {
      if (article.category != null && article.category!.isNotEmpty) {
        articleCategories.add(article.category!);
      }
    }

    // 2. Infer categories from content using keyword matching
    final inferredCategories = _inferCategoriesFromContent(story);

    // 3. Remove inferred categories that already exist in article categories
    final uniqueInferred =
        inferredCategories
            .where((cat) => !articleCategories.contains(cat))
            .toList();

    // 4. Assign to story
    story.storyTypes =
        articleCategories.isEmpty ? ['General'] : articleCategories.toList();

    story.inferredStoryTypes = uniqueInferred.isEmpty ? null : uniqueInferred;
  }

  /// Infer categories from story content using keyword matching
  List<String> _inferCategoriesFromContent(NewsStory story) {
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

    // Return the category names
    return matchingTypes.map((e) => e.key).toList();
  }

  List<NewsStory> groupArticles(List<Article> articles) {
    final List<NewsStory> stories = [];
    final Set<String> processedUrls =
        {}; // Track which articles we've already placed
    // int duplicateUrls = 0;

    // print('🔍 Starting grouping with ${articles.length} input articles');

    for (final article in articles) {
      // Skip if already processed
      if (processedUrls.contains(article.url)) {
        // duplicateUrls++;
        // print('⚠️ Duplicate URL skipped: ${article.url}');
        continue;
      }

      bool added = false;

      for (final story in stories) {
        final representative = story.articles.first;

        // Check similarity
        final similarity = similarityScore(article, representative);

        // Group if similar enough (regardless of source)
        if (similarity >= 0.30) {
          // Check if this exact URL is already in the story
          final alreadyInStory = story.articles.any(
            (a) => a.url == article.url,
          );

          if (!alreadyInStory) {
            story.articles.add(article);
            processedUrls.add(article.url);

            // Pick a representative image if not set
            if (story.imageUrl == null &&
                article.urlToImage != null &&
                article.urlToImage!.isNotEmpty) {
              story.imageUrl = article.urlToImage;
            }

            added = true;
            break;
          } else {
            // It's a duplicate URL, mark as processed but don't add
            // duplicateUrls++;
            added = true;
            break;
          }
        }
      }

      if (!added) {
        // Create new story for this article
        stories.add(
          NewsStory(
            canonicalTitle: article.title,
            summary: article.description,
            articles: [article],
            storyTypes: null,
            imageUrl: article.urlToImage,
          ),
        );
        processedUrls.add(article.url);
      }
    }

    // After grouping, update summary and categorize each story
    for (final story in stories) {
      // Pick first non-empty description among all grouped articles
      story.summary =
          story.articles
              .firstWhere(
                (a) => a.description.isNotEmpty,
                orElse: () => story.articles.first,
              )
              .description;

      // Categorize story (sets both storyTypes and inferredStoryTypes)
      categorizeStory(story);
    }

    // final totalArticlesInStories = stories.fold<int>(
    //   0,
    //   (sum, story) => sum + story.articles.length,
    // );

    // print('📊 Grouping complete:');
    // print('  - Input: ${articles.length} articles');
    // print('  - Output: ${stories.length} stories');
    // print('  - Articles in stories: $totalArticlesInStories');
    // print('  - Unique URLs processed: ${processedUrls.length}');
    // print('  - Duplicate URLs skipped: $duplicateUrls');
    // print('  - Missing: ${articles.length - totalArticlesInStories - duplicateUrls}');

    return stories;
  }

  List<NewsStory> groupArticlesIncremental(
    List<NewsStory> existing,
    List<Article> newArticles,
  ) {
    // 1️⃣ Convert existing canonicalTitles to a set
    final existingTitles = existing.map((s) => s.canonicalTitle).toSet();

    // 2️⃣ Group only new articles
    final newStories = groupArticles(newArticles);

    // 3️⃣ Merge
    final merged = [...existing];

    for (var story in newStories) {
      if (!existingTitles.contains(story.canonicalTitle)) {
        merged.add(story);
      } else {
        // Merge new articles into existing story
        final idx = merged.indexWhere(
          (s) => s.canonicalTitle == story.canonicalTitle,
        );
        merged[idx].articles.addAll(story.articles);
      }
    }

    return merged;
  }
}
