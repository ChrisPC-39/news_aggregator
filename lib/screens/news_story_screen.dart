import 'package:flutter/material.dart';

import '../globals.dart';
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
  int minimumSources = 0;

  late Stream<List<NewsStory>> _storiesStream;

  @override
  void initState() {
    super.initState();
    // _crawlerService.fetchAllSources();
    _scrollController.addListener(_onScroll);
    _storiesStream = _crawlerService.watchGroupedStories();
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
        ),
        body: StreamBuilder<List<NewsStory>>(
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

            return Stack(
              children: [
                ListView.builder(
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
                ),

                FloatingSearchAndFilter(
                  selectedCategories: selectedCategories,
                  minimumSources: minimumSources,
                  showSearchBar: _showSearchBar,
                  searchController: _searchController,
                  searchQuery: _searchQuery,
                  searchFocusNode: _searchFocusNode,
                  onSearchChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                  onClearSearch: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                  onCategoryToggled: (category, selected) {
                    setState(() {
                      selected
                          ? selectedCategories.add(category)
                          : selectedCategories.remove(category);
                    });
                  },
                  onMinimumSourcesChanged: (value) {
                    setState(() => minimumSources = value);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 🔎 Centralized filtering logic
  List<NewsStory> _applyAllFilters(List<NewsStory> stories) {
    return stories.where((story) {
      if (selectedCategories.isNotEmpty &&
          (story.storyType == null ||
              !selectedCategories.contains(story.storyType))) {
        return false;
      }

      final uniqueSources =
          story.articles.map((a) => a.sourceName).toSet().length;
      if (uniqueSources < minimumSources) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery;
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
    int leftCount =
        sources.where((s) => Globals.leftSources.contains(s)).length;
    int centerCount =
        sources.where((s) => Globals.centerSources.contains(s)).length;
    int rightCount =
        sources.where((s) => Globals.rightSources.contains(s)).length;

    // Only include categories with count > 0
    final counts = {
      "Left": leftCount,
      "Center": centerCount,
      "Right": rightCount,
    }..removeWhere((_, value) => value == 0);

    final totalCount = counts.values.fold(0, (a, b) => a + b);

    // If totalCount == 0, give dummy flex values to avoid Row collapse
    final flexLeft = leftCount > 0 ? leftCount : 0;
    final flexCenter = centerCount > 0 ? centerCount : 0;
    final flexRight = rightCount > 0 ? rightCount : 0;

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
                  if (story.storyType != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          story.storyType!.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
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

                  // Segmented Bar
                  SizedBox(
                    height: 10,
                    child: Row(
                      children: [
                        if (flexLeft > 0)
                          Expanded(
                            flex: flexLeft,
                            child: Container(color: Colors.blue[400]),
                          ),
                        if (flexCenter > 0)
                          Expanded(
                            flex: flexCenter,
                            child: Container(color: Colors.grey[400]),
                          ),
                        if (flexRight > 0)
                          Expanded(
                            flex: flexRight,
                            child: Container(color: Colors.red[400]),
                          ),
                        if (totalCount == 0)
                          Expanded(
                            flex: 1,
                            child: Container(color: Colors.grey.shade300),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
