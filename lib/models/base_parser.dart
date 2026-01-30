import 'article_model.dart';

abstract class BaseParser {
  Future<List<Article>> parse();
}