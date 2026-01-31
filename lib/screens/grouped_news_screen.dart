import 'dart:async';

import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../models/news_story_model.dart';
import '../services/firebase_save_service.dart';

class GroupedNewsScreen extends StatefulWidget {
  final NewsStory story;
  final bool isSaved;
  final String? aiSummary;
  final VoidCallback onBookmarkToggle;

  const GroupedNewsScreen({
    super.key,
    required this.story,
    required this.isSaved,
    required this.onBookmarkToggle,
    this.aiSummary,
  });

  @override
  State<GroupedNewsScreen> createState() => _GroupedNewsScreenState();
}

class _GroupedNewsScreenState extends State<GroupedNewsScreen>
    with SingleTickerProviderStateMixin {
  late bool _isSaved;
  late String? _aiSummary;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  final FirebaseSaveService _firebaseSaveService = FirebaseSaveService();
  StreamSubscription<Map<String, dynamic>?>? _summaryListener;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.isSaved;
    _aiSummary = widget.aiSummary;

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _startAppropriateAnimation();
  }

  @override
  void didUpdateWidget(covariant GroupedNewsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Parent re-pushed or updated props (e.g. after bookmark toggle)
    if (oldWidget.isSaved != widget.isSaved) {
      setState(() => _isSaved = widget.isSaved);
    }

    // The aiSummary arrived from the parent while this screen is open
    if (oldWidget.aiSummary != widget.aiSummary) {
      setState(() {
        _aiSummary = widget.aiSummary;
        _startAppropriateAnimation();
      });
    }
  }

  /// If summary is pending → repeat (loading pulse).
  /// If summary exists   → forward once (single shimmer sweep, then stop).
  void _startAppropriateAnimation() {
    _shimmerController.stop();
    if (_isSaved && _aiSummary == null) {
      _shimmerController.repeat();
    } else {
      _shimmerController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _summaryListener?.cancel();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final articles = widget.story.articles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coverage'),
        actions: [
          IconButton(
            icon: Icon(
              _isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: _isSaved ? Colors.green[400] : Colors.white70,
            ),
            onPressed: () {
              widget.onBookmarkToggle();
              setState(() {
                _isSaved = !_isSaved;

                if (!_isSaved) {
                  // Un-bookmarked — tear everything down.
                  _aiSummary = null;
                  _summaryListener?.cancel();
                  _summaryListener = null;
                  _shimmerController.stop();
                } else {
                  // Just bookmarked — summary is pending, start pulsing.
                  _startAppropriateAnimation();

                  // Open a one-shot listener so this screen picks up the
                  // summary directly from Firestore when it lands.
                  _summaryListener =
                      _firebaseSaveService
                          .watchStory(widget.story.canonicalTitle)
                          .listen((data) {
                        final summary = data?['aiSummary'] as String?;
                        if (summary != null && summary.isNotEmpty) {
                          if (mounted) {
                            setState(() {
                              _aiSummary = summary;
                              _startAppropriateAnimation();
                            });
                          }
                          // Summary arrived — cancel and clean up.
                          _summaryListener?.cancel();
                          _summaryListener = null;
                        }
                      });
                }
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Hero image ---
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

          // --- Title ---
          Text(
            widget.story.canonicalTitle,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // --- Original summary ---
          if (widget.story.summary != null) ...[
            Text(
              widget.story.summary!,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
          ],

          // --- AI Summary card ---
          // Only show if the story is bookmarked.
          if (_isSaved) ...[
            // Summary is pending — show a pulsing skeleton placeholder.
            // Summary has arrived — show the real text.
            // _buildAiSummaryCard handles both via the nullable summary param.
            _buildAiSummaryCard(context, _aiSummary),
            const SizedBox(height: 24),
          ],

          // --- Sources header ---
          const Text(
            'Detailed Sources',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),

          // --- Article list ---
          ...articles.map((article) {
            return ListTile(
              contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              title: Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  article.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
              subtitle: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(
                      'assets/images/${article.sourceName.toLowerCase()}.png',
                      width: 16,
                      height: 16,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.public,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    article.sourceName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: Text("•", style: TextStyle(color: Colors.grey[600])),
                  ),
                  Text(
                    timeago.format(article.publishedAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              trailing: Icon(
                Icons.open_in_new,
                size: 14,
                color: Colors.grey[700],
              ),
              onTap: () async {
                final uri = Uri.parse(article.url);
                if (!await launchUrl(uri)) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open the link')),
                    );
                  }
                }
              },
            );
          }),
        ],
      ),
    );
  }

  /// Builds the AI summary card with an animated shimmer border and a
  /// dark gradient background to visually distinguish it from regular content.
  /// If [summary] is null, a skeleton placeholder is shown instead.
  Widget _buildAiSummaryCard(BuildContext context, String? summary) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: _AiCardBorderPainter(progress: _shimmerAnimation.value),
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1025),
              Color(0xFF12101F),
              Color(0xFF1A1530),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label row: icon + "AI Summary" / "Generating..."
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: Colors.purpleAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    summary != null ? 'AI Summary' : 'Generating summary...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: summary != null
                          ? Colors.purpleAccent
                          : Colors.purpleAccent.withValues(alpha: 0.6),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Thin separator that fades out to the right
              Container(
                height: 1,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0x60A020FF),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Either the real summary or a skeleton
              if (summary != null)
                Text(
                  summary,
                  style: const TextStyle(
                    color: Color(0xDDDDDDDD),
                    fontSize: 14,
                    height: 1.6,
                  ),
                )
              else
                _buildSkeleton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Three grey rounded bars that mimic lines of text while the summary
  /// is still generating. Widths are staggered so it looks natural.
  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _skeletonLine(double.infinity),
        const SizedBox(height: 10),
        _skeletonLine(double.infinity),
        const SizedBox(height: 10),
        _skeletonLine(0.6), // last line shorter — like a real paragraph end
      ],
    );
  }

  /// A single skeleton line. [widthFraction] is relative to the parent width;
  /// use [double.infinity] to fill the full width.
  Widget _skeletonLine(double widthFraction) {
    return Container(
      height: 14,
      width: widthFraction == double.infinity ? double.infinity : null,
      constraints: widthFraction != double.infinity
          ? BoxConstraints(maxWidth: 240 * widthFraction)
          : null,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Paints the animated shimmer border around the AI summary card.
/// A bright highlight travels around the rounded-rect perimeter continuously.
class _AiCardBorderPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0, driven by the AnimationController

  _AiCardBorderPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));

    // 1. Static base border — subtle dark purple so the card has definition
    //    even when the shimmer highlight is on the opposite side.
    final basePaint = Paint()
      ..color = const Color(0x40A020FF) // purpleAccent @ 25%
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rrect, basePaint);

    // 2. Animated shimmer: clip to the border path, then draw a large
    //    gradient that moves based on `progress`.
    canvas.save();
    canvas.clipRRect(rrect.inflate(1)); // slight inflate so stroke fits inside clip
    canvas.clipRRect(rrect.deflate(0.5), doAntiAlias: false); // hollow out the inside

    // The gradient moves horizontally; progress shifts it from off-left to off-right.
    final gradientRect = Rect.fromLTWH(
      (progress - 0.5) * size.width * 2 - size.width * 0.3,
      0,
      size.width * 0.6,
      size.height,
    );

    final shimmerPaint = Paint()
      ..shader = LinearGradient(
        colors: const [
          Colors.transparent,
          Color(0x00A020FF),
          Color(0xFFD0A0FF), // bright highlight peak
          Color(0xFFA020FF), // purpleAccent
          Color(0x00A020FF),
          Colors.transparent,
        ],
      ).createShader(gradientRect);

    canvas.drawRect(
      Rect.fromLTWH(-2, -2, size.width + 4, size.height + 4),
      shimmerPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AiCardBorderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}