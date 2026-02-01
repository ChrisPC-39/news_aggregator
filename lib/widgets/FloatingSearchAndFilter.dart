import 'package:flutter/material.dart';
import '../globals.dart';

class FloatingSearchAndFilter extends StatefulWidget {
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
    this.searchFocusNode, required this.showSavedOnly, required this.onSavedOnlyToggled,
  });

  @override
  State<FloatingSearchAndFilter> createState() =>
      _FloatingSearchAndFilterState();
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
                  child:
                      isFiltersExpanded
                          ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Show Bookmarked Only',
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Switch(
                                      value: widget.showSavedOnly,
                                      activeColor: Colors.amber, // Matches the bookmark icon color
                                      onChanged: (value) => widget.onSavedOnlyToggled(value),
                                    ),
                                  ],
                                ),
                                const Divider(color: Colors.white10, height: 24),
                                // Category label
                                Text(
                                  'Categories',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Story type chips
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children:
                                        Globals.storyTypeKeywords.keys.map((
                                          category,
                                        ) {
                                          final normalized =
                                              category.toLowerCase().trim();
                                          final isSelected = widget
                                              .selectedCategories
                                              .contains(normalized);
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8.0,
                                            ),
                                            child: FilterChip(
                                              label: Text(category),
                                              selected: isSelected,
                                              backgroundColor: Colors.grey
                                                  .withValues(alpha: 0.3),
                                              onSelected: (selected) {
                                                widget.onCategoryToggled(
                                                  normalized,
                                                  selected,
                                                );
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
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Minimum sources chips
                                _buildMinSourcesCount(),

                                const SizedBox(height: 16),

                                Text(
                                  'News Sources',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                _buildSources(),
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
                        isFiltersExpanded
                            ? Icons.filter_alt
                            : Icons.filter_alt_outlined,
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
                    suffixIcon:
                        widget.searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: widget.onClearSearch,
                            )
                            : null,
                    filled: true,
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

  Widget _buildMinSourcesCount() {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 1, label: Text('All')),
        ButtonSegment(value: 2, label: Text('2+')),
        ButtonSegment(value: 3, label: Text('3+')),
        ButtonSegment(value: 5, label: Text('5+')),
        ButtonSegment(value: 7, label: Text('7+')),
        ButtonSegment(value: 9, label: Text('9+')),
      ],
      selected: {widget.minimumSources},
      onSelectionChanged: (Set<int> newSelection) {
        widget.onMinimumSourcesChanged(newSelection.first);
      },
      showSelectedIcon: false,
    );
  }

  Widget _buildSources() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            Globals.sourceConfigs.keys.map((sourceName) {
              // Inside Globals.allSources.map(...)
              final sourceId = sourceName.toLowerCase();
              final isSelected = widget.selectedSources.contains(sourceId);
              final imageName = sourceId.replaceAll('.ro', '').replaceAll('.net', '');

              return SizedBox(
                width: 65,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: GestureDetector(
                    onTap: () => widget.onSourceToggled(sourceId, !isSelected),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  isSelected
                                      ? Colors.deepPurpleAccent
                                      : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ColorFiltered(
                            // Use a Saturation Matrix: 0 is grayscale, 1 is full color
                            colorFilter:
                                isSelected
                                    ? const ColorFilter.mode(
                                      Colors.transparent,
                                      BlendMode.multiply,
                                    )
                                    : const ColorFilter.matrix(<double>[
                                      0.2126,
                                      0.7152,
                                      0.0722,
                                      0,
                                      0,
                                      0.2126,
                                      0.7152,
                                      0.0722,
                                      0,
                                      0,
                                      0.2126,
                                      0.7152,
                                      0.0722,
                                      0,
                                      0,
                                      0,
                                      0,
                                      0,
                                      1,
                                      0,
                                    ]),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white,
                              backgroundImage: AssetImage(
                                'assets/images/$imageName.png',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sourceName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.white : Colors.grey,
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}
