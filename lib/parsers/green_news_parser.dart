import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../models/article_model.dart';
import '../models/base_parser.dart';

class GreenNewsParser extends BaseParser {
  // Category URL mappings
  static const Map<String, String?> _categoryUrls = {
    'https://greennews.ro/stiri/': null,
  };

  /// Main entry point - parse all GreenNews categories
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

    print('✅ GreenNews: Parsed ${uniqueArticles.length} unique articles (Title & Date deduplicated)');
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
    final articleNodes = document.querySelectorAll('div.e-loop-item');

    for (final article in articleNodes) {
      try {
        // Get the main link element
        final linkElement = article.querySelector('a.e-con.e-parent');
        final articleUrl = linkElement?.attributes['href'];

        if (articleUrl == null || articleUrl.isEmpty) continue;

        // Get the title from the h2 element inside the child container
        final titleElement = article.querySelector('.e-con-full.e-con.e-child .elementor-heading-title');
        final title = titleElement?.text.trim() ?? '';

        if (title.isEmpty) continue;

        // Get the image URL
        final imageElement = article.querySelector('.elementor-widget-image img');
        final imageUrl = imageElement?.attributes['src'] ??
            imageElement?.attributes['data-lzl-src'];

        // Get the date/time - it's in the first heading element outside the child container
        final dateElement = article.querySelector('.elementor-element-ca7ee92 .elementor-heading-title');
        final dateText = dateElement?.text.trim() ?? '';
        final publishedAt = _parseRomanianDateTime(dateText);

        // Note: GreenNews doesn't seem to have visible descriptions in the listing
        final description = '';

        articles.add(
          Article(
            title: title,
            description: description,
            url: articleUrl,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'GreenNews',
            category: category,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return articles;
  }

  /// Parse Romanian datetime format:
  /// - "30 ianuarie 2026, 12:13" -> January 30, 2026 at 12:13
  /// - "29 ianuarie 2026, 16:35" -> January 29, 2026 at 16:35
  DateTime _parseRomanianDateTime(String dateText) {
    final now = DateTime.now();

    // Handle "DD monthName YYYY, HH:MM" format
    final dateMatch = RegExp(
        r'(\d{1,2})\s+(\w+)\s+(\d{4}),\s+(\d{1,2}):(\d{2})'
    ).firstMatch(dateText);

    if (dateMatch != null) {
      final day = int.parse(dateMatch.group(1)!);
      final monthName = dateMatch.group(2)!.toLowerCase();
      final year = int.parse(dateMatch.group(3)!);
      final hour = int.parse(dateMatch.group(4)!);
      final minute = int.parse(dateMatch.group(5)!);

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
      return DateTime(year, month, day, hour, minute);
    }

    // Fallback to current time if parsing fails
    return now;
  }
}