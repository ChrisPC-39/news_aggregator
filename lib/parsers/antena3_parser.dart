import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import '../models/article_model.dart';
import '../models/base_parser.dart';

class Antena3Parser extends BaseParser {
  // Category URL mappings
  static const Map<String, String?> _categoryUrls = {
    'https://www.antena3.ro/politica/': 'Politică internă',
    'https://www.antena3.ro/externe/': 'World',
    'https://www.antena3.ro/economic/': 'Business',
  };

  /// Main entry point - parse all Antena3 categories
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

    // print('✅ Antena3: Parsed ${allArticles.length} unique articles (deduplicated from categories)');
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
        // Extract title and URL from h3 > a
        final titleAnchor = article.querySelector('h3 a');
        if (titleAnchor == null) continue;

        final articleUrl = titleAnchor.attributes['href'];
        final title = titleAnchor.text.trim();

        if (articleUrl == null || articleUrl.isEmpty || title.isEmpty) continue;

        // Ensure full URL
        final fullUrl = articleUrl.startsWith('http')
            ? articleUrl
            : 'https://www.antena3.ro$articleUrl';

        // Extract image from data-src or src
        String? imageUrl;
        final imgElement = article.querySelector('.thumb img');
        if (imgElement != null) {
          imageUrl = imgElement.attributes['data-src'] ?? imgElement.attributes['src'];
        }

        // Extract and parse date
        DateTime publishedAt = _parseDate(article);

        articles.add(
          Article(
            title: title,
            description: '', // Antena3 doesn't provide descriptions in listings
            url: fullUrl,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'Antena3',
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
    final dateElement = article.querySelector('.date');
    if (dateElement == null) return DateTime.now();

    final dateText = dateElement.text.trim();
    if (dateText.isEmpty) return DateTime.now();

    // Check for "Publicat acum X minute/ore" format
    final relativeMatch = RegExp(r'Publicat acum (\d+)\s+(minut|ore|or)').firstMatch(dateText);
    if (relativeMatch != null) {
      return _parseRelativeTime(relativeMatch);
    }

    // Parse Romanian date format (e.g., "28 Ian")
    return _parseRomanianDate(dateText);
  }

  /// Parse relative time (e.g., "Publicat acum 17 minute")
  DateTime _parseRelativeTime(RegExpMatch match) {
    final amount = int.parse(match.group(1)!);
    final unit = match.group(2)!;

    final now = DateTime.now();

    if (unit.startsWith('minut')) {
      return now.subtract(Duration(minutes: amount));
    } else if (unit.startsWith('or')) {
      return now.subtract(Duration(hours: amount));
    }

    return now;
  }

  /// Parse Romanian date format (e.g., "28 Ian")
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

    // Match pattern: "28 Ian" or "28 Ianuarie"
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