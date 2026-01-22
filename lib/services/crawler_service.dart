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
  // final repo = FirebaseArticleRepository();
  final scoreService = ScoreService();
  final GroupedStoriesCacheService cache = GroupedStoriesCacheService();

  // StreamController to notify when processing is complete
  final _processingController = StreamController<bool>.broadcast();
  Stream<bool> get isProcessing => _processingController.stream;

  /// Watch Firestore and return cached + updated grouped stories
  Stream<List<NewsStory>> watchGroupedStories() {
    print('📍 watchGroupedStories called');
    final initialStories = cache.load();
    final controller = StreamController<List<NewsStory>>();
    controller.add(initialStories);

    bool isProcessing = false;

    localRepo.watchArticles().listen((articles) async {
      print('🔄 watchArticles triggered with ${articles.length} articles');
      if (isProcessing) return;

      isProcessing = true;
      _processingController.add(true);

      // Run grouping on main isolate (no compute needed)
      final grouped = scoreService.groupArticlesIncremental([], articles);
      print('📍 Grouping complete: ${grouped.length} stories');

      // Deduplicate articles within each story
      for (var story in grouped) {
        final seen = <String>{};
        story.articles.retainWhere((article) {
          final key = '${article.sourceName}::${article.title.trim().toLowerCase()}';
          if (seen.contains(key)) return false;
          seen.add(key);
          return true;
        });
      }

      // Remove empty stories
      grouped.removeWhere((story) => story.articles.isEmpty);

      final totalArticles = grouped.fold<int>(0, (sum, s) => sum + s.articles.length);
      print('📍 After deduplication: ${grouped.length} stories with $totalArticles total articles');

      await cache.save(grouped);

      if (!controller.isClosed) {
        controller.add(grouped);
      }

      _processingController.add(false);
      isProcessing = false;
    });

    return controller.stream;
  }

  /// Fetch all sources and sync to Firestore
  /// The repository handles deduplication and batch management
  Future<void> fetchAllSources() async {
    List<Article> allArticles = [];
    for (var url in Globals.sourceConfigs.values) {
      final siteArticles = await crawlSite(url);
      allArticles.addAll(siteArticles);
    }

    // Repository will handle:
    // - Checking for duplicates across all batches
    // - Updating existing articles if content changed
    // - Adding new articles to batch_0
    // - Rotating batches if needed
    await localRepo.saveArticles(allArticles);
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
      return [];
    }
  }

  /// Helper to remove duplicates within a single list
  /// (Not across batches - that's handled by the repository)
  List<Article> _removeDuplicatesInList(List<Article> articles) {
    final seen = <String>{};
    final uniqueArticles = <Article>[];

    for (var article in articles) {
      final key = '${article.sourceName}::${article.title.trim().toLowerCase()}';
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

  List<Article> parseDigi24(Document document) {
    final List<Article> articles = [];
    final articleNodes = document.querySelectorAll('article.article');

    for (final article in articleNodes) {
      try {
        final titleAnchor = article.querySelector('.article-title a');
        final title = titleAnchor?.text.trim() ?? '';
        final relativeLink = titleAnchor?.attributes['href'];

        if (title.isEmpty || relativeLink == null) continue;

        final url =
        relativeLink.startsWith('http')
            ? relativeLink
            : 'https://www.digi24.ro$relativeLink';

        final description =
            article.querySelector('.article-intro')?.text.trim() ?? '';

        final imageUrl =
        article
            .querySelector('figure.article-thumb img')
            ?.attributes['src'];

        DateTime publishedAt = DateTime.now();
        final datetimeAttr =
        article.querySelector('time')?.attributes['datetime'];

        if (datetimeAttr != null) {
          publishedAt = DateTime.tryParse(datetimeAttr) ?? DateTime.now();
        }

        articles.add(
          Article(
            title: title,
            description: description,
            url: url,
            urlToImage: imageUrl,
            publishedAt: publishedAt,
            sourceName: 'Digi24',
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

  List<Article> parseTvrInfo(Document document) {
    List<Article> articles = [];
    var articleElements = document.querySelectorAll('div.article');

    for (var element in articleElements) {
      try {
        var linkElement = element.querySelector('a.article__link');
        var titleElement = element.querySelector('h2.article__title');
        if (linkElement == null || titleElement == null) continue;

        String title = titleElement.text.trim();
        String url = linkElement.attributes['href'] ?? '';
        if (url.isEmpty) continue;

        String description =
            element.querySelector('.article__excerpt')?.text.trim() ?? '';

        DateTime publishedAt = DateTime.now();
        var dateText =
        element.querySelector('p.article__meta-data')?.text.trim();
        if (dateText != null) {
          try {
            var dateMatch = RegExp(
              r'(\d{1,2} \w+ \d{4}), (\d{2}:\d{2})',
            ).firstMatch(dateText);
            if (dateMatch != null) {
              publishedAt = parseTVRDate(
                '${dateMatch.group(1)} ${dateMatch.group(2)}',
              );
            }
          } catch (_) {}
        }

        String? mediaUrl;
        var img =
            element.querySelector('.slider__slide-inner img') ??
                element.querySelector('.article__thumbnail');
        var iframe = element.querySelector('.slider__slide-inner iframe');
        if (img != null) {
          mediaUrl = img.attributes['src'];
        } else if (iframe != null) {
          mediaUrl = iframe.attributes['data-src'];
        }

        articles.add(
          Article(
            title: title,
            url: url,
            description: description,
            urlToImage: mediaUrl,
            publishedAt: publishedAt,
            sourceName: 'TVRInfo',
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