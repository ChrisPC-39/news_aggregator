import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import '../models/article_model.dart';

class LibertateaParser {
  /// Category URL → App Category mapping
  static const Map<String, String?> _categoryUrls = {
    'https://www.libertatea.ro/stiri-externe': 'World',
    'https://www.libertatea.ro/bani-afaceri': 'Business',
    'https://www.libertatea.ro/politica': 'Politică internă',
  };

  /// Main entry point
  Future<List<Article>> parse() async {
    final List<Article> allArticles = [];
    final seenUrls = <String>{};

    for (final entry in _categoryUrls.entries) {
      try {
        final categoryArticles = await _parseCategoryPage(
          entry.key,
          entry.value,
        );

        for (final article in categoryArticles) {
          if (!seenUrls.contains(article.url)) {
            seenUrls.add(article.url);
            allArticles.add(article);
          }
        }
      } catch (e) {
        print('⚠️ Libertatea error parsing ${entry.key}: $e');
        continue;
      }
    }

    print(
      '✅ Libertatea: Parsed ${allArticles.length} unique articles (deduplicated)',
    );
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
      headers: const {
        'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    );

    if (response.statusCode != 200) {
      print('❌ Failed to fetch $url - Status: ${response.statusCode}');
      return articles;
    }

    final document = parser.parse(utf8.decode(response.bodyBytes));
    final nodes = document.querySelectorAll('div.news-item');

    print('📦 Found ${nodes.length} articles on $url');

    for (final item in nodes) {
      try {
        // ---------- TITLE ----------
        final titleEl = item.querySelector('h2.article-title');
        final title = titleEl?.text.trim() ?? '';
        if (title.isEmpty) continue;

        // ---------- URL ----------
        final linkEl = item.querySelector('a.art-link');
        final articleUrl = linkEl?.attributes['href'];
        if (articleUrl == null || articleUrl.isEmpty) continue;

        // ---------- IMAGE ----------
        final imgEl = item.querySelector('picture img');
        final imageUrl =
            imgEl?.attributes['data-src'] ?? imgEl?.attributes['src'];

        // ---------- DATE ----------
        final timeText =
        item.querySelector('.news-item__metadata__time')?.text.trim();

        final publishedAt =
        timeText != null && timeText.isNotEmpty
            ? _parseLibertateaDate(timeText)
            : DateTime.now();

        articles.add(
          Article(
            title: title,
            description: '', // Libertatea list pages have no excerpt
            url: articleUrl,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'Libertatea',
            category: category,
          ),
        );
      } catch (e) {
        print('⚠️ Libertatea article parse error: $e');
        continue;
      }
    }

    print('✅ Parsed ${articles.length} articles from $url');
    return articles;
  }

  /// Parse Libertatea date formats:
  /// - "16:13" → today
  /// - "25 ian." → date
  DateTime _parseLibertateaDate(String text) {
    final now = DateTime.now();

    // Case 1: HH:mm → today
    if (text.contains(':')) {
      final parts = text.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? now.hour;
        final minute = int.tryParse(parts[1]) ?? now.minute;

        return DateTime(
          now.year,
          now.month,
          now.day,
          hour,
          minute,
        );
      }
    }

    // Case 2: "25 ian."
    final match = RegExp(
      r'(\d{1,2})\s+([a-zăâîșț]+)',
      caseSensitive: false,
    ).firstMatch(text);

    if (match != null) {
      final day = int.parse(match.group(1)!);
      final monthName = match.group(2)!.toLowerCase();

      const months = {
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

      final month = months.entries
          .firstWhere(
            (e) => monthName.startsWith(e.key),
        orElse: () => const MapEntry('ian', 1),
      )
          .value;

      // Handle year rollover
      final year = month > now.month ? now.year - 1 : now.year;

      return DateTime(year, month, day);
    }

    return now;
  }
}
