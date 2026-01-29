import 'dart:async';

import 'package:html/dom.dart';
import '../globals.dart';
import '../models/article_model.dart';
import '../models/news_story_model.dart';
import '../parsers/adevarul_parser.dart';
import '../parsers/antena3_parser.dart';
import '../parsers/digi24_parser.dart';
import '../parsers/hot_news_parser.dart';
import '../parsers/libertatea_parser.dart';
import '../parsers/romania_tv_parser.dart';
import '../parsers/stiri_pe_surse_parser.dart';
import '../parsers/tvr_info_parser.dart';
import 'local_article_repository.dart';
import 'grouped_stories_cache_service.dart';
import 'old_score_service.dart';

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

      if (url.toLowerCase().contains("hotnews")) {
        final hotNewsParser = HotNewsParser();
        return await hotNewsParser.parse();
      }

      if (url.toLowerCase().contains("libertatea")) {
        final libertateaParser = LibertateaParser();
        return await libertateaParser.parse();
      }

      if (url.toLowerCase().contains("romaniatv")) {
        final romaniaTVParser = RomaniaTVParser();
        return await romaniaTVParser.parse();
      }

      if (url.toLowerCase().contains("antena3")) {
        final antena3Parser = Antena3Parser();
        return await antena3Parser.parse();
      }

      if (url.contains('stiripesurse.ro')) {
        final stiripesurseParser = StiriPeSurseParser();
        return await stiripesurseParser.parse();
      }

      return [];
    } catch (e) {
      print('  ❌ Error crawling $url: $e');
      return [];
    }
  }
}
