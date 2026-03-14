import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../globals.dart';
import '../models/news_story_model.dart';
import '../services/crawler_service.dart';
import '../services/firebase_save_service.dart';
import '../services/grouped_stories_cache_service.dart';
import '../services/summary_service.dart';
import '../parsers/default_content_parser.dart';
import '../widgets/CustomDrawer.dart';
import '../widgets/FloatingSearchAndFilter.dart';
import '../widgets/NewsStoryCard.dart';
import 'grouped_news_screen.dart';

class SavedStoriesScreen extends StatefulWidget {
  final bool isPremium;
  final bool isAdmin;

  const SavedStoriesScreen({
    super.key,
    required this.isPremium,
    required this.isAdmin,
  });

  @override
  State<SavedStoriesScreen> createState() => _SavedStoriesScreenState();
}

class _SavedStoriesScreenState extends State<SavedStoriesScreen> {
  // ---------------------------------------------------------------------------
  // Search / filter / scroll state
  // ---------------------------------------------------------------------------
  bool _showSearchBar = true;
  double _lastScrollOffset = 1;
  String _searchQuery = '';

  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Set<String> selectedCategories = {};
  int minimumSources = 1; // Default 1 — saved stories may have only 1 source
  bool showSavedOnly = false; // Not used here but kept for widget compatibility
  Set<String> selectedSources =
      Globals.sourceConfigs.keys.map((s) => s.toLowerCase()).toSet();

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------
  final FirebaseSaveService _firebaseSaveService = FirebaseSaveService();
  final CrawlerService _crawlerService = CrawlerService();
  final GroupedStoriesCacheService _cacheService = GroupedStoriesCacheService();
  final SummaryService _summaryService = SummaryService();
  final DefaultContentParser _defaultContentParser = DefaultContentParser();

  /// All stories loaded from Firebase (never removed mid-session).
  List<NewsStory> _stories = [];

  /// Tracks bookmark state within this session.
  /// true  = still bookmarked
  /// false = unbookmarked this session (stays visible until user leaves)
  final Map<String, bool> _bookmarkState = {};

  /// AI summaries keyed by canonicalTitle.
  final Map<String, String?> _summaries = {};

  /// Active summary listeners keyed by canonicalTitle.
  final Map<String, StreamSubscription<Map<String, dynamic>?>>
  _summaryListeners = {};

