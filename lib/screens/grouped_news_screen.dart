import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../models/news_story_model.dart';

class GroupedNewsScreen extends StatefulWidget {
  final NewsStory story;
  final bool isSaved;

  const GroupedNewsScreen({
    super.key,
    required this.story,
    required this.isSaved,
  });

  @override
  State<GroupedNewsScreen> createState() => _GroupedNewsScreenState();
}

class _GroupedNewsScreenState extends State<GroupedNewsScreen> {
  @override
  Widget build(BuildContext context) {
    final articles = widget.story.articles;

    return Scaffold(
      appBar: AppBar(title: const Text('Coverage')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.story.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                widget.story.imageUrl!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            widget.story.canonicalTitle,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.story.summary ?? "",
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          const Text(
            'Detailed Sources',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          // 3. Updated Article Mapping
          ...articles.map((article) {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 16,
              ),
              title: Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  article.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
              subtitle: Row(
                children: [
                  // 1. Small Rounded Source Icon
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(
                      'assets/images/${article.sourceName.toLowerCase()}.png',
                      width: 16,
                      height: 16,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) => const Icon(
                            Icons.public,
                            size: 16,
                            color: Colors.grey,
                          ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // 2. Source Name
                  Text(
                    article.sourceName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // 3. Dot Separator
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: Text("•", style: TextStyle(color: Colors.grey[600])),
                  ),

                  // 4. Prettier Date (Time Ago)
                  Text(
                    timeago.format(article.publishedAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              trailing: Icon(
                Icons.open_in_new,
                size: 14,
                color: Colors.grey[700],
              ),
              onTap: () async {
                final uri = Uri.parse(article.url);
                if (!await launchUrl(uri)) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open the link')),
                    );
                  }
                }
              },
            );
          }),
        ],
      ),
    );
  }
}
