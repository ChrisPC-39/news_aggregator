import 'dart:async';
import 'package:news_aggregator/services/v3_score_service.dart';
import '../globals.dart';
import '../models/article_model.dart';
import '../models/base_parser.dart';
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

class CrawlerService {
  final localRepo = LocalArticleRepository();
  final scoreService = ScoreService();
  final GroupedStoriesCacheService cache = GroupedStoriesCacheService();

  final _processingController = StreamController<bool>.broadcast();

  Stream<bool> get isProcessing => _processingController.stream;

  Stream<List<NewsStory>> watchGroupedStories() {
    final controller = StreamController<List<NewsStory>>();
    final initialStories = cache.load();
    controller.add(initialStories);
    return controller.stream;
  }

  Future<void> refreshStories() async {
    _processingController.add(true);

    // 1. Load articles from local storage
    final rawArticles = localRepo.getArticles();
    if (rawArticles.isEmpty) {
      _processingController.add(false);
      return;
    }

    // 2. Load existing cached stories to preserve isSaved flags
    final existingStories = cache.load();

    // 3. Pre-process / Deduplicate raw articles
    final Map<String, Article> uniqueMap = {};
    for (var a in rawArticles) {
      final key = '${a.sourceName}::${a.title.trim().toLowerCase()}';
      if (!uniqueMap.containsKey(key) ||
          a.publishedAt.isAfter(uniqueMap[key]!.publishedAt)) {
        uniqueMap[key] = a;
      }
    }
    final deduplicatedArticles = uniqueMap.values.toList();

    // 4. WARM UP: Trigger RegEx/Normalization in parallel
    await Future.wait(
      deduplicatedArticles.map((a) async => a.normalizedTokens),
    );

    // 5. Group articles using the optimized ScoreService (preserve saved flags)
    final grouped = scoreService.groupArticles(
      deduplicatedArticles,
      existingStories: existingStories, // ✅ Pass existing stories
    );

    // 6. Save to cache and notify UI
    await cache.save(grouped);
    _processingController.add(false);
  }

  Future<void> fetchAllSources() async {
    // final totalStopwatch = Stopwatch()..start();
    // print('\n🚀 Starting fetchAllSources (parallel)...\n');

    final futures =
        Globals.sourceConfigs.values.map((url) async {
          final siteStopwatch = Stopwatch()..start();
          final articles = await crawlSite(url);
          siteStopwatch.stop();

          final domain = Uri.parse(url).host.replaceFirst('www.', '');
          // print(
          //   '  ⏱️  $domain: ${articles.length} articles in ${siteStopwatch.elapsedMilliseconds}ms',
          // );
          return articles;
        }).toList();

    final results = await Future.wait(futures);
    final allArticles = results.expand((list) => list).toList();

    // print('\n📊 Total articles crawled: ${allArticles.length}');

    // final saveStopwatch = Stopwatch()..start();
    await localRepo.saveArticles(allArticles);
    // saveStopwatch.stop();

    // totalStopwatch.stop();
    // print('  ⏱️  Saving to Hive: ${saveStopwatch.elapsedMilliseconds}ms');
    // print('✅ Total crawl time: ${totalStopwatch.elapsedMilliseconds}ms\n');

    // Automatically trigger grouping after a fresh crawl
    await refreshStories();
  }

  Future<List<Article>> crawlSite(String url) async {
    // Use a registry map for O(1) lookup
    final Map<String, BaseParser Function()> parserRegistry = {
      'digi24.ro': () => Digi24Parser(),
      'adevarul.ro': () => AdevarulParser(),
      'tvrinfo.ro': () => TvrInfoParser(),
      'hotnews': () => HotNewsParser(),
      'libertatea': () => LibertateaParser(),
      'romaniatv': () => RomaniaTVParser(),
      'antena3': () => Antena3Parser(),
      'stiripesurse': () => StiriPeSurseParser(),
      'agerpres': () => AgerpresParser(),
      'dcnews': () => DcNewsParser(),
      'g4media': () => G4MediaParser(),
      'profit': () => ProfitParser(),
      'greennews': () => GreenNewsParser(),
      'economica': () => EconomicaParser(),
      'forbes': () => ForbesParser(),
      'cursdeguvernare': () => CursDeGuvernareParser(),
      'retail-fmcg': () => RetailFmcgParser(),
      'revistaprogresiv': () => RevistaProgresivParser(),
      'euractiv': () => EuractivParser(),
      'retail.ro': () => RetailRoParser(),
      '360medical.ro': () => Medical360Parser(),
      'edupedu': () => EdupeduParser(),
    };

    try {
      final lowerUrl = url.toLowerCase();

      // Find the first key that matches the URL
      final entry = parserRegistry.entries.firstWhere(
            (e) => lowerUrl.contains(e.key),
        orElse: () => MapEntry('none', () => throw 'No parser found'),
      );

      if (entry.key == 'none') return [];

      // Instantiate and parse
      return await entry.value().parse();

    } catch (e) {
      print('  ❌ Error crawling $url: $e');
      return [];
    }
  }
}
