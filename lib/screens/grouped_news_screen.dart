import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../globals.dart';
import '../models/news_story_model.dart';

class GroupedNewsScreen extends StatefulWidget {
  final NewsStory story;

  const GroupedNewsScreen({super.key, required this.story});

  @override
  State<GroupedNewsScreen> createState() => _GroupedNewsScreenState();
}

class _GroupedNewsScreenState extends State<GroupedNewsScreen> {
  String getBiasType(String sourceName) {
    final name = sourceName.toLowerCase();
    if (Globals.leftSources.any((s) => name.contains(s.toLowerCase()))) {
      return 'Left';
    }
    if (Globals.centerSources.any((s) => name.contains(s.toLowerCase()))) {
      return 'Center';
    }
    if (Globals.rightSources.any((s) => name.contains(s.toLowerCase()))) {
      return 'Right';
    }
    return 'Neutral';
  }

  // 2. Helper for bias colors
  Color getBiasColor(String bias) {
    switch (bias) {
      case 'Left':
        return Colors.blue[400]!;
      case 'Center':
        return Colors.grey[400]!;
      case 'Right':
        return Colors.red[400]!;
      default:
        return Colors.grey;
    }
  }

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
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              title: Text(article.title),
              subtitle: Row(
                children: [
                  Text(article.publishedAt.toIso8601String()),
                  const SizedBox(width: 8),
                  Text(
                    article.sourceName,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () async {
                final uri = Uri.parse(article.url);
                if (!await launchUrl(uri)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open the link')),
                  );
                }
              },
            );
          }),
        ],
      ),
    );
  }
}
