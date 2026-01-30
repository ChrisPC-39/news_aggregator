import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../models/article_model.dart';

class RetailRoParser {
  // Category URL mappings
  static const Map<String, String?> _categoryUrls = {
    'https://www.retail.ro/articole/stiri-si-noutati/index.html': null,
  };

  /// Main entry point - parse all Retail.ro categories
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

    print('✅ Retail.ro: Parsed ${uniqueArticles.length} unique articles (Title & Date deduplicated)');
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

    // Find all listing article elements
    final articleNodes = document.querySelectorAll('.listingArticle.sectionArticle');

    for (final article in articleNodes) {
      try {
        // Get the title
        final titleElement = article.querySelector('h2.title');
        final title = titleElement?.text.trim() ?? '';

        // Get the URL from the anchor element
        final articleUrl = article.attributes['href'];

        if (title.isEmpty || articleUrl == null || articleUrl.isEmpty) continue;

        // Get the image URL
        final imageElement = article.querySelector('.imgWrap img');
        final imageUrl = imageElement?.attributes['src'];

        // Get the date from the date paragraph
        final dateElement = article.querySelector('p.date');
        final dateText = dateElement?.text.trim() ?? '';
        final publishedAt = _parseEnglishDate(dateText);

        // Note: retail.ro doesn't seem to have descriptions in the listing
        final description = '';

        articles.add(
          Article(
            title: title,
            description: description,
            url: articleUrl,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'Retail.ro',
            category: category,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return articles;
  }

  /// Parse English date format:
  /// - "30 Jan 2026" -> January 30, 2026
  /// - "15 Feb 2026" -> February 15, 2026
  DateTime _parseEnglishDate(String dateText) {
    final now = DateTime.now();

    // Handle "DD Mon YYYY" format (e.g., "30 Jan 2026")
    final dateMatch = RegExp(
        r'(\d{1,2})\s+(\w+)\s+(\d{4})'
    ).firstMatch(dateText);

    if (dateMatch != null) {
      final day = int.parse(dateMatch.group(1)!);
      final monthAbbr = dateMatch.group(2)!.toLowerCase();
      final year = int.parse(dateMatch.group(3)!);

      // Map English month abbreviations to month numbers
      final monthMap = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };

      final month = monthMap[monthAbbr] ?? 1;
      return DateTime(year, month, day);
    }

    // Fallback to current time if parsing fails
    return now;
  }
}