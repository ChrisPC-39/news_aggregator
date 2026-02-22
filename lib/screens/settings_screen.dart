import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/similarity_settings_service.dart';
import 'news_story_screen.dart';

class SettingsScreen extends StatefulWidget {
  final bool isPremium;
  final bool isAdmin;

  const SettingsScreen({
    super.key,
    required this.isPremium,
    required this.isAdmin,
  });

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsService = SimilaritySettingsService();
  late double _currentThreshold;

  @override
  void initState() {
    super.initState();
    _currentThreshold = _settingsService.getThreshold();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Grouping Sensitivity',
          style: GoogleFonts.lexend(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: const BackButton(color: Colors.white),
      ),
      body: Stack(
        children: [
          // 1. Background with Dark Overlay
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),

          // 2. Content
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: _buildGlassCard(),
                  ),
                ),

                // 3. Bottom Action Button
                _buildApplyButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Percent
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Similarity Threshold',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  Text(
                    '${(_currentThreshold * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.lexend(
                      color: const Color(0xFFA78BFA),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Explanation Text
              Text(
                'Lower % = Aggressive grouping (loose).\nHigher % = Precise grouping (strict).',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 40),

              // The Styled Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF8B5CF6),
                  inactiveTrackColor: Colors.white10,
                  thumbColor: Colors.white,
                  overlayColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  valueIndicatorColor: const Color(0xFF6D28D9),
                  valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 12,
                  ),
                ),
                child: Slider(
                  value: _currentThreshold,
                  min: 0.1,
                  max: 0.5,
                  divisions: 40,
                  label: '${(_currentThreshold * 100).toStringAsFixed(0)}%',
                  onChanged: (value) {
                    setState(() => _currentThreshold = value);
                  },
                ),
              ),

              const SizedBox(height: 30),

              // Reset Button
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    setState(() => _currentThreshold = 0.25);
                  },
                  icon: const Icon(
                    Icons.refresh,
                    size: 18,
                    color: Colors.white60,
                  ),
                  label: const Text(
                    'Reset to Default (25%)',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplyButton() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: () async {
            await _settingsService.setThreshold(_currentThreshold);
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => NewsStoryScreen(
                        isPremium: widget.isPremium,
                        isAdmin: widget.isAdmin,
                      ),
                ),
              );
            }
          },
          child: Text(
            'Apply Changes',
            style: GoogleFonts.lexend(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
