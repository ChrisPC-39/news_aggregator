import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../models/article_model.dart';

class EconomicaParser {
  // Category URL mappings
  static const Map<String, String?> _categoryUrls = {
    'https://www.economica.net/news': 'Politică internă',
    'https://www.economica.net/extern': 'World',
    'https://www.economica.net/finante-si-banci': 'Business',
  };

  /// Main entry point - parse all Economica categories
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

    print('✅ Economica: Parsed ${uniqueArticles.length} unique articles (Title & Date deduplicated)');
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
    final articleNodes = document.querySelectorAll('div.article');

    for (final article in articleNodes) {
      try {
        // Get the title - could be in different structures
        final titleElement = article.querySelector('.article__title a') ??
            article.querySelector('h2.article__title a');

        final title = titleElement?.text.trim() ?? '';
        final articleUrl = titleElement?.attributes['href'];

        if (title.isEmpty || articleUrl == null || articleUrl.isEmpty) continue;

        // Get the description/excerpt
        final description = article.querySelector('.article__excerpt')?.text.trim() ?? '';

        // Get the image URL from the picture element
        final imageElement = article.querySelector('.article__media img');
        final imageUrl = imageElement?.attributes['src'];

        // Get the date - it's in the article__date element
        final dateElement = article.querySelector('.article__date');
        final dateText = dateElement?.text.trim() ?? '';
        final publishedAt = _parseRomanianDate(dateText);

        articles.add(
          Article(
            title: title,
            description: description,
            url: articleUrl,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'Economica',
            category: category,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return articles;
  }

  /// Parse Romanian date format:
  /// - "30 ian. 2026" -> January 30, 2026
  /// - "15 feb. 2026" -> February 15, 2026
  DateTime _parseRomanianDate(String dateText) {
    final now = DateTime.now();

    // Handle "DD mon. YYYY" format (e.g., "30 ian. 2026")
    final dateMatch = RegExp(
        r'(\d{1,2})\s+(\w+)\.\s+(\d{4})'
    ).firstMatch(dateText);

    if (dateMatch != null) {
      final day = int.parse(dateMatch.group(1)!);
      final monthAbbr = dateMatch.group(2)!.toLowerCase();
      final year = int.parse(dateMatch.group(3)!);

      // Map Romanian month abbreviations to month numbers
      final monthMap = {
        'ian': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'mai': 5,
        'iun': 6,
        'iul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'noi': 11,
        'dec': 12,
      };

      final month = monthMap[monthAbbr] ?? 1;
      return DateTime(year, month, day);
    }

    // Fallback to current time if parsing fails
    return now;
  }
}