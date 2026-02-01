import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../globals.dart';

class FloatingSearchAndFilter extends StatefulWidget {
  // ... (Props stay the same)
  final Set<String> selectedCategories;
  final int minimumSources;
  final Set<String> selectedSources;
  final Function(String, bool) onSourceToggled;
  final Function(int) onMinimumSourcesChanged;
  final Function(String, bool) onCategoryToggled;
  final bool showSearchBar;
  final TextEditingController searchController;
  final String searchQuery;
  final Function(String) onSearchChanged;
  final VoidCallback onClearSearch;
  final FocusNode? searchFocusNode;
  final bool showSavedOnly;
  final Function(bool) onSavedOnlyToggled;

  const FloatingSearchAndFilter({
    super.key,
    required this.selectedCategories,
    required this.minimumSources,
    required this.onMinimumSourcesChanged,
    required this.onCategoryToggled,
    required this.showSearchBar,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.selectedSources,
    required this.onSourceToggled,
    this.searchFocusNode,
    required this.showSavedOnly,
    required this.onSavedOnlyToggled,
  });

  @override
  State<FloatingSearchAndFilter> createState() => _FloatingSearchAndFilterState();
}

class _FloatingSearchAndFilterState extends State<FloatingSearchAndFilter> {
  bool isFiltersExpanded = false;

  // Unified Color Palette
  static const Color primaryPurple = Color(0xFFA78BFA); // Muted Lavender
  static const Color surfaceWhite = Colors.white10;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        offset: widget.showSearchBar ? Offset.zero : const Offset(0, 1.2),
        child: Container(
          margin: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6), // Slightly darker for contrast
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: isFiltersExpanded ? _buildExpandedFilters() : const SizedBox.shrink(),
                    ),
                    _buildSearchBar(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- REFINED SECTIONS ---

  Widget _buildExpandedFilters() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSavedToggle(),
          const Divider(color: Colors.white10, height: 32),
          _buildSectionHeader('CATEGORIES'),
          const SizedBox(height: 12),
          _buildCategoryChips(),
          const SizedBox(height: 24),
          _buildSectionHeader('MINIMUM SOURCES'),
          const SizedBox(height: 12),
          _buildMinSourcesCount(),
          const SizedBox(height: 24),
          _buildSectionHeader('NEWS SOURCES'),
          const SizedBox(height: 12),
          _buildSources(),
        ],
      ),
    );
  }

  Widget _buildSavedToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Show Bookmarked Only',
          style: GoogleFonts.lexend(color: Colors.white.withOpacity(0.9), fontSize: 14),
        ),
        Switch.adaptive(
          value: widget.showSavedOnly,
          activeColor: primaryPurple, // SYNCED COLOR
          onChanged: widget.onSavedOnlyToggled,
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: Globals.storyTypeKeywords.keys.map((category) {
          final normalized = category.toLowerCase().trim();
          final isSelected = widget.selectedCategories.contains(normalized);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) => widget.onCategoryToggled(normalized, selected),
              // SYNCED COLOR: Lower opacity for the background
              selectedColor: primaryPurple.withOpacity(0.15),
              backgroundColor: surfaceWhite,
              labelStyle: GoogleFonts.lexend(
                color: isSelected ? primaryPurple : Colors.white60,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(
                color: isSelected ? primaryPurple.withOpacity(0.5) : Colors.transparent,
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMinSourcesCount() {
    return Container(
      width: double.infinity,
      // This is the outer container
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        // This creates the "gutter" so the highlight doesn't touch the edges
        padding: const EdgeInsets.all(4.0),
        child: SegmentedButton<int>(
          style: SegmentedButton.styleFrom(
            backgroundColor: Colors.transparent,
            selectedBackgroundColor: primaryPurple.withOpacity(0.2),
            selectedForegroundColor: primaryPurple,
            foregroundColor: Colors.white38,
            // Fixed the rectangular shape as we discussed
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            side: BorderSide.none,
            // Reducing visual density brings the text and highlight closer
            visualDensity: VisualDensity.compact,
            textStyle: GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          segments: const [
            ButtonSegment(value: 1, label: Text('All')),
            ButtonSegment(value: 2, label: Text('2+')),
            ButtonSegment(value: 3, label: Text('3+')),
            ButtonSegment(value: 5, label: Text('5+')),
          ],
          selected: {widget.minimumSources},
          onSelectionChanged: (set) => widget.onMinimumSourcesChanged(set.first),
          showSelectedIcon: false,
        ),
      ),
    );
  }

  Widget _buildSources() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: Globals.sourceConfigs.keys.map((sourceName) {
          final sourceId = sourceName.toLowerCase();
          final isSelected = widget.selectedSources.contains(sourceId);
          final imageName = sourceId.replaceAll('.ro', '').replaceAll('.net', '');

          return SizedBox(
            width: 70, // FIXED WIDTH to prevent gaps and force ellipsis
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => widget.onSourceToggled(sourceId, !isSelected),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? primaryPurple : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Opacity(
                      opacity: isSelected ? 1.0 : 0.4,
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white,
                        backgroundImage: AssetImage('assets/images/$imageName.png'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  sourceName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis, // FORCES ...
                  style: GoogleFonts.lexend(
                    fontSize: 10,
                    color: isSelected ? Colors.white : Colors.white30,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ... (buildSearchBar and buildSectionHeader methods stay largely the same but use primaryPurple)
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(() => isFiltersExpanded = !isFiltersExpanded),
            icon: Icon(
              isFiltersExpanded ? Icons.expand_more : Icons.tune,
              color: isFiltersExpanded ? primaryPurple : Colors.white70,
            ),
          ),
          Expanded(
            child: TextField(
              controller: widget.searchController,
              focusNode: widget.searchFocusNode,
              style: GoogleFonts.lexend(color: Colors.white, fontSize: 14),
              onChanged: widget.onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: GoogleFonts.lexend(color: Colors.white24, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.lexend(
        color: Colors.white24,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    );
  }
}