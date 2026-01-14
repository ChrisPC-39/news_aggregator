import 'article_model.dart';

class NewsStory {
  final String canonicalTitle;
  final List<Article> articles;
  String? summary;
  String? storyType;
  String? imageUrl;

  NewsStory({
    required this.canonicalTitle,
    required this.articles,
    this.summary,
    this.storyType,
    this.imageUrl,
  });
}