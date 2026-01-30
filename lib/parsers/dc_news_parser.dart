import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

import '../models/article_model.dart';
import '../models/base_parser.dart';

class DcNewsParser extends BaseParser {
  static const Map<String, String> _categoryUrls = {
    'https://www.dcnews.ro/politica': 'Politică internă',
    'https://www.dcnews.ro/economie-si-afaceri': 'Business',
    'https://www.dcnews.ro/news/international': 'World',
  };

  @override
  Future<List<Article>> parse() async {
    final List<Article> allArticles = [];
    final seenUrls = <String>{};

    for (final entry in _categoryUrls.entries) {
      try {
        final articles =
        await _parseCategory(entry.key, entry.value);

        for (final article in articles) {
          if (!seenUrls.contains(article.url)) {
            seenUrls.add(article.url);
            allArticles.add(article);
          }
        }
      } catch (e) {
        print('⚠️ DCNews error (${entry.key}): $e');
      }
    }

    // print(
    //     '✅ DCNews: Parsed ${allArticles.length} unique articles');
    return allArticles;
  }

  Future<List<Article>> _parseCategory(
      String url,
      String category,
      ) async {
    final List<Article> articles = [];

    // print('🔍 Fetching $url');

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

    final items = document.querySelectorAll('li > div.box_mic');

    // print('📦 Found ${items.length} items on $url');

    for (final item in items) {
      try {
        // --- URL & Title ---
        final titleAnchor =
        item.querySelector('a.box_mic_second_title');

        if (titleAnchor == null) continue;

        final articleUrl =
        titleAnchor.attributes['href'];
        final title = titleAnchor.text.trim();

        if (articleUrl == null || title.isEmpty) continue;

        // --- Image ---
        String? imageUrl;
        final img = item.querySelector('img');
        if (img != null) {
          imageUrl = img.attributes['src'] ??
              img.attributes['data-src'];
        }

        // --- Publish date ---
        DateTime publishedAt = DateTime.now();
        final dateText = item
            .querySelector('div.date.publishedDate')
            ?.text
            .trim();

        if (dateText != null && dateText.isNotEmpty) {
          publishedAt = _parseDcNewsDate(dateText);
        }

        articles.add(
          Article(
            title: title,
            description: '',
            url: articleUrl,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'DCNews',
            category: category,
          ),
        );
      } catch (e) {
        print('⚠️ Error parsing DCNews article: $e');
      }
    }

    // print('✅ Parsed ${articles.length} articles from $url');
    return articles;
  }

  /// Parses: "Publicat pe 19 Ian 2026"
  DateTime _parseDcNewsDate(String text) {
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
      r'(\d{1,2})\s+([a-zA-Zăâîșț]+)\s+(\d{4})',
    ).firstMatch(text.toLowerCase());

    if (match == null) return DateTime.now();

    try {
      final day = int.parse(match.group(1)!);
      final month =
          months[match.group(2)!.substring(0, 3)] ?? 1;
      final year = int.parse(match.group(3)!);

      return DateTime(year, month, day);
    } catch (_) {
      return DateTime.now();
    }
  }
}
