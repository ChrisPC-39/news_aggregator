import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import 'package:news_aggregator/services/score_service.dart';
import '../globals.dart';
import '../models/article_model.dart';
import '../models/news_story_model.dart';
import '../parsers/adevarul_parser.dart';
import '../parsers/digi24_parser.dart';
import '../parsers/tvr_info_parser.dart';
import 'local_article_repository.dart';
import 'grouped_stories_cache_service.dart';

class CrawlerService {
  final localRepo = LocalArticleRepository();
  final scoreService = ScoreService();
  final GroupedStoriesCacheService cache = GroupedStoriesCacheService();

  // StreamController to notify when processing is complete
  final _processingController = StreamController<bool>.broadcast();

  Stream<bool> get isProcessing => _processingController.stream;

  Stream<List<NewsStory>> watchGroupedStories() {
    final controller = StreamController<List<NewsStory>>();

    // Load from cache once
    final initialStories = cache.load();
    controller.add(initialStories);

    return controller.stream;
  }

  Future<void> refreshStories() async {
    final articles = localRepo.getArticles();

    final grouped = scoreService.groupArticlesIncremental([], articles);

    // Deduplication
    for (var story in grouped) {
      final seen = <String>{};
      story.articles.retainWhere((article) {
        final key =
            '${article.sourceName}::${article.title.trim().toLowerCase()}';
        if (seen.contains(key)) return false;
        seen.add(key);
        return true;
      });
    }
    grouped.removeWhere((story) => story.articles.isEmpty);

    await cache.save(grouped);
    _processingController.add(false);
  }

  /// Fetch all sources and sync to local storage
  Future<void> fetchAllSources() async {
    final totalStopwatch = Stopwatch()..start();
    print('\n🚀 Starting fetchAllSources (parallel)...\n');

    // Crawl all sources in parallel
    final futures =
        Globals.sourceConfigs.values.map((url) async {
          final siteStopwatch = Stopwatch()..start();
          final articles = await crawlSite(url);
          siteStopwatch.stop();

          final domain = Uri.parse(url).host.replaceFirst('www.', '');
          print(
            '  ⏱️  $domain: ${articles.length} articles in ${siteStopwatch.elapsedMilliseconds}ms',
          );
          return articles;
        }).toList();

    final results = await Future.wait(futures);
    final allArticles = results.expand((list) => list).toList();

    print('\n📊 Total articles crawled: ${allArticles.length}');

    final saveStopwatch = Stopwatch()..start();
    await localRepo.saveArticles(allArticles);
    saveStopwatch.stop();

    totalStopwatch.stop();
    print('  ⏱️  Saving to Hive: ${saveStopwatch.elapsedMilliseconds}ms');
    print(
      '✅ Total crawl time: ${totalStopwatch.elapsedMilliseconds}ms (${(totalStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)}s)\n',
    );
  }

  Future<List<Article>> crawlSite(String url) async {
    try {
      // Special handling for Digi24 - use dedicated parser
      if (url.contains('digi24.ro')) {
        final digi24Parser = Digi24Parser();
        return await digi24Parser.parse();
      }

      // Special handling for Adevarul - use dedicated parser
      if (url.contains('adevarul.ro')) {
        final adevaruParser = AdevarulParser();
        return await adevaruParser.parse();
      }

      // Special handling for TvrInfo - use dedicated parser
      if (url.contains('tvrinfo.ro')) {
        final tvrinfoParser = TvrInfoParser();
        return await tvrinfoParser.parse();
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );

      if (response.statusCode != 200) return [];

      final document = parser.parse(utf8.decode(response.bodyBytes));
      final domain = Uri.parse(url).host.replaceFirst('www.', '');

      List<Article> articles = [];

      switch (domain) {
        case 'hotnews.ro':
          articles = parseHotNews(document);
          break;
        case 'libertatea.ro':
          articles = parseLibertatea(document);
          break;
        case 'romaniatv.net':
          articles = parseRomaniaTV(document);
          break;
        case 'antena3.ro':
          articles = parseAntena3(document);
          break;
        default:
          articles = [];
      }

      return _removeDuplicatesInList(articles);
    } catch (e) {
      print('  ❌ Error crawling $url: $e');
      return [];
    }
  }

  /// Helper to remove duplicates within a single list
  List<Article> _removeDuplicatesInList(List<Article> articles) {
    final seen = <String>{};
    final uniqueArticles = <Article>[];

    for (var article in articles) {
      final key =
          '${article.sourceName}::${article.title.trim().toLowerCase()}';
      if (!seen.contains(key)) {
        seen.add(key);
        uniqueArticles.add(article);
      }
    }

    return uniqueArticles;
  }

