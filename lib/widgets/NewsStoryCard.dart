import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final NewsStory story;
  final bool isSaved;
  final String? aiSummary;
  final VoidCallback onBookmarkToggle;
  final VoidCallback onTap;
  final bool isPremium;

  const NewsStoryCard({
    super.key,
    required this.story,
    required this.isSaved,

    /// Null = summary not yet generated (or story not saved).
    /// Non-null = summary has arrived.
    this.aiSummary,
    required this.onBookmarkToggle,
    required this.onTap,
    required this.isPremium,
  });

  @override
  State<NewsStoryCard> createState() => _NewsStoryCardState();
}

class _NewsStoryCardState extends State<NewsStoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _borderOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _borderOpacityAnimation = Tween<double>(
      begin: 0.1,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _syncAnimationState();
  }

  @override
  void didUpdateWidget(covariant NewsStoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-evaluate whenever saved state, summary, or premium status changes.
    if (oldWidget.isSaved != widget.isSaved ||
        oldWidget.aiSummary != widget.aiSummary ||
        oldWidget.isPremium != widget.isPremium) {
      _syncAnimationState();
    }
  }

  /// Start or stop the animation based on current border state.
  void _syncAnimationState() {
    if (_currentBorderState == _BorderState.pending) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  _BorderState get _currentBorderState {
    // 1. If not saved, there is no special state.
    if (!widget.isSaved) return _BorderState.none;

    // 2. If summary is already here, show the 'ready' state regardless of premium status.
    if (widget.aiSummary != null && widget.aiSummary!.isNotEmpty) {
      return _BorderState.ready;
    }

    // 3. If saved but no summary:
    // Only show 'pending' (the animation) if the user is premium.
    // Otherwise, treat it as 'none' so no animation plays for free users.
    if (widget.isPremium) {
      return _BorderState.pending;
    } else {
      return _BorderState.none;
    }
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

    return _buildWithBorder(
      context,
      uniqueSources,
      manualTypes,
      aiTypes,
      dateDisplay,
    );
  }

  Widget _buildImageHeader(
      NewsStory story,
      List<String> manualTypes,
      List<String> aiTypes,
      ) {
    return SizedBox(
      width: double.infinity,
      height: story.imageUrl != null && story.imageUrl!.isNotEmpty ? 180 : 40,
      child: Stack(
        children: [
          if (story.imageUrl != null && story.imageUrl!.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                story.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.white10),
              ),
            ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          if (manualTypes.isNotEmpty || aiTypes.isNotEmpty)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
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
    );
  }

  Widget _buildFooter(List<String> uniqueSources, String dateDisplay) {
    return Row(
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
                    backgroundColor: Colors.white10,
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
            style: GoogleFonts.lexend(color: Colors.white38, fontSize: 11),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          icon: Icon(
            widget.isSaved ? Icons.bookmark : Icons.bookmark_border,
            color: widget.isSaved ? const Color(0xFFA78BFA) : Colors.white30,
            size: 22,
          ),
          onPressed: widget.onBookmarkToggle,
        ),
      ],
    );
  }

  Widget _buildWithBorder(
      BuildContext context,
      List<String> uniqueSources,
      List<String> manualTypes,
      List<String> aiTypes,
      String dateDisplay,
      ) {
    switch (_currentBorderState) {
      case _BorderState.pending:
        return AnimatedBuilder(
          animation: _borderOpacityAnimation,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.purpleAccent.withValues(
                    alpha: _borderOpacityAnimation.value,
                  ),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purpleAccent.withValues(
                      alpha: _borderOpacityAnimation.value * 0.3,
                    ),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: _cardBody(
            context,
            uniqueSources,
            manualTypes,
            aiTypes,
            dateDisplay,
          ),
        );

      case _BorderState.ready:
      case _BorderState.none:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _cardBody(
            context,
            uniqueSources,
            manualTypes,
            aiTypes,
            dateDisplay,
          ),
        );
    }
  }

  Widget _cardBody(
      BuildContext context,
      List<String> uniqueSources,
      List<String> manualTypes,
      List<String> aiTypes,
      String dateDisplay,
      ) {
    final story = widget.story;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white10,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: widget.onTap,
          child: Column(
            children: [
              _buildImageHeader(story, manualTypes, aiTypes),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.canonicalTitle,
                      style: GoogleFonts.lexend(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    if (_currentBorderState == _BorderState.ready)
                      _buildAISummaryBadge(),
                    if (story.summary != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        story.summary!,
                        maxLines: 2,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildFooter(uniqueSources, dateDisplay),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAISummaryBadge() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 12, color: Color(0xFFA78BFA)),
          const SizedBox(width: 4),
          Text(
            'AI Summary Ready',
            style: GoogleFonts.lexend(
              color: const Color(0xFFA78BFA),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
            if (isAi)
              const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
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