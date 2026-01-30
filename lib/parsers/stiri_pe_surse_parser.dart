import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import '../models/article_model.dart';
import '../models/base_parser.dart';

class StiriPeSurseParser extends BaseParser {
  // Category URL mappings
  static const Map<String, String?> _categoryUrls = {
    'https://www.stiripesurse.ro/politica': 'Politică internă',
    'https://www.stiripesurse.ro/economie': 'Business',
    'https://www.stiripesurse.ro/externe': 'World',
    'https://www.stiripesurse.ro/diaspora': null,
  };

  /// Main entry point - parse all StiriPeSurse categories
  @override
  Future<List<Article>> parse() async {
    final List<Article> allArticles = [];
    final seenUrls = <String>{};

    // Crawl each category page
    for (final entry in _categoryUrls.entries) {
      try {
        final categoryArticles = await _parseCategoryPage(
          entry.key,
          entry.value,
        );

        // Deduplicate across categories
        for (final article in categoryArticles) {
          if (!seenUrls.contains(article.url)) {
            seenUrls.add(article.url);
            allArticles.add(article);
          }
        }
      } catch (e) {
        print('⚠️ Error parsing ${entry.key}: $e');
        continue;
      }
    }

    // print('✅ StiriPeSurse: Parsed ${allArticles.length} unique articles (deduplicated from categories)');
    return allArticles;
  }

  /// Parse a single category page
  Future<List<Article>> _parseCategoryPage(
      String url,
      String? category,
      ) async {
    final List<Article> articles = [];

    // print('🔍 Fetching $url');

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    );

    if (response.statusCode != 200) {
      print('❌ Failed to fetch $url - Status: ${response.statusCode}');
      return articles;
    }

    final document = parser.parse(utf8.decode(response.bodyBytes));
    final articleNodes = document.querySelectorAll('article');

    // print('📦 Found ${articleNodes.length} articles on $url');

    for (final article in articleNodes) {
      try {
        // Extract title and URL from h4 > a
        final linkElement = article.querySelector('a.list-article-link');
        if (linkElement == null) continue;

        final relativeUrl = linkElement.attributes['href'];
        if (relativeUrl == null || relativeUrl.isEmpty) continue;

        final articleUrl = relativeUrl.startsWith('http')
            ? relativeUrl
            : 'https://www.stiripesurse.ro$relativeUrl';

        // Extract title from h4
        final titleElement = article.querySelector('h4');
        if (titleElement == null) continue;

        final title = titleElement.text.trim();
        if (title.isEmpty) continue;

        // Extract image
        String? imageUrl;
        final imgElement = article.querySelector('img');
        if (imgElement != null) {
          imageUrl = imgElement.attributes['src'];
        }

        // Extract and parse date from time element
        DateTime publishedAt = _parseDate(article);

        articles.add(
          Article(
            title: title,
            description: '', // StiriPeSurse doesn't provide descriptions in listings
            url: articleUrl,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'StiriPeSurse',
            category: category,
          ),
        );
      } catch (e) {
        print('⚠️ Error parsing article: $e');
        continue;
      }
    }

    // print('✅ Parsed ${articles.length} articles from $url');
    return articles;
  }

  /// Parse date from article element
  DateTime _parseDate(Element article) {
    final timeElement = article.querySelector('time');
    if (timeElement == null) return DateTime.now();

    // Try datetime attribute first (most reliable)
    final datetimeAttr = timeElement.attributes['datetime'];
    if (datetimeAttr != null && datetimeAttr.isNotEmpty) {
      final parsed = DateTime.tryParse(datetimeAttr);
      if (parsed != null) return parsed;
    }

    // Fallback to text content
    final dateText = timeElement.text.trim();
    if (dateText.isEmpty) return DateTime.now();

    // Check if it's time-only format (e.g., "15:46")
    if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(dateText)) {
      return _parseTimeOnly(dateText);
    }

    // Parse Romanian date format (e.g., "28 ian")
    return _parseRomanianDate(dateText);
  }

  /// Parse time-only format and apply to today's date
  DateTime _parseTimeOnly(String timeText) {
    final parts = timeText.split(':');
    if (parts.length != 2) return DateTime.now();

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  /// Parse Romanian date format (e.g., "28 ian")
  DateTime _parseRomanianDate(String dateText) {
    // Romanian month abbreviations
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

    // Match pattern: "28 ian" or "28 ianuarie"
    final match = RegExp(r'(\d{1,2})\s+([a-zA-Z]+)').firstMatch(dateText.toLowerCase());

    if (match == null) return DateTime.now();

    try {
      final day = int.parse(match.group(1)!);
      final monthStr = match.group(2)!.substring(0, 3); // Take first 3 letters
      final month = months[monthStr] ?? 1;
      final year = DateTime.now().year; // Assume current year

      return DateTime(year, month, day);
    } catch (e) {
      print('⚠️ Error parsing date: $dateText - $e');
      return DateTime.now();
    }
  }
}