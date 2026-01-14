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

  Set<String> keywords(String text) {
    final stopWords = {
      'si',
      'sau',
      'din',
      'la',
      'cu',
      'pe',
      'pentru',
      'care',
      'este',
      'un',
      'o',
      'a',
      'in',
      'al',
      'ale',
    };

    return normalize(
      text,
    ).split(' ').where((w) => w.length > 3 && !stopWords.contains(w)).toSet();
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

  String inferStoryType(NewsStory story) {
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

    String? bestType;
    int bestScore = 0;

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

      if (score > bestScore) {
        bestScore = score;
        bestType = entry.key;
      }
    }

    // Adaptive threshold based on content length
    final threshold = 1;
    return bestScore >= threshold ? bestType! : 'General';
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
        stories.add(
          NewsStory(
            canonicalTitle: article.title,
            summary: article.description ?? '',
            // fallback to empty
            articles: [article],
            storyType: null,
            imageUrl: article.urlToImage,
          ),
        );
      }
    }

    // After grouping, update summary and infer story type for each story
    for (final story in stories) {
      // Pick first non-empty description among all grouped articles
      story.summary =
          story.articles
              .firstWhere(
                (a) => a.description.isNotEmpty,
                orElse: () => story.articles.first,
              )
              .description ??
          '';

      story.storyType = inferStoryType(story);
    }

    return stories;
  }
}
