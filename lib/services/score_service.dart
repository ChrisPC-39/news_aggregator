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
    final uniqueInferred = inferredCategories
        .where((cat) => !articleCategories.contains(cat))
        .toList();

    // 4. Assign to story
    story.storyTypes = articleCategories.isEmpty
        ? ['General']
        : articleCategories.toList();

    story.inferredStoryTypes = uniqueInferred.isEmpty
        ? null
        : uniqueInferred;
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
    final matchingTypes = categoryScores.entries
        .where((entry) => entry.value >= threshold)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Return the category names
    return matchingTypes.map((e) => e.key).toList();
  }

  Article _storyAnchor(NewsStory story) {
    return story.articles.first;
  }


  /// Ultra-fast LSH-based grouping with tunable similarity threshold
  /// Lower threshold = more grouping (0.2-0.4 recommended)
  List<NewsStory> groupArticlesFast(List<Article> articles, {double threshold = 0.25}) {
    print('🚀 LSH grouping started for ${articles.length} articles (threshold: $threshold)');
    final stopwatch = Stopwatch()..start();

    // Step 1: Create fingerprints and LSH signatures
    final fingerprints = <Article, Set<String>>{};
    final lshSignatures = <Article, List<int>>{};

    for (final article in articles) {
      final fingerprint = _createFingerprint(article);
      fingerprints[article] = fingerprint;
      lshSignatures[article] = _createLSHSignature(fingerprint);
    }
    print('  ⏱️  Fingerprints & LSH created: ${stopwatch.elapsedMilliseconds}ms');

    // Step 2: Use LSH to bucket similar articles (more lenient bucketing)
    final buckets = <String, List<Article>>{};

    for (final article in articles) {
      final signature = lshSignatures[article]!;

      // Create more buckets with single hash values (not pairs)
      // This increases recall - articles are in multiple buckets
      for (int i = 0; i < signature.length; i++) {
        final bucketKey = 'hash_${i}_${signature[i]}';
        buckets[bucketKey] = (buckets[bucketKey] ?? [])..add(article);
      }
    }
    print('  ⏱️  LSH bucketing: ${stopwatch.elapsedMilliseconds}ms (${buckets.length} buckets)');

    // Step 3: Group articles within buckets
    final stories = <NewsStory>[];
    final processed = <Article>{};

    for (final article in articles) {
      if (processed.contains(article)) continue;

      final articleFingerprint = fingerprints[article]!;
      final storyArticles = <Article>[article];
      processed.add(article);

      // Get candidate articles from all LSH buckets this article belongs to
      final candidates = <Article>{};
      final signature = lshSignatures[article]!;

      for (int i = 0; i < signature.length; i++) {
        final bucketKey = 'hash_${i}_${signature[i]}';
        if (buckets.containsKey(bucketKey)) {
          candidates.addAll(buckets[bucketKey]!);
        }
      }

      // If LSH found too few candidates, add a random sample for broader matching
      // This catches edge cases where synonyms cause bucket misses
      if (candidates.length < 20) {
        final remaining = articles.where((a) => !processed.contains(a) && a != article).toList();
        if (remaining.isNotEmpty) {
          // Add up to 30 random candidates for comparison
          remaining.shuffle();
          candidates.addAll(remaining.take(30));
        }
      }

      // Compare with candidates using fingerprint similarity
      for (final candidate in candidates) {
        if (processed.contains(candidate)) continue;
        if (candidate == article) continue;

        // final candidateFingerprint = fingerprints[candidate]!;
        // final similarity = _fingerprintSimilarity(articleFingerprint, candidateFingerprint);
        final similarity = similarityScore(article, candidate);

        if (similarity >= threshold) {
          storyArticles.add(candidate);
          processed.add(candidate);
        }
      }

      // Create story
      stories.add(
        NewsStory(
          canonicalTitle: article.title,
          summary: article.description ?? '',
          articles: storyArticles,
          storyTypes: null,
          imageUrl: article.urlToImage,
        ),
      );

      // Uncomment for debugging:
      // if (storyArticles.length > 1) {
      //   print('  ✅ Story with ${storyArticles.length} articles (similarity threshold: $threshold)');
      // }
    }

    print('  ⏱️  Grouping logic: ${stopwatch.elapsedMilliseconds}ms');

    // Step 4: Post-process stories
    for (final story in stories) {
      story.summary = story.articles
          .firstWhere(
            (a) => a.description.isNotEmpty,
        orElse: () => story.articles.first,
      )
          .description ?? '';

      categorizeStory(story);
    }

    stopwatch.stop();

    final multiArticleStories = stories.where((s) => s.articles.length > 1).length;
    final totalGroupedArticles = stories.fold<int>(0, (sum, s) => s.articles.length > 1 ? sum + s.articles.length : sum);

    print('✅ LSH grouping complete: ${stories.length} stories in ${stopwatch.elapsedMilliseconds}ms');
    print('  📊 Multi-article stories: $multiArticleStories (${totalGroupedArticles} articles grouped)');
    print('  📊 Average articles per story: ${(articles.length / stories.length).toStringAsFixed(1)}');

    return stories;
  }

  /// Create LSH signature using MinHash technique
  /// Returns a list of hash values representing the article
  List<int> _createLSHSignature(Set<String> fingerprint) {
    if (fingerprint.isEmpty) return List.filled(6, 0);

    final signature = <int>[];

    // Create 6 hash values using different hash functions
    // (in production, you'd use proper hash functions, but this works)
    for (int i = 0; i < 6; i++) {
      int minHash = 999999999;

      for (final word in fingerprint) {
        // Simple hash function with different seeds
        final hash = (word.hashCode * (i + 1) + i * 31).abs();
        if (hash < minHash) {
          minHash = hash;
        }
      }

      // Reduce to smaller range for bucketing
      signature.add(minHash % 1000);
    }

    return signature;
  }

  /// Create a fingerprint (set of significant words) from article
  /// Combines both title and description for better matching
  Set<String> _createFingerprint(Article article) {
    // Combine title (weighted more) and description
    final titleText = article.title.toLowerCase();
    final descText = article.description.toLowerCase();

    // Normalize Romanian diacritics
    final normalizedTitle = _normalizeDiacritics(titleText);
    final normalizedDesc = _normalizeDiacritics(descText);

    final combinedText = '$normalizedTitle $normalizedDesc';

    // Remove common Romanian stop words
    final stopWords = {
      'si', 'sau', 'din', 'la', 'cu', 'pe', 'pentru', 'care', 'este',
      'un', 'o', 'a', 'in', 'al', 'ale', 'de', 'ca', 'ce', 'se', 'cum',
      'mai', 'fost', 'fiind', 'sunt', 'era', 'după', 'înainte', 'între',
      'despre', 'foarte', 'avea', 'face', 'zi', 'an', 'luna', 'toate',
      'iar', 'acest', 'cea', 'cel', 'lui', 'acestea', 'aceasta', 'acesta'
    };

    // Extract significant words (length > 3, not stop words)
    final words = combinedText
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3 && !stopWords.contains(w))
        .toSet();

    return words;
  }

  /// Normalize Romanian diacritics for better matching
  String _normalizeDiacritics(String text) {
    return text.replaceAllMapped(RegExp(r'[ăâîșțĂÂÎȘȚ]'), (match) {
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
  }

  /// Enhanced similarity that mimics original algorithm's title-to-description matching
  double _fingerprintSimilarity(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;

    final intersection = a.intersection(b).length;
    final union = a.union(b).length;

    // Jaccard similarity
    return intersection / union;
  }

  List<NewsStory> groupArticlesIncremental(
      List<NewsStory> existing,
      List<Article> newArticles,
      ) {
    for (final article in newArticles) {
      NewsStory? bestStory;
      double bestScore = 0;

      for (final story in existing) {
        final anchor = _storyAnchor(story);
        final score = similarityScore(article, anchor);

        if (score > bestScore) {
          bestScore = score;
          bestStory = story;
        }
      }

      if (bestScore >= 0.18 && bestStory != null) {
        bestStory.articles.add(article);
      } else {
        existing.add(
          NewsStory(
            canonicalTitle: article.title,
            summary: article.description,
            articles: [article],
            imageUrl: article.urlToImage,
          ),
        );
      }
    }
    // Use threshold of 0.25 for better grouping (was 0.30)
    // Lower = more articles grouped together
    // Higher = stricter matching
    final allArticles = [
      ...existing.expand((s) => s.articles),
      ...newArticles,
    ];

    return groupArticlesFast(allArticles, threshold: 0.20);
    // return groupArticlesFast(newArticles, threshold: 0.20);
  }
}