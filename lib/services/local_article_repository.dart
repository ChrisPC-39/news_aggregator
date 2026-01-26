import 'package:hive/hive.dart';
import '../models/hive_models.dart';
import '../models/article_model.dart';

class LocalArticleRepository {
  static const _boxName = 'articles';

  Box<ArticleHive> get _box => Hive.box<ArticleHive>(_boxName);

  /// Save articles to Hive (replaces Firebase sync)
  Future<void> saveArticles(List<Article> articles) async {
    // Disable auto-compact during bulk operation
    await _box.clear();

    // Use putAll for bulk insert (triggers watch only once)
    final articlesMap = <int, ArticleHive>{};
    for (int i = 0; i < articles.length; i++) {
      articlesMap[i] = ArticleHive.fromArticle(articles[i]);
    }
    await _box.putAll(articlesMap);
  }

  List<Article> getArticles() {
    return _box.values.map((e) => e.toArticle()).toList();
  }

  /// Watch articles as a stream (for real-time updates)
  Stream<List<Article>> watchArticles() {
    return _box.watch().map((_) => getArticles());
  }
}