import 'package:flutter/material.dart';
import '../globals.dart';

class FloatingSearchAndFilter extends StatefulWidget {
  final Set<String> selectedCategories;
  final int minimumSources;
  final Function(int) onMinimumSourcesChanged;
  final Function(String, bool) onCategoryToggled;
  final bool showSearchBar;
  final TextEditingController searchController;
  final String searchQuery;
  final Function(String) onSearchChanged;
  final VoidCallback onClearSearch;
  final FocusNode? searchFocusNode;

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
    this.searchFocusNode,
  });

  @override
  State<FloatingSearchAndFilter> createState() => _FloatingSearchAndFilterState();
}

class _FloatingSearchAndFilterState extends State<FloatingSearchAndFilter> {
  bool isFiltersExpanded = false;

  @override
  Widget build(BuildContext context) {
    final minSourcesOptions = [1, 2, 3, 4, 5];

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        offset: widget.showSearchBar ? Offset.zero : const Offset(0, 1),
        child: Container(
          margin: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Filters section (expandable)
              Container(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: isFiltersExpanded
                      ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with close button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Filters',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() => isFiltersExpanded = false);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Category label
                        Text(
                          'Categories',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Story type chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: Globals.storyTypeKeywords.keys.map((category) {
                              final isSelected = widget.selectedCategories.contains(category);
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: FilterChip(
                                  label: Text(category),
                                  selected: isSelected,
                                  backgroundColor: Colors.grey.withValues(alpha: 0.3),
                                  // selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                  // checkmarkColor: Theme.of(context).primaryColor,
                                  onSelected: (selected) {
                                    widget.onCategoryToggled(category, selected);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Minimum sources label
                        Text(
                          'Minimum Sources',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Minimum sources chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: minSourcesOptions.map((value) {
                              final isSelected = widget.minimumSources == value;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text('$value+ sources'),
                                  selected: isSelected,
                                  // selectedColor: Theme.of(context).primaryColor,
                                  backgroundColor: Colors.grey.withValues(alpha: 0.3),
                                  // labelStyle: TextStyle(
                                  //   color: isSelected ? Colors.white : Colors.black87,
                                  // ),
                                  onSelected: (_) {
                                    widget.onMinimumSourcesChanged(value);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  )
                      : const SizedBox.shrink(),
                ),
              ),

              // Search bar
              Container(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                child: TextField(
                  controller: widget.searchController,
                  focusNode: widget.searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: IconButton(
                      icon: Icon(
                        isFiltersExpanded ? Icons.filter_alt : Icons.filter_alt_outlined,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() => isFiltersExpanded = !isFiltersExpanded);
                        // Unfocus search when opening filters
                        if (!isFiltersExpanded) {
                          widget.searchFocusNode?.unfocus();
                        }
                      },
                    ),
                    suffixIcon: widget.searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: widget.onClearSearch,
                    )
                        : null,
                    filled: true,
                    // fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: widget.onSearchChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}