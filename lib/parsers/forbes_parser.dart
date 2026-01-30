import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../models/article_model.dart';
import '../models/base_parser.dart';

class ForbesParser extends BaseParser {
  // Category URL mappings
  static const Map<String, String?> _categoryUrls = {
    'https://www.forbes.ro/actualitate': null,
    'https://www.forbes.ro/afaceri': 'Business',
  };

  /// Main entry point - parse all Forbes Romania categories
  @override
  Future<List<Article>> parse() async {
    final List<Article> allArticles = [];

    // Crawl each category page
    for (final entry in _categoryUrls.entries) {
      try {
        final categoryArticles = await _parseCategoryPage(
          entry.key,
          entry.value,
        );
        allArticles.addAll(categoryArticles);
      } catch (e) {
        continue;
      }
    }

    // --- Deduplication Logic ---
    final Map<String, Article> uniqueArticles = {};

    for (final article in allArticles) {
      // Normalize the title to handle slight variations in casing/spacing
      final String lookupTitle = article.title.toLowerCase().trim();

      if (!uniqueArticles.containsKey(lookupTitle)) {
        uniqueArticles[lookupTitle] = article;
      } else {
        // Check if this version is newer than the one we already stored
        final existing = uniqueArticles[lookupTitle]!;
        if (article.publishedAt.isAfter(existing.publishedAt)) {
          uniqueArticles[lookupTitle] = article;
        }
      }
    }

    // print('✅ Forbes: Parsed ${uniqueArticles.length} unique articles (Title & Date deduplicated)');
    // Return only the values of the map (the latest unique articles)
    return uniqueArticles.values.toList();
  }

  /// Parse a single category page
  Future<List<Article>> _parseCategoryPage(
      String url,
      String? category,
      ) async {
    final List<Article> articles = [];

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    );

    if (response.statusCode != 200) return articles;

    final document = parser.parse(utf8.decode(response.bodyBytes));

    // Forbes has multiple article card types
    final articleNodes = document.querySelectorAll(
        'article.article-card, div.article-card'
    );

    for (final article in articleNodes) {
      try {
        // Get the title - could be in different selectors
        final titleElement = article.querySelector('.article-card__title a') ??
            article.querySelector('a.article-card__title') ??
            article.querySelector('a.main-article__title');

        final title = titleElement?.text.trim() ?? '';
        final articleUrl = titleElement?.attributes['href'];

        if (title.isEmpty || articleUrl == null || articleUrl.isEmpty) continue;

        // Get the description - only in article-card--more variant
        final description = article.querySelector('.article-card__description')?.text.trim() ?? '';

        // Get the image URL
        final imageElement = article.querySelector('.article-card__image-wrapper img') ??
            article.querySelector('.main-article__image-wrapper img');
        final imageUrl = imageElement?.attributes['src'];

        // Get the date - only in article-card--more variant
        final dateElement = article.querySelector('.article-card__date');
        final dateText = dateElement?.text.trim() ?? '';
        final publishedAt = _parseRomanianRelativeTime(dateText);

        articles.add(
          Article(
            title: title,
            description: description,
            url: articleUrl,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'Forbes Romania',
            category: category,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return articles;
  }

  /// Parse Romanian relative time format:
  /// - "acum 5 minute" -> 5 minutes ago
  /// - "acum 2 ore" -> 2 hours ago
  /// - "acum 1 zi" -> 1 day ago
  /// If no date text is provided, defaults to now
  DateTime _parseRomanianRelativeTime(String dateText) {
    final now = DateTime.now();

    if (dateText.isEmpty) {
      return now;
    }

    // Handle "acum X minute"
    final minuteMatch = RegExp(r'acum\s+(\d+)\s+minut').firstMatch(dateText);
    if (minuteMatch != null) {
      final minutes = int.parse(minuteMatch.group(1)!);
      return now.subtract(Duration(minutes: minutes));
    }

    // Handle "acum X ore"
    final hourMatch = RegExp(r'acum\s+(\d+)\s+or').firstMatch(dateText);
    if (hourMatch != null) {
      final hours = int.parse(hourMatch.group(1)!);
      return now.subtract(Duration(hours: hours));
    }

    // Handle "acum X zi/zile"
    final dayMatch = RegExp(r'acum\s+(\d+)\s+zi').firstMatch(dateText);
    if (dayMatch != null) {
      final days = int.parse(dayMatch.group(1)!);
      return now.subtract(Duration(days: days));
    }

    // Handle "acum X săptămâni"
    final weekMatch = RegExp(r'acum\s+(\d+)\s+săptămân').firstMatch(dateText);
    if (weekMatch != null) {
      final weeks = int.parse(weekMatch.group(1)!);
      return now.subtract(Duration(days: weeks * 7));
    }

    // Handle "acum X luni"
    final monthMatch = RegExp(r'acum\s+(\d+)\s+lun').firstMatch(dateText);
    if (monthMatch != null) {
      final months = int.parse(monthMatch.group(1)!);
      return DateTime(now.year, now.month - months, now.day);
    }

    // Fallback to current time
    return now;
  }
}