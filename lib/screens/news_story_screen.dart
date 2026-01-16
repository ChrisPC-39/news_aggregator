import 'package:flutter/material.dart';

import '../models/news_story_model.dart';
import '../services/crawler_service.dart';
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

  late Stream<List<NewsStory>> _storiesStream;
  bool _isLoading = true; // Track loading state

  @override
  void initState() {
    super.initState();
    _crawlerService.fetchAllSources();
    _scrollController.addListener(_onScroll);
    _storiesStream = _crawlerService.watchGroupedStories().asBroadcastStream();

    // Listen to processing status from CrawlerService
    _crawlerService.isProcessing.listen((isProcessing) {
      if (mounted) {
        setState(() => _isLoading = isProcessing);
      }
    });
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
    return GestureDetector(
      onTap: () => _searchFocusNode.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Stories'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          actions: [
            StreamBuilder<List<NewsStory>>(
              stream: _storiesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();

                final displayed = _applyAllFilters(snapshot.data!).length;

                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    '$displayed listed',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                );
              },
            ),
          ],
          // Add loading indicator at bottom of AppBar
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(_isLoading ? 3 : 0),
            child:
                _isLoading
                    ? LinearProgressIndicator(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.8),
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ),
        body: Stack(
          children: [
            StreamBuilder<List<NewsStory>>(
              stream: _storiesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final stories = _applyAllFilters(snapshot.data!);

                if (stories.isEmpty) {
                  return Center(
                    child:
                        _searchQuery.isNotEmpty
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
                                    });
                                  },
                                  child: const Text('Clear filters'),
                                ),
                              ],
                            ),
                  );
                }

                return ListView.builder(
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
                    final sources =
                        story.articles.map((a) => a.sourceName).toList();

                    return buildNewsStoryCard(context, story, sources);
                  },
                );
              },
            ),
            FloatingSearchAndFilter(
              selectedCategories: selectedCategories,
              minimumSources: minimumSources,
              showSearchBar: _showSearchBar,
              searchController: _searchController,
              searchQuery: _searchQuery,
              searchFocusNode: _searchFocusNode,
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

  // Centralized filtering logic
  List<NewsStory> _applyAllFilters(List<NewsStory> stories) {
    return stories.where((story) {
      if (selectedCategories.isNotEmpty) {
        // Merge all story types into a single set
        final allTypes = <String>{
          ...?story.storyTypes?.map((e) => e.toLowerCase().trim()),
          ...?story.inferredStoryTypes?.map((e) => e.toLowerCase().trim()),
        };

        if (allTypes.isEmpty) return false;

        if (!selectedCategories.every(allTypes.contains)) {
          return false;
        }
      }

      final uniqueSources =
          story.articles.map((a) => a.sourceName).toSet().length;
      if (uniqueSources < minimumSources) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.trimRight();
        return story.canonicalTitle.toLowerCase().contains(q) ||
            (story.summary?.toLowerCase().contains(q) ?? false) ||
            story.articles.any(
              (a) =>
                  a.title.toLowerCase().contains(q) ||
                  a.description.toLowerCase().contains(q),
            );
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
            // Wrap your image in a Stack
            SizedBox(
              width: double.infinity,
              height:
                  story.imageUrl != null && story.imageUrl!.isNotEmpty
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
                  // The Tag Overlay
                  if (manualTypes.isNotEmpty || aiTypes.isNotEmpty)
                    Positioned(
                      top: 12,
                      left: 12,
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

                  Visibility(
                    visible: story.summary != null,
                    child: const SizedBox(height: 8),
                  ),

                  Visibility(
                    visible: story.summary != null,
                    child: Text(
                      story.summary ?? "",
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),

                  Visibility(
                    visible: story.summary != null,
                    child: const SizedBox(height: 16),
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
    return ClipRRect( // Clips the blur to the border radius
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          // Use higher opacity and a touch of white for AI to fight dark/busy images
          color: isAi
              ? Colors.deepPurple.withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isAi ? Colors.deepPurple : Colors.white24,
            width: 1,
          ),
          // Optional: Add a subtle outer glow for the AI tag
          boxShadow: isAi ? [
            BoxShadow(
              color: Colors.deepPurple.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 1,
            )
          ] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAi)
              const Icon(
                Icons.auto_awesome,
                size: 12,
                color: Colors.white, // White icon pops better on purple
              ),
            if (isAi) const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: Colors.white, // Solid white text is the most readable
                fontSize: 10,
                fontWeight: FontWeight.w900, // Extra bold for small text
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}