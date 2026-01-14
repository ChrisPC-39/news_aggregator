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
  double _lastScrollOffset = 0;
  String _searchQuery = '';
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _scrollController = ScrollController();
  final CrawlerService _crawlerService = CrawlerService();
  late Future<List<NewsStory>> _storiesFuture;
  Set<String> selectedCategories = {};
  int minimumSources = 2;

  @override
  void initState() {
    super.initState();
    _storiesFuture = _crawlerService.fetchGroupedStories();

    // Listen to scroll changes
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final currentScrollOffset = _scrollController.offset;

    // Show search bar when scrolling up, hide when scrolling down
    if (currentScrollOffset < _lastScrollOffset) {
      // Scrolling up
      if (!_showSearchBar) {
        setState(() => _showSearchBar = true);
      }
    } else if (currentScrollOffset > _lastScrollOffset && currentScrollOffset > 50) {
      // Scrolling down (and past 50 pixels to avoid hiding at top)
      if (_showSearchBar) {
        setState(() => _showSearchBar = false);
      }
    }

    _lastScrollOffset = currentScrollOffset;
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
      onTap: () {
        _searchFocusNode.unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Stories'),
          actions: [
            FutureBuilder<List<NewsStory>>(
              future: _storiesFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container();
                }

                // Filter by selected categories
                final filteredByCategory = snapshot.data!.where(
                      (story) =>
                  selectedCategories.isEmpty ||
                      (story.storyType != null &&
                          selectedCategories.contains(story.storyType)),
                );

                // Filter by minimum sources
                final displayedStoriesList =
                filteredByCategory
                    .where(
                      (story) =>
                  story.articles
                      .map((a) => a.sourceName)
                      .toSet()
                      .length >=
                      minimumSources,
                )
                    .toList();

                final displayedStories = displayedStoriesList.length;

                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    '$displayedStories listed',
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
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // News list wrapped in Expanded
            Expanded(
              child: Stack(
                children: [
                  // Main FutureBuilder with ListView
                  FutureBuilder<List<NewsStory>>(
                    future: _storiesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('No grouped news found.'));
                      }

                      // Filter by selected categories
                      var stories = snapshot.data!.where(
                            (story) =>
                        selectedCategories.isEmpty ||
                            (story.storyType != null &&
                                selectedCategories.contains(story.storyType)),
                      ).toList();

                      // Filter by search query
                      if (_searchQuery.isNotEmpty) {
                        stories = stories.where((story) {
                          final titleMatch = story.canonicalTitle
                              .toLowerCase()
                              .contains(_searchQuery);
                          final summaryMatch = story.summary
                              ?.toLowerCase()
                              .contains(_searchQuery) ?? false;
                          final articlesMatch = story.articles.any(
                                (article) =>
                            article.title.toLowerCase().contains(_searchQuery) ||
                                article.description.toLowerCase().contains(_searchQuery),
                          );
                          return titleMatch || summaryMatch || articlesMatch;
                        }).toList();
                      }

                      if (stories.isEmpty) {
                        return Center(
                          child: Text(
                            _searchQuery.isNotEmpty
                                ? 'No stories match "$_searchQuery"'
                                : 'No news found for selected categories.',
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(
                          top: 8,
                          bottom: 80, // Space for search bar
                          left: 8,
                          right: 8,
                        ),
                        itemCount: stories.length,
                        itemBuilder: (context, index) {
                          final story = stories[index];

                          final sourcesList =
                          story.articles.map((a) => a.sourceName).toList();
                          final sources =
                          story.articles
                              .map((a) => a.sourceName)
                              .toSet()
                              .toList();

                          if (sources.length < minimumSources) {
                            return Container();
                          }

                          return SizedBox(
                            width: double.infinity,
                            child: buildNewsStoryCard(context, story, sourcesList),
                          );
                        },
                      );
                    },
                  ),

                  // Combined Search and Filter widget
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
                      });
                    },
                    onClearSearch: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                    onCategoryToggled: (category, selected) {
                      setState(() {
                        if (selected) {
                          selectedCategories.add(category);
                        } else {
                          selectedCategories.remove(category);
                        }
                      });
                    },
                    onMinimumSourcesChanged: (value) {
                      setState(() {
                        minimumSources = value;
                      });
                    },
                  ),
                  // Floating Search Bar at Bottom
                  // Positioned(
                  //   left: 0,
                  //   right: 0,
                  //   bottom: 0,
                  //   child: AnimatedSlide(
                  //     duration: const Duration(milliseconds: 200),
                  //     curve: Curves.easeInOut,
                  //     offset: _showSearchBar ? Offset.zero : const Offset(0, 1),
                  //     child: Container(
                  //       padding: const EdgeInsets.all(12),
                  //       decoration: BoxDecoration(
                  //         color: Colors.transparent,
                  //         boxShadow: [
                  //           BoxShadow(
                  //             color: Colors.black.withOpacity(0.15),
                  //             blurRadius: 8,
                  //             offset: const Offset(0, -2),
                  //           ),
                  //         ],
                  //       ),
                  //       child: TextField(
                  //         controller: _searchController,
                  //         focusNode: _searchFocusNode,
                  //         decoration: InputDecoration(
                  //           hintText: 'Search stories...',
                  //           prefixIcon: const Icon(Icons.search),
                  //           suffixIcon: _searchQuery.isNotEmpty
                  //               ? IconButton(
                  //             icon: const Icon(Icons.clear),
                  //             onPressed: () {
                  //               setState(() {
                  //                 _searchController.clear();
                  //                 _searchQuery = '';
                  //               });
                  //             },
                  //           )
                  //               : null,
                  //           filled: true,
                  //           border: OutlineInputBorder(
                  //             borderRadius: BorderRadius.circular(12),
                  //             borderSide: BorderSide.none,
                  //           ),
                  //           contentPadding: const EdgeInsets.symmetric(
                  //             horizontal: 16,
                  //             vertical: 12,
                  //           ),
                  //         ),
                  //         onChanged: (value) {
                  //           setState(() {
                  //             _searchQuery = value.toLowerCase();
                  //           });
                  //         },
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),

            // Bottom chip selector

          ],
        )
      ),
    );
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
              height: 200,
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
