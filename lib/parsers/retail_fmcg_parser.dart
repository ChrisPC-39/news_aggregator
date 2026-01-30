import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../models/article_model.dart';
import '../models/base_parser.dart';

class RetailFmcgParser extends BaseParser {
  // Category URL mappings
  static const Map<String, String?> _categoryUrls = {
    'https://www.retail-fmcg.ro/cat/retail/retail-national': 'Business',
    'https://www.retail-fmcg.ro/cat/retail/retail-international': 'Business',
    'https://www.retail-fmcg.ro/cat/retail/retail-traditional': 'Business',
  };

  /// Main entry point - parse all Retail-FMCG categories
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

    print('✅ Retail-FMCG: Parsed ${uniqueArticles.length} unique articles (Title & Date deduplicated)');
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

    // Find all article content columns
    final articleNodes = document.querySelectorAll('.article-content-col');

    for (final article in articleNodes) {
      try {
        // Get the title
        final titleElement = article.querySelector('.blog-entry-title a');
        final title = titleElement?.text.trim() ?? '';
        final articleUrl = titleElement?.attributes['href'];

        if (title.isEmpty || articleUrl == null || articleUrl.isEmpty) continue;

        // Get the description from the excerpt
        final descriptionElement = article.querySelector('.excerpt-wrap p');
        final description = descriptionElement?.text.trim() ?? '';

        // Get the image URL - check both src and data-lazy-src
        final imageElement = article.querySelector('.nv-post-thumbnail-wrap img');
        final imageUrl = imageElement?.attributes['src'] ??
            imageElement?.attributes['data-lazy-src'];

        // Get the publication date from the time element
        // First try to get the datetime attribute which is in ISO format
        final timeElement = article.querySelector('time.entry-date.published');
        final dateTimeAttr = timeElement?.attributes['datetime'];

        DateTime publishedAt;
        if (dateTimeAttr != null) {
          // Parse ISO 8601 datetime format (e.g., "2026-01-19T14:50:59+02:00")
          publishedAt = DateTime.tryParse(dateTimeAttr) ?? DateTime.now();
        } else {
          // Fallback: parse the Romanian text format if datetime attribute is missing
          final dateText = timeElement?.text.trim() ?? '';
          publishedAt = _parseRomanianDate(dateText);
        }

        articles.add(
          Article(
            title: title,
            description: description,
            url: articleUrl,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'Retail-FMCG',
            category: category,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return articles;
  }

  /// Parse Romanian date format as fallback:
  /// - "19 ianuarie 2026" -> January 19, 2026
  /// - "19 decembrie 2025" -> December 19, 2025
  DateTime _parseRomanianDate(String dateText) {
    final now = DateTime.now();

    // Handle "DD monthName YYYY" format
    final dateMatch = RegExp(
        r'(\d{1,2})\s+(\w+)\s+(\d{4})'
    ).firstMatch(dateText);

    if (dateMatch != null) {
      final day = int.parse(dateMatch.group(1)!);
      final monthName = dateMatch.group(2)!.toLowerCase();
      final year = int.parse(dateMatch.group(3)!);

      // Map Romanian full month names to month numbers
      final monthMap = {
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

      final month = monthMap[monthName] ?? 1;
      return DateTime(year, month, day);
    }

    // Fallback to current time if parsing fails
    return now;
  }
}