  bool _isLoading = true;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadSavedStories();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    for (final sub in _summaryListeners.values) {
      sub.cancel();
    }
    _summaryListeners.clear();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Load saved stories from Firebase
  // ---------------------------------------------------------------------------
  Future<void> _loadSavedStories() async {
    setState(() => _isLoading = true);

    try {
      final rawMap = await _firebaseSaveService.fetchRawStoriesMap();

      final stories = <NewsStory>[];
      final summaries = <String, String?>{};
      final bookmarkState = <String, bool>{};

      for (final entry in rawMap.entries) {
        try {
          final storyData = entry.value as Map<String, dynamic>;
          final story = NewsStory.fromJson(storyData);
          final title = story.canonicalTitle;
          final summary = storyData['aiSummary'] as String?;

          stories.add(story);
          summaries[title] = summary?.isNotEmpty == true ? summary : null;
          bookmarkState[title] = true;

          // Listen for summary updates if premium and no summary yet
          if (widget.isPremium && (summary == null || summary.isEmpty)) {
            _listenForSummary(title);
          }
        } catch (e) {
          debugPrint('Failed to parse saved story "${entry.key}": $e');
        }
      }

      if (mounted) {
        setState(() {
          _stories = stories;
          _summaries.addAll(summaries);
          _bookmarkState.addAll(bookmarkState);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved stories: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Summary listener (same pattern as NewsStoryScreen)
  // ---------------------------------------------------------------------------
  void _listenForSummary(String title) {
    if (_summaryListeners.containsKey(title)) return;

    final sub = _firebaseSaveService.watchStory(title).listen((data) {
      final summary = data?['aiSummary'] as String?;
      if (summary != null && summary.isNotEmpty) {
        if (mounted) {
          setState(() {
            if (_bookmarkState.containsKey(title)) {
              _summaries[title] = summary;
            }
          });
        }
        _cacheService.updateSummary(title, summary);
        _summaryListeners.remove(title)?.cancel();
      }
    });

    _summaryListeners[title] = sub;
  }

  // ---------------------------------------------------------------------------
  // Bookmark toggle — story stays visible until user leaves the screen
  // ---------------------------------------------------------------------------
  Future<void> _toggleBookmark(NewsStory story) async {
    final title = story.canonicalTitle;
    final isCurrentlySaved = _bookmarkState[title] ?? false;

    // Optimistic update — flip the state but keep the card visible
    setState(() {
      _bookmarkState[title] = !isCurrentlySaved;
      if (isCurrentlySaved) {
        _summaryListeners.remove(title)?.cancel();
      }
    });

    try {
      if (isCurrentlySaved) {
        await _firebaseSaveService.deleteStory(title);
        await _cacheService.removeBookmark(title);
      } else {
        // Re-saving a story that was un-bookmarked this session
        await _firebaseSaveService.saveStory(story);
        await _cacheService.saveBookmarkedStory(story);

        if (widget.isPremium) {
          _generateAndUploadSummary(story);
          _listenForSummary(title);
        }
      }
    } catch (e) {
      // Rollback
      setState(() => _bookmarkState[title] = isCurrentlySaved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update bookmark')),
        );
      }
    }
  }

  /// Generates the AI summary and writes it to Firestore.
  Future<void> _generateAndUploadSummary(NewsStory story) async {
    try {
      final articleContents = <String>[];

      for (final article in story.articles) {
        final content = await _defaultContentParser.fetchContent(article.url);
        if (content != null && content.isNotEmpty) {
          articleContents.add('--- ${article.url} ---\n$content');
        }
      }

      if (articleContents.isEmpty) return;

      final summary = await _summaryService.generateSummary(
        articleContents.join('\n\n'),
      );
      await _firebaseSaveService.updateStorySummary(
        story.canonicalTitle,
        summary,
      );
    } catch (e) {
      debugPrint('AI Summary generation failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Scroll handling
  // ---------------------------------------------------------------------------
  void _onScroll() {
    final offset = _scrollController.offset;
    if (offset < _lastScrollOffset && !_showSearchBar) {
      setState(() => _showSearchBar = true);
    } else if (offset > _lastScrollOffset && offset > 100 && _showSearchBar) {
      setState(() => _showSearchBar = false);
    }
    _lastScrollOffset = offset;
  }

  // ---------------------------------------------------------------------------
  // Filtering — identical logic to NewsStoryScreen, minus the saved-only toggle
  // ---------------------------------------------------------------------------
  List<NewsStory> _applyAllFilters(List<NewsStory> stories) {
    return stories.where((story) {
      // 1. Source filter
      final storySourceIds =
          story.articles.map((a) => a.sourceName.toLowerCase()).toSet();
      final hasActiveSource = storySourceIds.any(
        (id) => selectedSources.contains(id),
      );
      if (!hasActiveSource) return false;

      // 2. Category filter
      if (selectedCategories.isNotEmpty) {
        final allTypes = <String>{
          ...?story.storyTypes?.map((e) => e.toLowerCase().trim()),
          ...?story.inferredStoryTypes?.map((e) => e.toLowerCase().trim()),
        };
        if (allTypes.isEmpty || !selectedCategories.every(allTypes.contains)) {
          return false;
        }
      }

      // 3. Minimum sources filter
      final uniqueSourcesCount =
          story.articles.map((a) => a.sourceName).toSet().length;
      if (uniqueSourcesCount < minimumSources) return false;

      // 4. Search filter
      if (_searchQuery.isNotEmpty) {
        final q = Globals.normalizeDiacritics(_searchQuery).trim();
        final normalizedTitle = Globals.normalizeDiacritics(
          story.canonicalTitle,
        );
        final normalizedSummary = Globals.normalizeDiacritics(
          story.summary ?? '',
        );
        return normalizedTitle.contains(q) || normalizedSummary.contains(q);
      }

      return true;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final filteredStories = _applyAllFilters(_stories);

    return GestureDetector(
      onTap: () => _searchFocusNode.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Saved Stories'),
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
            child:
                _isLoading
                    ? LinearProgressIndicator(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.8),
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ),
        drawer: CustomDrawer(
          isPremium: widget.isPremium,
          isAdmin: widget.isAdmin,
          activeScreen: ActiveScreen.saved
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
              // Hide the saved-only toggle — not relevant on this screen
              showSavedOnly: false,
              onSavedOnlyToggled: (_) {},
              onSourceToggled: (source, isSelected) {
                setState(() {
                  final allSources =
                      Globals.sourceConfigs.keys
                          .map((s) => s.toLowerCase())
                          .toSet();
                  if (selectedSources.length == allSources.length) {
                    selectedSources.clear();
                    selectedSources.add(source);
                  } else {
                    if (isSelected) {
                      selectedSources.add(source);
                    } else {
                      selectedSources.remove(source);
                    }
                    if (selectedSources.isEmpty) {
                      selectedSources.addAll(allSources);
                    }
                  }
                });
              },
              onSearchChanged: (value) {
                setState(() {
                  _searchQuery = Globals.normalizeDiacritics(value);
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_stories.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 48, color: Colors.white38),
            SizedBox(height: 16),
            Text(
              'No saved stories yet.',
              style: TextStyle(color: Colors.white60),
            ),
            SizedBox(height: 8),
            Text(
              'Bookmark a story to see it here.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (stories.isEmpty) {
      return Center(
        child:
            _searchQuery.isNotEmpty
                ? Text('No stories match "$_searchQuery"')
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No stories match the current filters.'),
                    TextButton(
                      onPressed:
                          () => setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                            selectedCategories.clear();
                            minimumSources = 1;
                            selectedSources =
                                Globals.sourceConfigs.keys
                                    .map((s) => s.toLowerCase())
                                    .toSet();
                          }),
                      child: const Text('Clear filters'),
                    ),
                  ],
                ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSavedStories,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: stories.length,
        itemBuilder: (context, index) {
          final story = stories[index];
          final title = story.canonicalTitle;
          final isSaved = _bookmarkState[title] ?? false;

          return NewsStoryCard(
            story: story,
            isSaved: isSaved,
            aiSummary: _summaries[title],
            isPremium: widget.isPremium,
            onBookmarkToggle: () => _toggleBookmark(story),
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => GroupedNewsScreen(
                          story: story,
                          isSaved: isSaved,
                          crawlerService: _crawlerService,
                          aiSummary: _summaries[title],
                          isPremium: widget.isPremium,
                          onBookmarkToggle: () => _toggleBookmark(story),
                        ),
                  ),
                ),
          );
        },
      ),
    );
  }
}
