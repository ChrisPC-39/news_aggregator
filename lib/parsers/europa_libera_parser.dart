import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

import '../models/article_model.dart';
import '../models/base_parser.dart';

class EuropaLiberaParser extends BaseParser {
  static const String _baseUrl = 'https://romania.europalibera.org';

  // Category URL mappings
  static const Map<String, String?> _categoryUrls = {
    'https://romania.europalibera.org/politica': null,
    'https://romania.europalibera.org/externe': 'World',
    'https://romania.europalibera.org/societate': 'Politică internă',
  };

  /// Main entry point
  @override
  Future<List<Article>> parse() async {
    final List<Article> allArticles = [];
    final seenUrls = <String>{};

    for (final entry in _categoryUrls.entries) {
      try {
        final categoryArticles =
        await _parseCategoryPage(entry.key, entry.value);

        for (final article in categoryArticles) {
          if (!seenUrls.contains(article.url)) {
            seenUrls.add(article.url);
            allArticles.add(article);
          }
        }
      } catch (e) {
        print('⚠️ Europa Liberă error (${entry.key}): $e');
      }
    }

    print(
        '✅ Europa Liberă: Parsed ${allArticles.length} unique articles (deduplicated)');
    return allArticles;
  }

  /// Parse a single category page
  Future<List<Article>> _parseCategoryPage(
      String url,
      String? category,
      ) async {
    final List<Article> articles = [];

    print('🔍 Fetching $url');

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    );

    if (response.statusCode != 200) {
      print('❌ Failed to fetch $url (${response.statusCode})');
      return articles;
    }

    final document = parser.parse(utf8.decode(response.bodyBytes));
    final items = document.querySelectorAll('li.archive-list__item');

    print('📦 Found ${items.length} items on $url');

    for (final item in items) {
      try {
        // --- URL & Title ---
        final titleAnchor = item.querySelector(
          'h4.media-block__title',
        )?.parent;

        if (titleAnchor == null) continue;

        final relativeUrl = titleAnchor.attributes['href'];
        final title =
            item.querySelector('h4.media-block__title')?.text.trim() ?? '';

        if (relativeUrl == null || title.isEmpty) continue;

        final articleUrl = relativeUrl.startsWith('http')
            ? relativeUrl
            : '$_baseUrl$relativeUrl';

        // --- Image ---
        String? imageUrl;
        final img = item.querySelector('img');
        if (img != null) {
          imageUrl = img.attributes['src'] ??
              img.attributes['data-src'];
        }

        // --- Date ---
        DateTime publishedAt = DateTime.now();
        final dateText =
        item.querySelector('span.date')?.text.trim();

        if (dateText != null && dateText.isNotEmpty) {
          publishedAt = _parseRomanianLongDate(dateText);
        }

        articles.add(
          Article(
            title: title,
            description: '', // Europa Liberă list pages don't include excerpts
            url: articleUrl,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'Europa Liberă',
            category: category,
          ),
        );
      } catch (e) {
        print('⚠️ Error parsing Europa Liberă article: $e');
      }
    }

    print('✅ Parsed ${articles.length} articles from $url');
    return articles;
  }

  /// Parse Romanian long date format: "ianuarie 29, 2026"
  DateTime _parseRomanianLongDate(String text) {
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

    final match = RegExp(
      r'([a-zăâîșț]+)\s+(\d{1,2}),\s*(\d{4})',
    ).firstMatch(text.toLowerCase());

    if (match == null) return DateTime.now();

    try {
      final month = months[match.group(1)] ?? 1;
      final day = int.parse(match.group(2)!);
      final year = int.parse(match.group(3)!);

      return DateTime(year, month, day);
    } catch (_) {
      return DateTime.now();
    }
  }
}
