import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

import '../models/article_model.dart';
import '../models/base_parser.dart';

class RomaniaTVParser extends BaseParser {
  /// Category URL → App category mapping
  static const Map<String, String?> _categoryUrls = {
    'https://www.romaniatv.net/politica': 'Politică internă',
    'https://www.romaniatv.net/economie': 'Business',
    'https://www.romaniatv.net/justitie': null,
    'https://www.romaniatv.net/extern': 'World',
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
        print('⚠️ RomaniaTV error parsing ${entry.key}: $e');
        continue;
      }
    }

    print(
      '✅ RomaniaTV: Parsed ${allArticles.length} unique articles (deduplicated)',
    );
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
      headers: const {
        'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    );

    if (response.statusCode != 200) {
      print('❌ Failed to fetch $url - Status: ${response.statusCode}');
      return articles;
    }

    final document = parser.parse(utf8.decode(response.bodyBytes));
    final nodes = document.querySelectorAll('div.article');

    print('📦 Found ${nodes.length} articles on $url');

    for (final article in nodes) {
      try {
        // ---------- TITLE + URL ----------
        final titleAnchor = article.querySelector('h3 a');
        if (titleAnchor == null) continue;

        final title = titleAnchor.text.trim();
        final articleUrl = titleAnchor.attributes['href'];

        if (title.isEmpty || articleUrl == null || articleUrl.isEmpty) continue;

        // ---------- DESCRIPTION ----------
        final description = article
            .querySelector('.article__excerpt')
            ?.text
            .trim() ??
            '';

        // ---------- IMAGE ----------
        String? imageUrl;
        final img = article.querySelector('picture img');
        if (img != null) {
          imageUrl = img.attributes['src'];
        }

        // ---------- DATE ----------
        final dateText = article
            .querySelector('.article__eyebrow div')
            ?.text
            .trim();

        final publishedAt =
        dateText != null && dateText.isNotEmpty
            ? _parseRomaniaTVDate(dateText)
            : DateTime.now();

        articles.add(
          Article(
            title: title,
            description: description,
            url: articleUrl,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'RomaniaTV',
            category: category,
          ),
        );
      } catch (e) {
        print('⚠️ RomaniaTV article parse error: $e');
        continue;
      }
    }

    print('✅ Parsed ${articles.length} articles from $url');
    return articles;
  }

  /// Parse RomaniaTV date format:
  /// "26 ian. 2026, 12:38"
  DateTime _parseRomaniaTVDate(String text) {
    try {
      final parts = text.split(',');
      if (parts.length != 2) return DateTime.now();

      final datePart = parts[0].trim(); // "26 ian. 2026"
      final timePart = parts[1].trim(); // "12:38"

      final dateTokens = datePart.split(' ');
      if (dateTokens.length < 3) return DateTime.now();

      final day = int.parse(dateTokens[0]);
      final monthStr = dateTokens[1].toLowerCase().replaceAll('.', '');
      final year = int.parse(dateTokens[2]);

      final timeTokens = timePart.split(':');
      final hour = int.parse(timeTokens[0]);
      final minute = int.parse(timeTokens[1]);

      const months = {
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

      final month = months[monthStr] ?? 1;

      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      print('⚠️ RomaniaTV date parse error: $text - $e');
      return DateTime.now();
    }
  }
}