  List<Article> parseHotNews(Document document) {
    final List<Article> articles = [];
    final articleNodes = document.querySelectorAll('article.post');

    for (final article in articleNodes) {
      try {
        final titleAnchor = article.querySelector('h2.entry-title a');
        final title = titleAnchor?.text.trim() ?? '';
        final link = titleAnchor?.attributes['href'];

        if (title.isEmpty || link == null) continue;

        final description =
            article.querySelector('a.entry-excerpt')?.text.trim() ?? '';

        final imageUrl =
            article
                .querySelector('figure.post-thumbnail img')
                ?.attributes['src'];

        DateTime publishedAt = DateTime.now();
        final datetimeAttr =
            article.querySelector('time.entry-date')?.attributes['datetime'];

        if (datetimeAttr != null) {
          publishedAt = DateTime.tryParse(datetimeAttr) ?? DateTime.now();
        }

        articles.add(
          Article(
            title: title,
            description: description,
            url: link,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'HotNews',
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return articles;
  }

  List<Article> parseLibertatea(Document document) {
    final List<Article> articles = [];
    final items = document.querySelectorAll('div.news-item');

    for (final item in items) {
      try {
        final titleElement = item.querySelector('h2.article-title');
        final title = titleElement?.text.trim() ?? '';
        final link = item.querySelector('a.art-link')?.attributes['href'];

        if (title.isEmpty || link == null) continue;

        final img = item.querySelector('picture img');
        final imageUrl = img?.attributes['src'] ?? img?.attributes['data-src'];

        articles.add(
          Article(
            title: title,
            description: '',
            url: link,
            urlToImage: imageUrl,
            publishedAt: DateTime.now(),
            sourceName: 'Libertatea',
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return articles;
  }

  List<Article> parseRomaniaTV(Document document) {
    final List<Article> articles = [];
    final articleBlocks = document.querySelectorAll('.article');

    for (var item in articleBlocks) {
      try {
        var titleAnchor =
            item.querySelector('h2 a') ??
            item.querySelector('.article__title a') ??
            item.querySelector('a');
        if (titleAnchor == null) continue;

        final title = titleAnchor.text.trim();
        final url = titleAnchor.attributes['href'] ?? '';
        if (url.isEmpty) continue;

        final description =
            item.querySelector('.article__excerpt')?.text.trim() ??
            item.querySelector('p')?.text.trim() ??
            '';

        String? imageUrl;
        final imgTag = item.querySelector('img');
        if (imgTag != null) {
          imageUrl = imgTag.attributes['src'] ?? imgTag.attributes['data-src'];
        }

        final timeText =
            item.querySelector('time')?.text.trim() ??
            item.querySelector('.article__meta-data')?.text.trim() ??
            '';
        DateTime publishedAt = DateTime.now();
        if (timeText.isNotEmpty) {
          final match = RegExp(
            r'(\d{1,2})\s+([^\s]+)\s+(\d{4}),\s*(\d{2}:\d{2})',
          ).firstMatch(timeText);
          if (match != null) {
            final day = int.parse(match.group(1)!);
            final monthName = match.group(2)!.toLowerCase();
            final year = int.parse(match.group(3)!);
            final timeParts = match.group(4)!.split(':');
            final hour = int.parse(timeParts[0]);
            final minute = int.parse(timeParts[1]);

            final months = {
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
            publishedAt = DateTime(
              year,
              months[monthName] ?? 1,
              day,
              hour,
              minute,
            );
          }
        }

        articles.add(
          Article(
            title: title,
            description: description,
            url: url.startsWith('http') ? url : 'https://www.romaniatv.net$url',
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'RomaniaTV',
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return articles;
  }

  List<Article> parseAntena3(Document document) {
    final List<Article> articles = [];
    final articleBlocks = document.querySelectorAll('article');

    for (var item in articleBlocks) {
      try {
        final titleAnchor = item.querySelector('h3 a');
        if (titleAnchor == null) continue;

        final title = titleAnchor.text.trim();
        final url = titleAnchor.attributes['href'] ?? '';
        if (url.isEmpty) continue;

        final description =
            item.querySelector('.abs, .abs-extern')?.text.trim() ?? '';

        String? imageUrl;
        final imgTag = item.querySelector('.thumb img');
        if (imgTag != null) {
          imageUrl = imgTag.attributes['data-src'] ?? imgTag.attributes['src'];
        }

        final timeText = item.querySelector('.date')?.text.trim() ?? '';
        DateTime publishedAt = DateTime.now();
        if (timeText.isNotEmpty) {
          final match = RegExp(
            r'Publicat\s+acum\s+(\d+)\s+minute?',
          ).firstMatch(timeText);
          if (match != null) {
            final minutesAgo = int.parse(match.group(1)!);
            publishedAt = DateTime.now().subtract(
              Duration(minutes: minutesAgo),
            );
          }
        }

        articles.add(
          Article(
            title: title,
            description: description,
            url: url.startsWith('http') ? url : 'https://www.antena3.ro$url',
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'Antena3',
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return articles;
  }

  DateTime parseTVRDate(String dateStr) {
    Map<String, int> months = {
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

    var parts = dateStr.split(' ');
    int day = int.parse(parts[0]);
    int month = months[parts[1].toLowerCase()] ?? 1;
    int year = int.parse(parts[2]);
    var timeParts = parts[3].split(':');
    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);

    return DateTime(year, month, day, hour, minute);
  }
}
