import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../models/article_model.dart';
import '../models/base_parser.dart';

class CursDeGuvernareParser extends BaseParser {
  // Category URL mappings
  static const Map<String, String?> _categoryUrls = {
    'https://cursdeguvernare.ro/cat/stiri-2': null,
    'https://cursdeguvernare.ro/cat/sectiunea-europa': 'World',
  };

  /// Main entry point - parse all Curs de Guvernare categories
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

    // print('✅ Curs de Guvernare: Parsed ${uniqueArticles.length} unique articles (Title & Date deduplicated)');
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

    // Find all listing items (Elementor-based layout)
    final articleNodes = document.querySelectorAll('.jet-listing-grid__item');

    for (final article in articleNodes) {
      try {
        // Get the title from the heading element with an anchor
        final titleElement = article.querySelector('.elementor-heading-title a');
        final title = titleElement?.text.trim() ?? '';
        final articleUrl = titleElement?.attributes['href'];

        if (title.isEmpty || articleUrl == null || articleUrl.isEmpty) continue;

        // Get the description from the dynamic field content
        final descriptionElement = article.querySelector('.jet-listing-dynamic-field__content');
        final description = descriptionElement?.text.trim() ?? '';

        // Get the image URL - check both src and data-src for lazy loading
        final imageElement = article.querySelector('.jet-listing-dynamic-image__img') ??
            article.querySelector('img');
        final imageUrl = imageElement?.attributes['src'] ??
            imageElement?.attributes['data-src'];

        // Get the category from dynamic terms if available
        // This is just for reference, we use the URL-based category from our mapping

        // Since there's no date in the HTML samples, we'll use current time
        // In production, you might want to fetch the article page to get the actual date
        final publishedAt = DateTime.now();

        articles.add(
          Article(
            title: title,
            description: description,
            url: articleUrl,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'Curs de Guvernare',
            category: category,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return articles;
  }
}