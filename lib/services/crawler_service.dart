import 'dart:async';

import '../globals.dart';
import '../models/article_model.dart';
import '../models/news_story_model.dart';
import '../parsers/adevarul_parser.dart';
import '../parsers/agerpres.dart';
import '../parsers/antena3_parser.dart';
import '../parsers/curs_de_guvernare_parser.dart';
import '../parsers/dc_news_parser.dart';
import '../parsers/digi24_parser.dart';
import '../parsers/economica_parser.dart';
import '../parsers/edupedu_parser.dart';
import '../parsers/euractiv_parser.dart';
import '../parsers/forbes_parser.dart';
import '../parsers/g4_media_parser.dart';
import '../parsers/green_news_parser.dart';
import '../parsers/hot_news_parser.dart';
import '../parsers/libertatea_parser.dart';
import '../parsers/medical360_parser.dart';
import '../parsers/profit_parser.dart';
import '../parsers/retail_fmcg_parser.dart';
import '../parsers/retail_ro_parser.dart';
import '../parsers/revista_progresiv_parser.dart';
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
      if (url.contains('digi24.ro')) {
        final digi24Parser = Digi24Parser();
        return await digi24Parser.parse();
      }

      if (url.contains('adevarul.ro')) {
        final adevaruParser = AdevarulParser();
        return await adevaruParser.parse();
      }

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

      if (url.contains('stiripesurse')) {
        final stiripesurseParser = StiriPeSurseParser();
        return await stiripesurseParser.parse();
      }

      if (url.contains('agerpres')) {
        final agerpresParser = AgerpresParser();
        return await agerpresParser.parse();
      }

      if (url.contains('europalibera')) {
        final europaLiberaParser = AgerpresParser();
        return await europaLiberaParser.parse();
      }

      if (url.contains('dcnews')) {
        final dcNewsParser = DcNewsParser();
        return await dcNewsParser.parse();
      }

      if (url.contains('g4media')) {
        final g4MediaParser = G4MediaParser();
        return await g4MediaParser.parse();
      }

      if (url.contains('profit')) {
        final profitParser = ProfitParser();
        return await profitParser.parse();
      }

      if (url.contains('greennews')) {
        final greennewsParser = GreenNewsParser();
        return await greennewsParser.parse();
      }

      if (url.contains('economica')) {
        final economicaParser = EconomicaParser();
        return await economicaParser.parse();
      }

      if (url.contains('forbes')) {
        final forbesParser = ForbesParser();
        return await forbesParser.parse();
      }

      if (url.contains('cursdeguvernare')) {
        final cursDeGuvernareParser = CursDeGuvernareParser();
        return await cursDeGuvernareParser.parse();
      }

      if (url.contains('retail-fmcg')) {
        final retailFmcgParser = RetailFmcgParser();
        return await retailFmcgParser.parse();
      }

      if (url.contains('revistaprogresiv')) {
        final revistaProgresivParser = RevistaProgresivParser();
        return await revistaProgresivParser.parse();
      }

      if (url.contains('euractiv')) {
        final euractivParser = EuractivParser();
        return await euractivParser.parse();
      }

      if (url.contains('retail.ro')) {
        final retailRoParser = RetailRoParser();
        return await retailRoParser.parse();
      }

      if (url.contains('360medical.ro')) {
        final medical360Parser = Medical360Parser();
        return await medical360Parser.parse();
      }

      if (url.contains('edupedu')) {
        final edupeduParser = EdupeduParser();
        return await edupeduParser.parse();
      }

      return [];
    } catch (e) {
      print('  ❌ Error crawling $url: $e');
      return [];
    }
  }
}
