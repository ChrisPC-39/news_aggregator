import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

import '../models/article_model.dart';
import '../models/base_parser.dart';

class ProfitParser extends BaseParser {
  // Category URL mappings
  static const Map<String, String?> _categoryUrls = {
    'https://www.profit.ro/stiri/politic/': null,
    'https://www.profit.ro/stiri/economie/': 'Business',
  };

  /// Main entry point - parse all Profit.ro categories
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

    print('✅ Profit.ro: Parsed ${uniqueArticles.length} unique articles (Title & Date deduplicated)');
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
    final articleNodes = document.querySelectorAll('article.article');

    for (final article in articleNodes) {
      try {
        final titleAnchor = article.querySelector('.article-title');
        final title = titleAnchor?.text.trim() ?? '';
        final relativeLink = titleAnchor?.attributes['href'];

        if (title.isEmpty || relativeLink == null) continue;

        final articleUrl =
        relativeLink.startsWith('http')
            ? relativeLink
            : 'https://www.profit.ro$relativeLink';

        final description =
            article.querySelector('p.truncate-3')?.text.trim() ?? '';

        final imageUrl =
        article
            .querySelector('figure.article-thumb img')
            ?.attributes['src'];

        // Parse the Romanian date format
        final timeElement = article.querySelector('time');
        final dateText = timeElement?.text.trim() ?? '';
        final publishedAt = _parseRomanianDate(dateText);

        articles.add(
          Article(
            title: title,
            description: description,
            url: articleUrl,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'Profit.ro',
            category: category,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return articles;
  }

  /// Parse Romanian date formats:
  /// - "azi, 11:17" -> today at 11:17
  /// - "ieri, 06:00" -> yesterday at 06:00
  /// - "28 ian 2026" -> January 28, 2026
  DateTime _parseRomanianDate(String dateText) {
    final now = DateTime.now();

    // Handle "azi, HH:MM" (today)
    if (dateText.startsWith('azi,')) {
      final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(dateText);
      if (timeMatch != null) {
        final hour = int.parse(timeMatch.group(1)!);
        final minute = int.parse(timeMatch.group(2)!);
        return DateTime(now.year, now.month, now.day, hour, minute);
      }
    }

    // Handle "ieri, HH:MM" (yesterday)
    if (dateText.startsWith('ieri,')) {
      final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(dateText);
      if (timeMatch != null) {
        final hour = int.parse(timeMatch.group(1)!);
        final minute = int.parse(timeMatch.group(2)!);
        final yesterday = now.subtract(Duration(days: 1));
        return DateTime(yesterday.year, yesterday.month, yesterday.day, hour, minute);
      }
    }

    // Handle "DD mon YYYY" format (e.g., "28 ian 2026")
    final dateMatch = RegExp(r'(\d{1,2})\s+(\w{3})\s+(\d{4})').firstMatch(dateText);
    if (dateMatch != null) {
      final day = int.parse(dateMatch.group(1)!);
      final monthAbbr = dateMatch.group(2)!;
      final year = int.parse(dateMatch.group(3)!);

      // Map Romanian month abbreviations to month numbers
      final monthMap = {
        'ian': 1, 'feb': 2, 'mar': 3, 'apr': 4,
        'mai': 5, 'iun': 6, 'iul': 7, 'aug': 8,
        'sep': 9, 'oct': 10, 'noi': 11, 'dec': 12,
      };

      final month = monthMap[monthAbbr.toLowerCase()] ?? 1;
      return DateTime(year, month, day);
    }

    // Fallback to current time if parsing fails
    return now;
  }
}