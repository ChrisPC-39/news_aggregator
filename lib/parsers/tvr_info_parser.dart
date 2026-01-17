import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import '../models/article_model.dart';

class TvrInfoParser {
  // Category URL mappings
  static const Map<String, String?> _categoryUrls = {
    'https://tvrinfo.ro/category/actualitate/': null,
    'https://tvrinfo.ro/category/extern/': 'World',
    'https://tvrinfo.ro/category/justitie/': null,
    'https://tvrinfo.ro/category/social/': null,
    'https://tvrinfo.ro/category/politic/': 'Politică internă',
    'https://tvrinfo.ro/category/special/': null,
  };

  /// Main entry point - parse all TvrInfo categories
  Future<List<Article>> parse() async {
    // Use a Map to track the latest article for each title
    final Map<String, Article> uniqueArticles = {};

    // Crawl each category page
    for (final entry in _categoryUrls.entries) {
      try {
        final categoryArticles = await _parseCategoryPage(
          entry.key,
          entry.value,
        );

        for (final article in categoryArticles) {
          // Normalize title for consistent matching
          final String lookupTitle = article.title.toLowerCase().trim();

          if (!uniqueArticles.containsKey(lookupTitle)) {
            // If title is new, add it
            uniqueArticles[lookupTitle] = article;
          } else {
            // If title exists, keep the one with the most recent timestamp
            final existing = uniqueArticles[lookupTitle]!;
            if (article.publishedAt.isAfter(existing.publishedAt)) {
              uniqueArticles[lookupTitle] = article;
            }
          }
        }
      } catch (e) {
        print('⚠️ TvrInfo: Error parsing ${entry.key}: $e');
        continue;
      }
    }

    // Convert the map back to a list
    final result = uniqueArticles.values.toList();

    print('✅ TvrInfo: Parsed ${result.length} unique articles (Title & Date deduplicated)');
    return result;
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

    if (response.statusCode != 200) {
      print('❌ Failed to fetch $url - Status: ${response.statusCode}');
      return articles;
    }

    final document = parser.parse(utf8.decode(response.bodyBytes));
    final articleNodes = document.querySelectorAll('article.article');

    for (final article in articleNodes) {
      try {
        // Extract title and URL
        final linkElement = article.querySelector('a.article__link');
        if (linkElement == null) continue;

        final url = linkElement.attributes['href'];
        if (url == null || url.isEmpty) continue;

        final titleElement = article.querySelector('h2.article__title');
        final title = titleElement?.text.trim() ?? '';
        if (title.isEmpty) continue;

        // Extract description
        final description = article.querySelector('.article__excerpt')?.text.trim() ?? '';

        // Extract image
        String? imageUrl;
        final imgElement = article.querySelector('.article__thumbnail');
        if (imgElement != null) {
          imageUrl = imgElement.attributes['src'];
        }

        // Extract and parse date
        DateTime publishedAt = _parseDate(article);

        articles.add(
          Article(
            title: title,
            description: description,
            url: url,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'TVRInfo',
            category: category,
          ),
        );
      } catch (e) {
        print('⚠️ Error parsing article: $e');
        continue;
      }
    }

    return articles;
  }

  /// Parse date from article meta-data
  DateTime _parseDate(Element article) {
    final metaElement = article.querySelector('p.article__meta-data');
    if (metaElement == null) return DateTime.now();

    final metaText = metaElement.text.trim();
    if (metaText.isEmpty) return DateTime.now();

    // Extract only the original publication date (before "actualizat")
    // Format: "17 ianuarie 2026, 16:01"
    final dateMatch = RegExp(
      r'(\d{1,2})\s+([a-z]+)\s+(\d{4}),\s*(\d{2}):(\d{2})',
    ).firstMatch(metaText);

    if (dateMatch == null) return DateTime.now();

    try {
      final day = int.parse(dateMatch.group(1)!);
      final monthName = dateMatch.group(2)!.toLowerCase();
      final year = int.parse(dateMatch.group(3)!);
      final hour = int.parse(dateMatch.group(4)!);
      final minute = int.parse(dateMatch.group(5)!);

      // Romanian month names
      final months = {
        'ianuarie': 1,
        'februarie': 2,
        'martie': 3,
        'aprilie': 4,
        'mai': 5,
        'iunie': 6,
        'iulie': 7,
        'august': 8,
        'septembrie': 9,
        'octombrie': 10,
        'noiembrie': 11,
        'decembrie': 12,
      };

      final month = months[monthName] ?? 1;

      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      print('⚠️ Error parsing date: $metaText - $e');
      return DateTime.now();
    }
  }
}