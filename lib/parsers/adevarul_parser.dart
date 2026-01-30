import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import '../models/article_model.dart';
import '../models/base_parser.dart';

class AdevarulParser extends BaseParser {
  // Category URL mappings
  static const Map<String, String?> _categoryUrls = {
    'https://adevarul.ro/stiri-interne': null,
    'https://adevarul.ro/stiri-externe': 'World',
    'https://adevarul.ro/politica': 'Politică internă',
    'https://adevarul.ro/economie': 'Business',
    'https://adevarul.ro/stil-de-viata': null,
  };

  /// Main entry point - parse all Adevarul categories
  @override
  Future<List<Article>> parse() async {
    final List<Article> allArticles = [];

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
      final title = article.title.trim();

      if (!uniqueArticles.containsKey(title)) {
        // New title, just add it
        uniqueArticles[title] = article;
      } else {
        // Duplicate found, compare timestamps
        final existingArticle = uniqueArticles[title]!;
        if (article.publishedAt.isAfter(existingArticle.publishedAt)) {
          // The new one is newer, replace the old one
          uniqueArticles[title] = article;
        }
      }
    }

    // print(
    //   '✅ Adevarul: Parsed ${uniqueArticles.length} unique articles (Title & Date deduplicated)',
    // );
    // Convert map values back to a list
    return uniqueArticles.values.toList();
  }

  /// Parse a single category page
  Future<List<Article>> _parseCategoryPage(String url, String? category) async {
    final List<Article> articles = [];

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
    final containers = document.querySelectorAll('div.container');

    for (final container in containers) {
      try {
        // Extract title and URL - the <a> tag itself has class "title"
        final titleAnchor = container.querySelector('a.title');
        if (titleAnchor == null) {
          continue;
        }

        final title = titleAnchor.text.trim();
        final link = titleAnchor.attributes['href'];

        if (title.isEmpty || link == null || link.isEmpty) {
          continue;
        }

        // Skip if link is just the homepage
        if (link == 'https://adevarul.ro/' || link == '/') {
          continue;
        }

        // Ensure full URL
        final fullUrl =
            link.startsWith('http') ? link : 'https://adevarul.ro$link';

        // Skip if URL is still just the homepage after processing
        if (fullUrl == 'https://adevarul.ro/' ||
            fullUrl == 'https://adevarul.ro') {
          continue;
        }

        // Extract description
        final description =
            container.querySelector('.summary')?.text.trim() ?? '';

        // Extract image - look for <img> tag in picture element
        String? imageUrl;
        final imgElement =
            container.querySelector('.cover img') ??
            container.querySelector('.poster img') ??
            container.querySelector('img');

        if (imgElement != null) {
          // Try src first, then srcset
          imageUrl = imgElement.attributes['src'];
          if (imageUrl == null || imageUrl.isEmpty) {
            final srcset = imgElement.attributes['srcset'];
            if (srcset != null && srcset.isNotEmpty) {
              // Extract first URL from srcset
              imageUrl = srcset.split(' ').first;
            }
          }
        }

        // Extract and parse date
        DateTime publishedAt = _parseDate(container);

        articles.add(
          Article(
            title: _cleanTitle(title),
            description: description,
            url: fullUrl,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'Adevarul',
            category: category,
          ),
        );
      } catch (e) {
        print('⚠️ Error parsing container: $e');
        continue;
      }
    }

    return articles;
  }

  /// Parse date from container element
  DateTime _parseDate(Element container) {
    final dateElement = container.querySelector('.date');
    if (dateElement == null) return DateTime.now();

    final dateText = dateElement.text.trim();
    if (dateText.isEmpty) return DateTime.now();

    // Check if it's a time-only format (e.g., "14:30")
    if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(dateText)) {
      return _parseTimeOnly(dateText);
    }

    // Parse full date format (e.g., "16 ian. 2026")
    return _parseFullDate(dateText);
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

  /// Parse full date format (e.g., "16 ian. 2026")
  DateTime _parseFullDate(String dateText) {
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

    // Match pattern: "16 ian. 2026" or "16 ianuarie 2026"
    final match = RegExp(
      r'(\d{1,2})\s+([a-z]+)\.?\s+(\d{4})',
    ).firstMatch(dateText.toLowerCase());

    if (match == null) return DateTime.now();

    final day = int.tryParse(match.group(1)!) ?? 1;
    final monthStr = match.group(2)!.substring(0, 3); // Take first 3 letters
    final month = months[monthStr] ?? 1;
    final year = int.tryParse(match.group(3)!) ?? DateTime.now().year;

    return DateTime(year, month, day);
  }

  /// Clean title text (remove extra whitespace, etc.)
  String _cleanTitle(String title) {
    return title
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[„"]'), '"')
        .trim();
  }
}
