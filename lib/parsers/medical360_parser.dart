import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../models/article_model.dart';
import '../models/base_parser.dart';

class Medical360Parser extends BaseParser {
  // Category URL mappings
  static const Map<String, String?> _categoryUrls = {
    'https://www.360medical.ro/toate': 'Health',
  };

  /// Main entry point - parse all 360medical categories
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

    // print('✅ 360medical: Parsed ${uniqueArticles.length} unique articles (Title & Date deduplicated)');
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

    // Find all article elements
    final articleNodes = document.querySelectorAll('article.article');

    for (final article in articleNodes) {
      try {
        // Get the title and URL
        final titleElement = article.querySelector('.article-title');
        final title = titleElement?.text.trim() ?? '';
        final relativeUrl = titleElement?.attributes['href'];

        if (title.isEmpty || relativeUrl == null || relativeUrl.isEmpty) continue;

        // Construct full URL
        final articleUrl = relativeUrl.startsWith('http')
            ? relativeUrl
            : 'https://www.360medical.ro$relativeUrl';

        // Get the image URL
        final imageElement = article.querySelector('figure.article-thumb img');
        final imageUrl = imageElement?.attributes['src'];

        // Get the date from the time element
        final timeElement = article.querySelector('time.article-date');
        final dateText = timeElement?.text.trim() ?? '';
        final publishedAt = _parseRomanianDateTime(dateText);

        // Note: 360medical doesn't seem to have descriptions in the listing
        final description = '';

        articles.add(
          Article(
            title: title,
            description: description,
            url: articleUrl,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: '360medical',
            category: category,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return articles;
  }

  /// Parse Romanian datetime format:
  /// - "astăzi, 17:57" -> today at 17:57
  /// - "ieri, 14:30" -> yesterday at 14:30
  /// - "28 ian. 2026" -> January 28, 2026
  DateTime _parseRomanianDateTime(String dateText) {
    final now = DateTime.now();

    // Handle "astăzi, HH:MM" (today)
    if (dateText.startsWith('astăzi') || dateText.startsWith('astazi')) {
      final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(dateText);
      if (timeMatch != null) {
        final hour = int.parse(timeMatch.group(1)!);
        final minute = int.parse(timeMatch.group(2)!);
        return DateTime(now.year, now.month, now.day, hour, minute);
      }
      return now;
    }

    // Handle "ieri, HH:MM" (yesterday)
    if (dateText.startsWith('ieri')) {
      final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(dateText);
      if (timeMatch != null) {
        final hour = int.parse(timeMatch.group(1)!);
        final minute = int.parse(timeMatch.group(2)!);
        final yesterday = now.subtract(Duration(days: 1));
        return DateTime(yesterday.year, yesterday.month, yesterday.day, hour, minute);
      }
      final yesterday = now.subtract(Duration(days: 1));
      return yesterday;
    }

    // Handle "DD mon. YYYY" format (e.g., "28 ian. 2026")
    final dateMatch = RegExp(r'(\d{1,2})\s+(\w+)\.\s+(\d{4})').firstMatch(dateText);
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