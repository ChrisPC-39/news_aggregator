import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../models/article_model.dart';
import '../models/base_parser.dart';

class EuractivParser extends BaseParser {
  // Category URL mappings
  static const Map<String, String?> _categoryUrls = {
    'https://www.euractiv.ro/eu-elections-2019': 'World',
    'https://www.euractiv.ro/extern': 'World',
    'https://www.euractiv.ro/politic-intern': 'Politică internă',
    'https://www.euractiv.ro/economic': 'Business',
  };

  /// Main entry point - parse all Euractiv categories
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

    // print('✅ Euractiv: Parsed ${uniqueArticles.length} unique articles (Title & Date deduplicated)');
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

    // Find all teaser elements
    final articleNodes = document.querySelectorAll('.teaser');

    for (final article in articleNodes) {
      try {
        // Get the title
        final titleElement = article.querySelector('h2 a');
        final title = titleElement?.text.trim() ?? '';
        final relativeUrl = titleElement?.attributes['href'];

        if (title.isEmpty || relativeUrl == null || relativeUrl.isEmpty) continue;

        // Construct full URL
        final articleUrl = relativeUrl.startsWith('http')
            ? relativeUrl
            : 'https://www.euractiv.ro/$relativeUrl';

        // Get the description from the teaser body
        final descriptionElement = article.querySelector('.entry-teaser .field-item p');
        final description = descriptionElement?.text.trim() ?? '';

        // Get the image URL
        final imageElement = article.querySelector('.teaser-thumb img');
        final imageUrl = imageElement?.attributes['data-src'] ??
            imageElement?.attributes['src'];

        // Get the publication date from the timestamp data attribute
        // The data-timestamp attribute contains Unix timestamp
        final timestampElement = article.querySelector('.teaser-timestamp.format-timestamp');
        final timestampStr = timestampElement?.attributes['data-timestamp'];

        DateTime publishedAt;
        if (timestampStr != null && timestampStr.isNotEmpty) {
          try {
            final timestamp = int.parse(timestampStr);
            publishedAt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          } catch (_) {
            // Fallback: try parsing the visible date text
            final dateText = timestampElement?.text.trim() ?? '';
            publishedAt = _parseRomanianDate(dateText);
          }
        } else {
          // Fallback: try parsing the visible date text
          final dateText = timestampElement?.text.trim() ?? '';
          publishedAt = _parseRomanianDate(dateText);
        }

        articles.add(
          Article(
            title: title,
            description: description,
            url: articleUrl,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'Euractiv',
            category: category,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return articles;
  }

  /// Parse Romanian date format as fallback:
  /// - "28 Ian 2026" -> January 28, 2026
  /// - "27 Ian 2026" -> January 27, 2026
  DateTime _parseRomanianDate(String dateText) {
    final now = DateTime.now();

    // Remove any icon characters or extra whitespace
    final cleanedText = dateText.replaceAll(RegExp(r'[^\d\w\s]'), '').trim();

    // Handle "DD mon YYYY" format (e.g., "28 Ian 2026")
    final dateMatch = RegExp(
        r'(\d{1,2})\s+(\w+)\s+(\d{4})'
    ).firstMatch(cleanedText);

    if (dateMatch != null) {
      final day = int.parse(dateMatch.group(1)!);
      final monthAbbr = dateMatch.group(2)!.toLowerCase();
      final year = int.parse(dateMatch.group(3)!);

      // Map Romanian month abbreviations to month numbers
      final monthMap = {
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

      final month = monthMap[monthAbbr] ?? 1;
      return DateTime(year, month, day);
    }

    // Fallback to current time if parsing fails
    return now;
  }
}