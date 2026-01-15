//flutter packages pub run build_runner build

import 'package:hive/hive.dart';

import 'article_model.dart';
import 'news_story_model.dart';

part 'hive_models.g.dart';

@HiveType(typeId: 0)
class ArticleHive extends HiveObject {
  @HiveField(0)
  String? author;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  String url;

  @HiveField(4)
  String? urlToImage;

  @HiveField(5)
  DateTime publishedAt;

  @HiveField(6)
  String? content;

  @HiveField(7)
  String sourceName;

  @HiveField(8)
  String? aiSummary;

  ArticleHive({
    this.author,
    required this.title,
    required this.description,
    required this.url,
    this.urlToImage,
    required this.publishedAt,
    this.content,
    required this.sourceName,
    this.aiSummary,
  });

  factory ArticleHive.fromArticle(Article a) => ArticleHive(
    author: a.author,
    title: a.title,
    description: a.description,
    url: a.url,
    urlToImage: a.urlToImage,
    publishedAt: a.publishedAt,
    content: a.content,
    sourceName: a.sourceName,
    aiSummary: a.aiSummary,
  );

  Article toArticle() => Article(
    author: author,
    title: title,
    description: description,
    url: url,
    urlToImage: urlToImage,
    publishedAt: publishedAt,
    content: content,
    sourceName: sourceName,
    aiSummary: aiSummary,
  );
}

@HiveType(typeId: 1)
class NewsStoryHive extends HiveObject {
  @HiveField(0)
  String canonicalTitle;

  @HiveField(1)
  List<ArticleHive> articles;

  @HiveField(2)
  String? summary;

  @HiveField(3)
  List<String>? storyTypes;

  @HiveField(4)
  String? imageUrl;

  NewsStoryHive({
    required this.canonicalTitle,
    required this.articles,
    this.summary,
    this.storyTypes,
    this.imageUrl,
  });

  factory NewsStoryHive.fromNewsStory(NewsStory s) => NewsStoryHive(
    canonicalTitle: s.canonicalTitle,
    articles: s.articles.map((a) => ArticleHive.fromArticle(a)).toList(),
    summary: s.summary,
    storyTypes: s.storyTypes,
    imageUrl: s.imageUrl,
  );

  NewsStory toNewsStory() => NewsStory(
    canonicalTitle: canonicalTitle,
    articles: articles.map((a) => a.toArticle()).toList(),
    summary: summary,
    storyTypes: storyTypes,
    imageUrl: imageUrl,
  );
}
