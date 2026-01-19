// lib/services/local_article_repository.dart
import 'package:hive/hive.dart';
import '../models/hive_models.dart';
import '../models/article_model.dart';

class LocalArticleRepository {
  static const _boxName = 'articles';

  Box<ArticleHive> get _box => Hive.box<ArticleHive>(_boxName);

  /// Save articles to Hive (replaces Firebase sync)
  Future<void> saveArticles(List<Article> articles) async {
    await _box.clear(); // Clear old articles

    for (var article in articles) {
      await _box.add(ArticleHive.fromArticle(article));
    }
  }

  /// Get all articles as a list
  List<Article> getArticles() {
    return _box.values.map((e) => e.toArticle()).toList();
  }

  /// Watch articles as a stream (for real-time updates)
  Stream<List<Article>> watchArticles() {
    return _box.watch().map((_) => getArticles());
  }
}