import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/article_model.dart';
import '../services/crawler_service.dart';

class CrawlerResultsPage extends StatefulWidget {
  const CrawlerResultsPage({super.key});

  @override
  State<CrawlerResultsPage> createState() => _CrawlerResultsPageState();
}

class _CrawlerResultsPageState extends State<CrawlerResultsPage> {
  late Future<List<Article>> _newsFuture;
  final CrawlerService _apiService = CrawlerService();

  // Mapping URLs to friendly names
  final Map<String, String> domainNames = {
    'adevarul.ro': 'Adevărul',
    'hotnews.ro': 'HotNews',
    'digi24.ro': 'Digi24',
    'libertatea.ro': 'Libertatea',
    'tvrinfo.ro': 'TVR Info',
    'romaniatv.net': 'RomaniaTV',
    'antena3.ro': 'Antena 3',
  };

  // Track which domains are selected
  final Set<String> selectedDomains = {};

  @override
  void initState() {
    super.initState();
    _newsFuture = _apiService.fetchAllSources();
  }

  String extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('News Results'),
      ),
      body: FutureBuilder<List<Article>>(
        future: _newsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final articles = snapshot.data!;

          // Extract all domains present in the current data
          final availableDomains = articles
              .map((a) => extractDomain(a.url))
              .where(domainNames.containsKey)
              .toSet()
              .toList();

          // Filter articles based on selected domains
          final filteredArticles = selectedDomains.isEmpty
              ? articles
              : articles
              .where((a) => selectedDomains.contains(extractDomain(a.url)))
              .toList();

          return Column(
            children: [
              // ----- Filter chips row -----
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: availableDomains.map((domain) {
                    final friendlyName = domainNames[domain] ?? domain;
                    final isSelected = selectedDomains.contains(domain);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: FilterChip(
                        label: Text(friendlyName),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedDomains.add(domain);
                            } else {
                              selectedDomains.remove(domain);
                            }
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const Divider(height: 1),

              // ----- Article list -----
              Expanded(
                child: filteredArticles.isEmpty
                    ? const Center(child: Text('No articles for selected sources'))
                    : ListView.builder(
                  itemCount: filteredArticles.length,
                  itemBuilder: (context, index) {
                    final article = filteredArticles[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      elevation: 4,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (article.urlToImage != null)
                            Image.network(
                              article.urlToImage!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      launchArticleUrl(context, article.url),
                                  child: Text(
                                    article.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontSize: 18),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  article.description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        domainNames[
                                        extractDomain(article.url)] ??
                                            extractDomain(article.url),
                                        style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: Theme.of(context)
                                                .primaryColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('MMM d, yyyy')
                                          .format(article.publishedAt),
                                      style:
                                      const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> launchArticleUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link')),
      );
    }
  }
}
