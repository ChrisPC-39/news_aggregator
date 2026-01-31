import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/news_story_model.dart';

/// The three states a saved story's border can be in.
enum _BorderState {
  /// Story is not bookmarked — no border at all.
  none,

  /// Story is bookmarked but the AI summary hasn't arrived yet — animate.
  pending,

  /// Summary is present — show a quiet static border.
  ready,
}

class NewsStoryCard extends StatefulWidget {
  const NewsStoryCard({
    super.key,
    required this.story,
    required this.isSaved,

    /// Null = summary not yet generated (or story not saved).
    /// Non-null = summary has arrived.
    this.aiSummary,
    required this.onBookmarkToggle,
    required this.onTap,
  });

  final NewsStory story;
  final bool isSaved;
  final String? aiSummary;
  final VoidCallback onBookmarkToggle;
  final VoidCallback onTap;

  @override
  State<NewsStoryCard> createState() => _NewsStoryCardState();
}

class _NewsStoryCardState extends State<NewsStoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _colorAnimation = ColorTween(
      begin: Colors.purpleAccent.withValues(alpha: 0.2),
      end: Colors.purpleAccent,
    ).animate(_controller);

    _syncAnimationState();
  }

  @override
  void didUpdateWidget(covariant NewsStoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-evaluate whenever saved state or summary changes.
    if (oldWidget.isSaved != widget.isSaved ||
        oldWidget.aiSummary != widget.aiSummary) {
      _syncAnimationState();
    }
  }

  /// Start or stop the animation based on current border state.
  void _syncAnimationState() {
    switch (_currentBorderState) {
      case _BorderState.pending:
        _controller.repeat(reverse: true);
      case _BorderState.none:
      case _BorderState.ready:
        _controller.stop();
    }
  }

  _BorderState get _currentBorderState {
    if (!widget.isSaved) return _BorderState.none;
    if (widget.aiSummary != null && widget.aiSummary!.isNotEmpty)
      return _BorderState.ready;
    return _BorderState.pending;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    final articles = story.articles;
    final manualTypes = story.storyTypes ?? [];
    final aiTypes = story.inferredStoryTypes ?? [];
    final uniqueSources = articles.map((a) => a.sourceName).toSet().toList();

    // Date range
    final dates = articles.map((a) => a.publishedAt).toList()..sort();
    final String dateDisplay;
    if (dates.isEmpty) {
      dateDisplay = "No date";
    } else {
      final first = dates.first;
      final last = dates.last;
      dateDisplay =
      DateFormat('yyyyMMdd').format(first) ==
          DateFormat('yyyyMMdd').format(last)
          ? timeago.format(last)
          : "${DateFormat('MMM d').format(first)} - ${DateFormat('MMM d').format(last)}";
    }

    return _buildWithBorder(context, uniqueSources, manualTypes, aiTypes, dateDisplay);
  }

  Widget _buildWithBorder(
      BuildContext context,
      List<String> uniqueSources,
      List<String> manualTypes,
      List<String> aiTypes,
      String dateDisplay,
      ) {
    final card = _cardBody(context, uniqueSources, manualTypes, aiTypes, dateDisplay);

    // Pending: wrap in AnimatedBuilder so the border color updates each frame.
    // All other states: static transparent border — same width, no layout shift.
    if (_currentBorderState == _BorderState.pending) {
      return AnimatedBuilder(
        animation: _colorAnimation,
        builder: (context, child) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _colorAnimation.value ?? Colors.purpleAccent,
                width: 2.5,
              ),
            ),
            child: child,
          );
        },
        child: card,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.transparent,
          width: 2.5,
        ),
      ),
      child: card,
    );
  }

  /// The Card itself — shared across all three border states.
  /// No margin here; the parent (_buildWithBorder) handles spacing.
  Widget _cardBody(
      BuildContext context,
      List<String> uniqueSources,
      List<String> manualTypes,
      List<String> aiTypes,
      String dateDisplay,
      ) {
    final story = widget.story;
    final articles = story.articles;

    return Card(
      margin: EdgeInsets.zero, // margin is on the outer Container
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Image + Tags ---
            SizedBox(
              width: double.infinity,
              height:
              story.imageUrl != null && story.imageUrl!.isNotEmpty ? 200 : 35,
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
                          ...manualTypes.map((t) => _buildTagChip(t, isAi: false)),
                          ...aiTypes.map((t) => _buildTagChip(t, isAi: true)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // --- Content ---
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

                  // AI summary badge — only shown when ready
                  if (_currentBorderState == _BorderState.ready)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.auto_awesome, size: 13, color: Colors.purpleAccent),
                            SizedBox(width: 6),
                            Text(
                              'AI Summary available',
                              style: TextStyle(
                                color: Colors.purpleAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Original summary
                  if (story.summary != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      story.summary!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // --- Footer: sources + date + bookmark ---
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
                                  border: Border.all(color: Colors.black, width: 2),
                                ),
                                child: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.grey[900],
                                  backgroundImage: AssetImage(
                                    'assets/images/${uniqueSources[index].toLowerCase().replaceAll('.ro', '').replaceAll('.net', '')}.png',
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
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          widget.isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: widget.isSaved ? Colors.green[400] : Colors.white70,
                          size: 20,
                        ),
                        onPressed: widget.onBookmarkToggle,
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
          color:
          isAi
              ? Colors.deepPurple.withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isAi ? Colors.deepPurple : Colors.white24,
            width: 1,
          ),
          boxShadow:
          isAi
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
            if (isAi) const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
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