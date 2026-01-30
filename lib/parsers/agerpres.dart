import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

import 'package:intl/intl.dart';

import '../models/article_model.dart';
import '../models/base_parser.dart';

class AgerpresParser extends BaseParser {
  // Category URL mappings
  static const Map<String, String?> _categoryUrls = {
    'https://agerpres.ro/national': 'Politică internă',
    'https://agerpres.ro/international': 'World',
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
        print('⚠️ Agerpres error (${entry.key}): $e');
      }
    }

    print(
        '✅ Agerpres: Parsed ${allArticles.length} unique articles (deduplicated)');
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
    final cards = document.querySelectorAll('div.card.bg-transparent');

    print('📦 Found ${cards.length} cards on $url');

    for (final card in cards) {
      try {
        // --- Title & URL ---
        final titleAnchor = card.querySelector('h3 a');
        if (titleAnchor == null) continue;

        final articleUrl = titleAnchor.attributes['href'];
        final title = titleAnchor.text.trim();

        if (articleUrl == null || title.isEmpty) continue;

        // --- Image ---
        final imageUrl =
        card.querySelector('div.image-container img')?.attributes['src'];

        // --- Description ---
        final description =
            card.querySelector('div.news-description p')?.text.trim() ?? '';

        // --- Date ---
        DateTime publishedAt = DateTime.now();
        final descContainer = card.querySelector('div.news-description');

        if (descContainer != null) {
          final rawText = descContainer.text;

          final match = RegExp(
            r'\d{2}-\d{2}-\d{4}\s+\d{2}:\d{2}',
          ).firstMatch(rawText);

          if (match != null) {
            try {
              publishedAt = DateFormat('dd-MM-yyyy HH:mm')
                  .parse(match.group(0)!);
            } catch (_) {}
          }
        }

        articles.add(
          Article(
            title: title,
            description: description,
            url: articleUrl,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'Agerpres',
            category: category,
          ),
        );
      } catch (e) {
        print('⚠️ Error parsing Agerpres article: $e');
      }
    }

    print('✅ Parsed ${articles.length} articles from $url');
    return articles;
  }
}
