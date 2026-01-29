import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';

import '../models/article_model.dart';

class G4MediaParser {
  static const Map<String, String?> _sources = {
    'https://www.g4media.ro/green-news': 'Health',
    'https://www.g4media.ro/': null,
  };

  Future<List<Article>> parse() async {
    final List<Article> allArticles = [];
    final seenUrls = <String>{};

    for (final entry in _sources.entries) {
      try {
        final articles =
        await _parsePage(entry.key, entry.value);

        for (final article in articles) {
          if (!seenUrls.contains(article.url)) {
            seenUrls.add(article.url);
            allArticles.add(article);
          }
        }
      } catch (e) {
        print('⚠️ G4Media error (${entry.key}): $e');
      }
    }

    print(
        '✅ G4Media: Parsed ${allArticles.length} unique articles');
    return allArticles;
  }

  Future<List<Article>> _parsePage(
      String url,
      String? category,
      ) async {
    final List<Article> articles = [];

    print('🔍 Fetching $url');

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      },
    );

    if (response.statusCode != 200) {
      print('❌ Failed to fetch $url (${response.statusCode})');
      return articles;
    }

    final document = parser.parse(
      utf8.decode(response.bodyBytes),
    );

    final items = document.querySelectorAll('div.article');

    print('📦 Found ${items.length} article blocks');

    for (final item in items) {
      try {
        // --- Title & URL ---
        final titleAnchor =
        item.querySelector('h2 a, h3 a');

        if (titleAnchor == null) continue;

        final articleUrl =
        titleAnchor.attributes['href'];
        final title = titleAnchor.text.trim();

        if (articleUrl == null || title.isEmpty) continue;

        // --- Image ---
        String? imageUrl;
        final img = item.querySelector('img');
        if (img != null) {
          imageUrl = img.attributes['src'];
        }

        // --- Excerpt ---
        final excerpt = item
            .querySelector('.article__excerpt')
            ?.text
            .trim();

        // --- Date ---
        DateTime publishedAt = DateTime.now();
        final dateText = item
            .querySelector('.article__eyebrow')
            ?.text
            .trim();

        if (dateText != null) {
          publishedAt = _parseG4MediaDate(dateText);
        }

        articles.add(
          Article(
            title: title,
            description: excerpt ?? '',
            url: articleUrl,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'G4Media',
            category: category,
          ),
        );
      } catch (e) {
        print('⚠️ Error parsing G4Media article: $e');
      }
    }

    print('✅ Parsed ${articles.length} articles from $url');
    return articles;
  }

  /// Parses formats like:
  /// "29 ian."
  /// "27 ian."
  DateTime _parseG4MediaDate(String text) {
    final months = {
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
      'nov': 11,
      'dec': 12,
    };

    final match = RegExp(
      r'(\d{1,2})\s+([a-zăâîșț]+)',
      caseSensitive: false,
    ).firstMatch(text);

    if (match == null) return DateTime.now();

    try {
      final day = int.parse(match.group(1)!);
      final month =
          months[match.group(2)!.substring(0, 3).toLowerCase()] ??
              DateTime.now().month;
      final year = DateTime.now().year;

      return DateTime(year, month, day);
    } catch (_) {
      return DateTime.now();
    }
  }
}
