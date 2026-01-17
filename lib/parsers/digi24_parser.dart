import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:html/parser.dart' as parser;
import '../models/article_model.dart';

class Digi24Parser {
  // Category URL mappings
  static const Map<String, String?> _categoryUrls = {
    'https://www.digi24.ro/stiri/actualitate/politica': 'Politică internă',
    'https://www.digi24.ro/stiri/externe': 'World',
    'https://www.digi24.ro/stiri/economie': 'Business',
    'https://www.digi24.ro/stiri/actualitate': null,
    'https://www.digi24.ro/stiri/sport': 'Sport',
    'https://www.digi24.ro/magazin/stil-de-viata': null,
  };

  static const String _rssUrl = 'https://www.digi24.ro/rss_files/google_news.xml';

  /// Main entry point - parse all Digi24 categories
  Future<List<Article>> parse() async {
    final List<Article> allArticles = [];

    // Step 1: Fetch RSS feed to get publication dates
    final rssDateMap = await _fetchRssDates();

    // Step 2: Crawl each category page
    for (final entry in _categoryUrls.entries) {
      try {
        final categoryArticles = await _parseCategoryPage(
          entry.key,
          entry.value,
          rssDateMap,
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

    print('✅ Digi24: Parsed ${uniqueArticles.length} unique articles (Title & Date deduplicated)');
    // Return only the values of the map (the latest unique articles)
    return uniqueArticles.values.toList();
  }

  /// Fetch RSS feed and create a map of URL -> publication date
  Future<Map<String, DateTime>> _fetchRssDates() async {
    final dateMap = <String, DateTime>{};

    final response = await http.get(Uri.parse(_rssUrl));
    if (response.statusCode != 200) return dateMap;

    final document = xml.XmlDocument.parse(
      utf8.decode(response.bodyBytes),
    );

    const sitemapNs = 'http://www.sitemaps.org/schemas/sitemap/0.9';
    const newsNs = 'http://www.google.com/schemas/sitemap-news/0.9';

    final urlElements =
    document.findAllElements('url', namespace: sitemapNs);

    for (final urlElement in urlElements) {
      final loc = urlElement
          .findElements('loc', namespace: sitemapNs)
          .firstOrNull
          ?.innerText
          .trim();

      final publicationDate = urlElement
          .findAllElements('publication_date', namespace: newsNs)
          .firstOrNull
          ?.innerText
          .trim();

      if (loc == null || publicationDate == null) continue;

      final parsed = DateTime.tryParse(publicationDate);
      if (parsed != null) {
        dateMap[loc] = parsed;
      }
    }

    return dateMap;
  }

  /// Parse a single category page
  Future<List<Article>> _parseCategoryPage(
      String url,
      String? category,
      Map<String, DateTime> rssDateMap,
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
    final articleNodes = document.querySelectorAll('article.article');

    for (final article in articleNodes) {
      try {
        final titleAnchor = article.querySelector('.article-title a');
        final title = titleAnchor?.text.trim() ?? '';
        final relativeLink = titleAnchor?.attributes['href'];

        if (title.isEmpty || relativeLink == null) continue;

        final articleUrl =
        relativeLink.startsWith('http')
            ? relativeLink
            : 'https://www.digi24.ro$relativeLink';

        final description =
            article.querySelector('.article-intro')?.text.trim() ?? '';

        final imageUrl =
        article
            .querySelector('figure.article-thumb img')
            ?.attributes['src'];

        // Get publication date from RSS feed or fallback to now
        DateTime publishedAt = rssDateMap[articleUrl] ?? DateTime.now();

        articles.add(
          Article(
            title: title,
            description: description,
            url: articleUrl,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'Digi24',
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