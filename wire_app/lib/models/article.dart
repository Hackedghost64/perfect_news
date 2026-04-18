class Article {
  final String id;
  final String title;
  final String source;
  final String url;
  final List<String> bulletPoints;
  final DateTime publishedAt;

  Article({
    required this.id,
    required this.title,
    required this.source,
    required this.url,
    required this.bulletPoints,
    required this.publishedAt,
  });
}
