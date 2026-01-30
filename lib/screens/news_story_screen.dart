import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For compute()
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../globals.dart';
import '../models/news_story_model.dart';
import '../models/article_model.dart';
import '../services/crawler_service.dart';
import '../services/v3_score_service.dart';
import '../widgets/FloatingSearchAndFilter.dart';
import 'grouped_news_screen.dart';

class GroupedNewsResultsPage extends StatefulWidget {
  const GroupedNewsResultsPage({super.key});

  @override
  State<GroupedNewsResultsPage> createState() => _GroupedNewsResultsPageState();
}

class _GroupedNewsResultsPageState extends State<GroupedNewsResultsPage> {
  bool _showSearchBar = true;
  double _lastScrollOffset = 1;
  String _searchQuery = '';

  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final CrawlerService _crawlerService = CrawlerService();

  Set<String> selectedCategories = {};
  int minimumSources = 2;
  Set<String> selectedSources =
  Globals.sourceConfigs.keys.map((source) => source.toLowerCase()).toSet();

  // Direct state instead of stream
  List<NewsStory> _stories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Load initial cached stories synchronously
    _stories = _crawlerService.cache.load();

    // Listen to processing status
    _crawlerService.isProcessing.listen((isProcessing) {
      if (mounted) {
        setState(() => _isLoading = isProcessing);
      }
    });

