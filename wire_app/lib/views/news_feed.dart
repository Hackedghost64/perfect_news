import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/feed_controller.dart';
import '../models/article.dart';

class NewsFeedView extends StatefulWidget {
  const NewsFeedView({super.key});

  @override
  State<NewsFeedView> createState() => _NewsFeedViewState();
}

class _NewsFeedViewState extends State<NewsFeedView> {
  final FeedController _controller = FeedController();

  @override
  void initState() {
    super.initState();
    _controller.syncFeed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'WIRE',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 4.0),
        ),
        backgroundColor: Colors.black,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.white),
            onPressed: _controller.syncFeed,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading && _controller.articles.isEmpty) {
            return const Center(
              child: Text(
                "SYNCING WIRES...",
                style: TextStyle(letterSpacing: 2.0),
              ),
            );
          }

          if (_controller.errorMessage != null &&
              _controller.articles.isEmpty) {
            return Center(
              child: Text(
                _controller.errorMessage!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          return RefreshIndicator(
            color: Colors.white,
            backgroundColor: Colors.black,
            onRefresh: _controller.syncFeed,
            child: ListView.builder(
              itemCount: _controller.articles.length,
              itemBuilder: (context, index) {
                return ArticleCard(article: _controller.articles[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class ArticleCard extends StatelessWidget {
  final Article article;

  const ArticleCard({super.key, required this.article});

  Future<void> _launchUrl() async {
    final uri = Uri.parse(article.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.inAppWebView);
    } else {
      debugPrint("WARN: Cannot launch URL ${article.url}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        iconColor: Colors.white,
        collapsedIconColor: Colors.grey,
        title: Text(
          article.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              Text(
                article.source.toUpperCase(),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(article.publishedAt),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...article.bulletPoints.map(
                  (bullet) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      bullet,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _launchUrl,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white30),
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: const Text(
                    "ACCESS SOURCE FILE",
                    style: TextStyle(letterSpacing: 1.0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return "${diff.inMinutes}M AGO";
    if (diff.inHours < 24) return "${diff.inHours}H AGO";
    return "${diff.inDays}D AGO";
  }
}
