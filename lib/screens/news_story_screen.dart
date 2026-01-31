import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For compute()

import '../globals.dart';
import '../models/news_story_model.dart';
import '../models/article_model.dart';
import '../services/crawler_service.dart';
import '../services/summary_service.dart';
import '../services/firebase_save_service.dart';
import '../services/v3_score_service.dart';
import '../widgets/FloatingSearchAndFilter.dart';
import '../widgets/NewsStoryCard.dart';
import 'grouped_news_screen.dart';

class NewsStoryScreen extends StatefulWidget {
  const NewsStoryScreen({super.key});

  @override
  State<NewsStoryScreen> createState() => _NewsStoryScreenState();
}

class _NewsStoryScreenState extends State<NewsStoryScreen>
    with SingleTickerProviderStateMixin {
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
  int minimumSources = 2;
  Set<String> selectedSources =
      Globals.sourceConfigs.keys.map((source) => source.toLowerCase()).toSet();

  // ---------------------------------------------------------------------------
  // News data
  // ---------------------------------------------------------------------------
  final CrawlerService _crawlerService = CrawlerService();
  List<NewsStory> _stories = [];
  bool _isLoading = true;

  // ---------------------------------------------------------------------------
  // Bookmark + summary state
  //
  // Key  = canonicalTitle
  // Value = null   → saved, but AI summary hasn't arrived yet
  //       = String → the summary text
  //
  // A title that is NOT in this map is simply not bookmarked.
  // ---------------------------------------------------------------------------
  final Map<String, String?> _savedStories = {};

  /// Active one-shot subscriptions keyed by canonicalTitle.
  /// Each subscription cancels itself once the summary arrives.
  final Map<String, StreamSubscription<Map<String, dynamic>?>>
  _summaryListeners = {};

  final SummaryService _summaryService = SummaryService();
  final FirebaseSaveService _firebaseSaveService = FirebaseSaveService();

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _stories = _crawlerService.cache.load();

    _crawlerService.isProcessing.listen((isProcessing) {
      if (mounted) setState(() => _isLoading = isProcessing);
    });

    // _fetchSavedStories must run after _refreshNews so it compares against
    // the final crawled list — otherwise _refreshNews overwrites _stories
    // and wipes out any Firebase stories that were appended.
    _refreshNews().then((_) => _fetchSavedStories());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    // Cancel every active one-shot listener.
    for (final sub in _summaryListeners.values) {
      sub.cancel();
    }
    _summaryListeners.clear();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Firebase: initial load of saved stories
  // ---------------------------------------------------------------------------

  /// Loads saved bookmark state from Firebase, and hydrates any stories
  /// that exist in Firebase but are missing from the local crawled list.
  Future<void> _fetchSavedStories() async {
    final snapshot = await _firebaseSaveService.fetchRawStoriesMap();
    if (!mounted) return;

    final localTitles = _stories.map((s) => s.canonicalTitle).toSet();
    final missingStories = <NewsStory>[];

    setState(() {
      _savedStories.clear();

      for (final entry in snapshot.entries) {
        final title = entry.key;
        final storyData = entry.value as Map<String, dynamic>;

        // Read the aiSummary directly from the raw map.
        final aiSummary = storyData['aiSummary'] as String?;
        _savedStories[title] =
            (aiSummary != null && aiSummary.isNotEmpty) ? aiSummary : null;

        // If this story isn't in the local crawled list, deserialize and
        // collect it so we can append it below.
        if (!localTitles.contains(title)) {
          try {
            missingStories.add(NewsStory.fromJson(storyData));
          } catch (e) {
            debugPrint('Failed to deserialize saved story "$title": $e');
          }
        }

        // If the summary is still pending, open a one-shot listener so the
        // card updates when it arrives.
        if (_savedStories[title] == null) {
          _listenForSummary(title);
        }
      }

      // Append any stories that exist in Firebase but not locally.
      if (missingStories.isNotEmpty) {
        _stories.addAll(missingStories);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Bookmark toggle
  // ---------------------------------------------------------------------------
  Future<void> toggleBookmark(NewsStory story) async {
    final title = story.canonicalTitle;
    final isCurrentlySaved = _savedStories.containsKey(title);

    // Optimistic update
    setState(() {
      if (isCurrentlySaved) {
        _savedStories.remove(title);
        // Cancel any pending listener for this title
        _summaryListeners.remove(title)?.cancel();
      } else {
        // null = saved but summary pending
        _savedStories[title] = null;
      }
    });

    try {
      if (isCurrentlySaved) {
        await _firebaseSaveService.deleteStory(title);
      } else {
        await _firebaseSaveService.saveStory(story);
      }
    } catch (e) {
      // Rollback only if the Firestore write itself failed.
      setState(() {
        if (isCurrentlySaved) {
          _savedStories[title] = null; // restore as saved (summary unknown)
        } else {
          _savedStories.remove(title); // undo the optimistic add
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to update")));
      }
      return; // don't proceed to summary generation if the write failed
    }

    // Only reached if the Firestore write succeeded.
    // These are both fire-and-forget — failures here are logged internally
    // and should never surface as "Failed to update".
    if (!isCurrentlySaved) {
      _generateAndUploadSummary(story);
      _listenForSummary(title);
    }
  }

  /// Generates the AI summary and writes it to Firestore.
  Future<void> _generateAndUploadSummary(NewsStory story) async {
    try {
      final summary = await _summaryService.generateSummary(story);
      await _firebaseSaveService.updateStorySummary(
        story.canonicalTitle,
        summary,
      );
      // Note: we don't setState here — the one-shot listener in
      // _listenForSummary will pick up the change and do it for us.
    } catch (e) {
      debugPrint("AI Summary generation failed: $e");
    }
  }

  /// Opens a Firestore listener on the user doc. As soon as the summary
  /// field for [title] is non-empty, it updates local state and cancels itself.
  void _listenForSummary(String title) {
    // If there's already a listener for this title, don't open another one.
    if (_summaryListeners.containsKey(title)) return;

    final sub = _firebaseSaveService.watchStory(title).listen((data) {
      final summary = data?['aiSummary'] as String?;

      if (summary != null && summary.isNotEmpty) {
        // Summary has arrived — update state and tear down.
        if (mounted) {
          setState(() {
            // Only update if still saved (user might have un-bookmarked)
            if (_savedStories.containsKey(title)) {
              _savedStories[title] = summary;
            }
          });
        }
        // Cancel and remove the listener — we no longer need it.
        _summaryListeners.remove(title)?.cancel();
      }
      // If summary is still null, do nothing — wait for next event.
    });

    _summaryListeners[title] = sub;
  }

  // ---------------------------------------------------------------------------
  // News refresh
  // ---------------------------------------------------------------------------
  Future<void> _refreshNews() async {
    setState(() => _isLoading = true);
    try {
      await _crawlerService.fetchAllSources();
      final articles = _crawlerService.localRepo.getArticles();
      final grouped = await _groupArticlesInBackground(articles);
      await _crawlerService.cache.save(grouped);

      if (mounted) {
        setState(() {
          _stories = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing news: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<NewsStory>> _groupArticlesInBackground(
    List<Article> articles,
  ) async {
    final articlesJson = articles.map((a) => a.toJson()).toList();
    final groupedJson = await compute(_groupArticlesIsolate, articlesJson);
    return groupedJson.map((json) => NewsStory.fromJson(json)).toList();
  }

  static List<Map<String, dynamic>> _groupArticlesIsolate(
    List<Map<String, dynamic>> articlesJson,
  ) {
    final articles =
        articlesJson.map((json) => Article.fromJson(json)).toList();
    final scoreService = ScoreService();
    final grouped = scoreService.groupArticlesIncremental([], articles);

    for (var story in grouped) {
      final seen = <String>{};
      story.articles.retainWhere((article) {
        final key =
            '${article.sourceName}::${article.title.trim().toLowerCase()}';
        if (seen.contains(key)) return false;
        seen.add(key);
        return true;
      });
    }
    grouped.removeWhere((story) => story.articles.isEmpty);
    return grouped.map((story) => story.toJson()).toList();
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
  // Filtering
  // ---------------------------------------------------------------------------
  List<NewsStory> _applyAllFilters(List<NewsStory> stories) {
    return stories.where((story) {
      final storySourceIds =
          story.articles.map((a) => a.sourceName.toLowerCase()).toSet();
      if (!storySourceIds.any((id) => selectedSources.contains(id)))
        return false;

      if (selectedCategories.isNotEmpty) {
        final allTypes = <String>{
          ...?story.storyTypes?.map((e) => e.toLowerCase().trim()),
          ...?story.inferredStoryTypes?.map((e) => e.toLowerCase().trim()),
        };
        if (allTypes.isEmpty || !selectedCategories.every(allTypes.contains))
          return false;
      }

      if (story.articles.map((a) => a.sourceName).toSet().length <
          minimumSources)
        return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.trimRight();
        return story.canonicalTitle.toLowerCase().contains(q) ||
            (story.summary?.toLowerCase().contains(q) ?? false);
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
                          selectedSources =
                              Globals.sourceConfigs.keys
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
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: stories.length,
        itemBuilder: (context, index) {
          final story = stories[index];
          final title = story.canonicalTitle;
          final isSaved = _savedStories.containsKey(title);

          return NewsStoryCard(
            story: story,
            isSaved: isSaved,
            // null if not saved, or if saved but summary hasn't arrived
            aiSummary: _savedStories[title],
            onBookmarkToggle: () => toggleBookmark(story),
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => GroupedNewsScreen(
                          story: story,
                          isSaved: isSaved,
                          aiSummary:
                              _savedStories[title] ?? "Loading",
                          onBookmarkToggle: () => toggleBookmark(story),
                        ),
                  ),
                ),
          );
        },
      ),
    );
  }
}
