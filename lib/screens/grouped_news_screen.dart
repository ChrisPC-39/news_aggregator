import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../models/article_model.dart';
import '../models/news_story_model.dart';
import '../services/firebase_save_service.dart';

class GroupedNewsScreen extends StatefulWidget {
  final NewsStory story;
  final bool isSaved;
  final bool isPremium;
  final String? aiSummary;
  final VoidCallback onBookmarkToggle;

  const GroupedNewsScreen({
    super.key,
    required this.story,
    required this.isSaved,
    required this.isPremium,
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
      duration: const Duration(seconds: 2),
    );

    _shimmerAnimation = Tween<double>(begin: 0.1, end: 0.8).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _startAppropriateAnimation();
  }

  /// If premium + saved + no summary yet → repeat (loading pulse).
  /// Otherwise → stop (either not saved, not premium, or summary already here).
  void _startAppropriateAnimation() {
    if (_isSaved && _aiSummary == null && widget.isPremium) {
      _shimmerController.repeat(reverse: true);
    } else {
      _shimmerController.stop();
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
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withValues(alpha: 0.2)),
          ),
        ),
        title: Text('Coverage', style: GoogleFonts.lexend(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(
              _isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: _isSaved ? const Color(0xFFA78BFA) : Colors.white70,
            ),
            onPressed: _handleBookmarkToggle,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1521295121783-8a321d551ad2?auto=format&fit=crop&q=80&w=2070',
              fit: BoxFit.cover,
            ),
          ),

          // Blur overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
              ),
            ),
          ),

          // Content
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 120, 16, 40),
            children: [
              // --- Hero image ---
              if (widget.story.imageUrl != null)
                _buildHeroImage(),

              const SizedBox(height: 24),

              // --- Title ---
              Text(
                widget.story.canonicalTitle,
                style: GoogleFonts.lexend(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              // --- Original summary ---
              if (widget.story.summary != null)
                Text(
                  widget.story.summary!,
                  style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                ),

              const SizedBox(height: 32),

              // --- AI Summary card ---
              // Only visible if saved AND the user is premium.
              if (_isSaved && widget.isPremium) ...[
                _buildAiSummaryCard(context, _aiSummary),
                const SizedBox(height: 32),
              ],

              // --- Sources header ---
              Row(
                children: [
                  const Icon(Icons.article_outlined, color: Colors.white54, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'DETAILED SOURCES',
                    style: GoogleFonts.lexend(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white54,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 32),

              // --- Article list ---
              ...articles.map((article) => _buildSourceTile(context, article)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImage() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          widget.story.imageUrl!,
          height: 240,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  void _handleBookmarkToggle() {
    widget.onBookmarkToggle();
    setState(() {
      _isSaved = !_isSaved;

      if (!_isSaved) {
        // Un-bookmarked — tear everything down.
        _aiSummary = null;
        _summaryListener?.cancel();
        _summaryListener = null;
        _shimmerController.stop();
      } else if (widget.isPremium) {
        // Just bookmarked and user is premium — summary is pending.
        // Start pulsing and open a one-shot listener for the summary.
        _startAppropriateAnimation();

        _summaryListener = _firebaseSaveService
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
      // else: just bookmarked but not premium — nothing extra to do.
    });
  }

  Widget _buildAiSummaryCard(BuildContext context, String? summary) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: summary == null
                  ? Colors.purpleAccent.withValues(alpha: _shimmerAnimation.value)
                  : Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
            color: Colors.white.withValues(alpha: 0.05),
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 18, color: Color(0xFFA78BFA)),
                const SizedBox(width: 10),
                Text(
                  summary != null ? 'AI INSIGHT' : 'GENERATING SUMMARY...',
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFA78BFA),
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (summary != null)
              Text(
                summary,
                style: GoogleFonts.lexend(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 15,
                  height: 1.6,
                ),
              )
            else
              _buildSkeleton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceTile(BuildContext context, Article article) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          hoverColor: Colors.white.withValues(alpha: 0.05),
          splashColor: const Color(0xFFA78BFA).withValues(alpha: 0.1),
          focusColor: const Color(0xFFA78BFA).withValues(alpha: 0.05),

          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          title: Text(
            article.title,
            style: GoogleFonts.lexend(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.white10,
                  backgroundImage: AssetImage(
                      'assets/images/${article.sourceName.toLowerCase().replaceAll('.ro', '').replaceAll('.net', '')}.png'
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  article.sourceName,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white38,
                      fontWeight: FontWeight.bold
                  ),
                ),
                const Text("  •  ", style: TextStyle(color: Colors.white24)),
                Text(
                  timeago.format(article.publishedAt),
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),
          trailing: const Icon(Icons.open_in_new, size: 14, color: Colors.white24),
          onTap: () async {
            final uri = Uri.parse(article.url);
            if (!await launchUrl(uri)) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open link'))
                );
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _skeletonLine(double.infinity),
        const SizedBox(height: 10),
        _skeletonLine(double.infinity),
        const SizedBox(height: 10),
        _skeletonLine(0.6),
      ],
    );
  }

  Widget _skeletonLine(double widthFraction) {
    return Container(
      height: 14,
      width: widthFraction == double.infinity ? double.infinity : null,
      constraints: widthFraction != double.infinity ? BoxConstraints(maxWidth: 240 * widthFraction) : null,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}