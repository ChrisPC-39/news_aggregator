import 'article_model.dart';

class NewsStory {
  final String canonicalTitle;
  final List<Article> articles;
  String? summary;
  List<String>? storyTypes;
  String? imageUrl;
  List<String>? inferredStoryTypes;

  NewsStory({
    required this.canonicalTitle,
    required this.articles,
    this.summary,
    this.storyTypes,
    this.imageUrl,
    this.inferredStoryTypes,
  });
}