    // Fetch and refresh in background
    _refreshNews();
  }

  Future<void> _refreshNews() async {
    setState(() => _isLoading = true);

    try {
      // Fetch all sources (parallel)
      await _crawlerService.fetchAllSources();

      // Get articles
      final articles = _crawlerService.localRepo.getArticles();

      // print('🔄 Starting grouping for ${articles.length} articles...');

      // Run grouping in isolate to prevent UI freeze
      final grouped = await _groupArticlesInBackground(articles);

      // print('✅ Grouping complete: ${grouped.length} stories');

      // Save to cache
      await _crawlerService.cache.save(grouped);

      // Update UI
      if (mounted) {
        setState(() {
          _stories = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error refreshing news: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Run grouping in background isolate
  Future<List<NewsStory>> _groupArticlesInBackground(List<Article> articles) async {
    // Convert to JSON for serialization
    final articlesJson = articles.map((a) => a.toJson()).toList();

    // Run in isolate
    final groupedJson = await compute(_groupArticlesIsolate, articlesJson);

    // Convert back to objects
    return groupedJson.map((json) => NewsStory.fromJson(json)).toList();
  }

  // Top-level function for isolate
  static List<Map<String, dynamic>> _groupArticlesIsolate(List<Map<String, dynamic>> articlesJson) {
    // Reconstruct articles from JSON
    final articles = articlesJson.map((json) => Article.fromJson(json)).toList();

    // Use ScoreService to group
    final scoreService = ScoreService();
    final grouped = scoreService.groupArticlesIncremental([], articles);

    // Deduplicate
    for (var story in grouped) {
      final seen = <String>{};
      story.articles.retainWhere((article) {
        final key = '${article.sourceName}::${article.title.trim().toLowerCase()}';
        if (seen.contains(key)) return false;
        seen.add(key);
        return true;
      });
    }
    grouped.removeWhere((story) => story.articles.isEmpty);

    // Convert to JSON for return
    return grouped.map((story) => story.toJson()).toList();
  }

  void _onScroll() {
    final offset = _scrollController.offset;

    if (offset < _lastScrollOffset && !_showSearchBar) {
      setState(() => _showSearchBar = true);
    } else if (offset > _lastScrollOffset && offset > 100 && _showSearchBar) {
      setState(() => _showSearchBar = false);
    }

    _lastScrollOffset = offset;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredStories = _applyAllFilters(_stories);

    return GestureDetector(
      onTap: () => _searchFocusNode.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Stories'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${filteredStories.length} listed',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white60,
                  fontSize: 14,
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(_isLoading ? 3 : 0),
            child: _isLoading
                ? LinearProgressIndicator(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withValues(alpha: 0.8),
              ),
            )
                : const SizedBox.shrink(),
          ),
        ),
        body: Stack(
          children: [
            _buildBody(filteredStories),
            FloatingSearchAndFilter(
              selectedCategories: selectedCategories,
              selectedSources: selectedSources,
              minimumSources: minimumSources,
              showSearchBar: _showSearchBar,
              searchController: _searchController,
              searchQuery: _searchQuery,
              searchFocusNode: _searchFocusNode,
              onSourceToggled: (source, isSelected) {
                setState(() {
                  isSelected
                      ? selectedSources.add(source)
                      : selectedSources.remove(source);
                });
              },
              onSearchChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                  _showSearchBar = true;
                });
              },
              onClearSearch: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
              onCategoryToggled: (category, selected) {
                final normalized = category.toLowerCase().trim();
                setState(() {
                  selected
                      ? selectedCategories.add(normalized)
                      : selectedCategories.remove(normalized);
                });
              },
              onMinimumSourcesChanged: (value) {
                setState(() => minimumSources = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<NewsStory> stories) {
    if (_stories.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (stories.isEmpty) {
      return Center(
        child: _searchQuery.isNotEmpty
            ? Text('No stories match "$_searchQuery"')
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No news found.'),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  selectedCategories.clear();
                  minimumSources = 1;
                  selectedSources = Globals.sourceConfigs.keys
                      .map((source) => source.toLowerCase())
                      .toSet();
                });
              },
              child: const Text('Clear filters'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshNews,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(
          top: 8,
          bottom: 80,
          left: 8,
          right: 8,
        ),
        itemCount: stories.length,
        itemBuilder: (context, index) {
          final story = stories[index];
          final sources = story.articles.map((a) => a.sourceName).toList();

          return buildNewsStoryCard(context, story, sources);
        },
      ),
    );
  }

  // Centralized filtering logic
  List<NewsStory> _applyAllFilters(List<NewsStory> stories) {
    return stories.where((story) {
      // 1. Source Filter
      final storySourceIds =
      story.articles.map((a) => a.sourceName.toLowerCase()).toSet();
      final hasActiveSource = storySourceIds.any(
            (id) => selectedSources.contains(id),
      );
      if (!hasActiveSource) return false;

      // 2. Category Filter
      if (selectedCategories.isNotEmpty) {
        final allTypes = <String>{
          ...?story.storyTypes?.map((e) => e.toLowerCase().trim()),
          ...?story.inferredStoryTypes?.map((e) => e.toLowerCase().trim()),
        };
        if (allTypes.isEmpty || !selectedCategories.every(allTypes.contains)) {
          return false;
        }
      }

      // 3. Minimum Sources Filter
      final uniqueSources =
          story.articles.map((a) => a.sourceName).toSet().length;
      if (uniqueSources < minimumSources) return false;

      // 4. Search Filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.trimRight();
        return story.canonicalTitle.toLowerCase().contains(q) ||
            (story.summary?.toLowerCase().contains(q) ?? false);
      }

      return true;
    }).toList();
  }

  Widget buildNewsStoryCard(
      BuildContext context,
      NewsStory story,
      List<String> sources,
      ) {
    final manualTypes = story.storyTypes ?? [];
    final aiTypes = story.inferredStoryTypes ?? [];

    final articles = story.articles;

    // Get unique source names
    final uniqueSources =
    articles.map((a) => a.sourceName).toSet().toList();

    // Find date range
    final dates = articles.map((a) => a.publishedAt).toList();
    dates.sort();

    final String dateDisplay;

    if (dates.isEmpty) {
      dateDisplay = "No date";
    } else {
      final firstDate = dates.first;
      final lastDate = dates.last;

      if (DateFormat('yyyyMMdd').format(firstDate) ==
          DateFormat('yyyyMMdd').format(lastDate)) {
        dateDisplay = timeago.format(lastDate);
      } else {
        final String firstDateStr = DateFormat('MMM d').format(firstDate);
        final String lastDateStr = DateFormat('MMM d').format(lastDate);
        dateDisplay = "$firstDateStr - $lastDateStr";
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => GroupedNewsScreen(story: story)),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: story.imageUrl != null && story.imageUrl!.isNotEmpty
                  ? 200
                  : 35,
              child: Stack(
                children: [
                  if (story.imageUrl != null && story.imageUrl!.isNotEmpty)
                    Image.network(
                      story.imageUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  if (manualTypes.isNotEmpty || aiTypes.isNotEmpty)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ...manualTypes.map(
                                (type) => _buildTagChip(type, isAi: false),
                          ),
                          ...aiTypes.map(
                                (type) => _buildTagChip(type, isAi: true),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.canonicalTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (story.summary != null) const SizedBox(height: 8),
                  if (story.summary != null)
                    Text(
                      story.summary!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60),
                    ),
                  if (story.summary != null) const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: (uniqueSources.length * 14.0) + 10,
                        child: Stack(
                          children: List.generate(uniqueSources.length, (index) {
                            return Positioned(
                              left: index * 14.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.grey[900],
                                  backgroundImage: AssetImage(
                                    'assets/images/${uniqueSources[index].toLowerCase()}.png',
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${uniqueSources.join(', ')} • $dateDisplay",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagChip(String label, {required bool isAi}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isAi
              ? Colors.deepPurple.withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isAi ? Colors.deepPurple : Colors.white24,
            width: 1,
          ),
          boxShadow: isAi
              ? [
            BoxShadow(
              color: Colors.deepPurple.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAi)
              const Icon(
                Icons.auto_awesome,
                size: 12,
                color: Colors.white,
              ),
            if (isAi) const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}