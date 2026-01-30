import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../models/article_model.dart';

class RevistaProgresivParser {
  // Category URL mappings
  static const Map<String, String?> _categoryUrls = {
    'https://revistaprogresiv.ro/retail/': null,
    'https://revistaprogresiv.ro/fmcg/': null,
  };

  /// Main entry point - parse all Revista Progresiv categories
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

    print('✅ Revista Progresiv: Parsed ${uniqueArticles.length} unique articles (Title & Date deduplicated)');
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

    // Find all article boxes
    final articleNodes = document.querySelectorAll('.item_box');

    for (final article in articleNodes) {
      try {
        // Get the title
        final titleElement = article.querySelector('.item_box_tit');
        final title = titleElement?.text.trim() ?? '';

        // Get the URL from the link
        final linkElement = article.querySelector('.item_box_pic_a');
        final articleUrl = linkElement?.attributes['href'];

        if (title.isEmpty || articleUrl == null || articleUrl.isEmpty) continue;

        // Construct full URL if relative
        final fullUrl = articleUrl.startsWith('http')
            ? articleUrl
            : 'https://revistaprogresiv.ro$articleUrl';

        // Get the description from article_txt
        final descriptionElement = article.querySelector('.article_txt');
        final description = descriptionElement?.text.trim() ?? '';

        // Get the image URL from the picture element
        final imageElement = article.querySelector('.item_box_pic img');
        final imageUrl = imageElement?.attributes['src'];

        // Get the date from the vdate element
        // IMPORTANT: Use the data-long attribute which contains the full date
        // NOT the vtime element which contains read time (e.g., "3 min")
        final dateElement = article.querySelector('.article_det_box.vdate .div_article_det');
        final dateText = dateElement?.attributes['data-long'] ??
            dateElement?.text.trim() ?? '';

        final publishedAt = _parseRomanianDate(dateText);

        articles.add(
          Article(
            title: title,
            description: description,
            url: fullUrl,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'Revista Progresiv',
            category: category,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return articles;
  }

  /// Parse Romanian date format:
  /// - "30 ianuarie 2026" -> January 30, 2026
  /// - "29 ianuarie 2026" -> January 29, 2026
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