class Article {
  final String? author;
  final String title;
  final String description;
  final String url;
  final String? urlToImage;
  final DateTime publishedAt;
  final String? content;
  final String sourceName;
  final String? aiSummary;

  Article({
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

  Map<String, dynamic> toJson() {
    return {
      // 'author': author,
      'title': title,
      'description': description,
      // 'content': content,
      'url': url,
      'urlToImage': urlToImage,
      'publishedAt': publishedAt.toIso8601String(),
      'sourceName': sourceName,
      'aiSummary': aiSummary
    };
  }

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      author: json['author'] as String?,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      content: json['content'] as String?,
      url: json['url'] as String,
      urlToImage: json['urlToImage'] as String?,
      publishedAt: DateTime.parse(json['publishedAt'] as String),
      sourceName: json['sourceName'] as String,
      aiSummary: json['aiSummary'] as String?,
    );
  }
}