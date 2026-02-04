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

  Map<String, dynamic> toJson() {
    return {
      'canonicalTitle': canonicalTitle,
      'articles': articles.map((a) => a.toJson()).toList(),
      'summary': summary,
      'storyTypes': storyTypes,
      'inferredStoryTypes': inferredStoryTypes,
      'imageUrl': imageUrl,
    };
  }

  factory NewsStory.fromJson(Map<String, dynamic> json) {
    return NewsStory(
      canonicalTitle: json['canonicalTitle'] as String,
      articles: (json['articles'] as List)
          .map((a) => Article.fromJson(a as Map<String, dynamic>))
          .toList(),
      summary: json['summary'] as String?,
      storyTypes: (json['storyTypes'] as List?)?.cast<String>(),
      inferredStoryTypes: (json['inferredStoryTypes'] as List?)?.cast<String>(),
      imageUrl: json['imageUrl'] as String?,
    );
  }
}