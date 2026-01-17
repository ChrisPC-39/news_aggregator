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
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children:
                                        minSourcesOptions.map((value) {
                                          final isSelected =
                                              widget.minimumSources == value;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8.0,
                                            ),
                                            child: ChoiceChip(
                                              label: Text('$value+ sources'),
                                              shape: StadiumBorder(),
                                              selected: isSelected,
                                              backgroundColor: Colors.grey
                                                  .withValues(alpha: 0.3),
                                              onSelected: (_) {
                                                widget.onMinimumSourcesChanged(
                                                  value,
                                                );
                                              },
                                            ),
                                          );
                                        }).toList(),
                                  ),
                                ),

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

                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children:
                                        Globals.allSources.map((sourceName) {
                                          // Inside Globals.allSources.map(...)
                                          final sourceId =
                                              sourceName.toLowerCase();
                                          final isSelected = widget
                                              .selectedSources
                                              .contains(sourceId);

                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              right: 16.0,
                                            ),
                                            child: GestureDetector(
                                              onTap:
                                                  () => widget.onSourceToggled(
                                                    sourceId,
                                                    !isSelected,
                                                  ),
                                              child: Column(
                                                children: [
                                                  AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 200,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.all(3),
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color:
                                                            isSelected
                                                                ? Colors
                                                                    .deepPurpleAccent
                                                                : Colors
                                                                    .transparent,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: ColorFiltered(
                                                      // Use a Saturation Matrix: 0 is grayscale, 1 is full color
                                                      colorFilter:
                                                          isSelected
                                                              ? const ColorFilter.mode(
                                                                Colors
                                                                    .transparent,
                                                                BlendMode
                                                                    .multiply,
                                                              )
                                                              : const ColorFilter.matrix(
                                                                <double>[
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
                                                                ],
                                                              ),
                                                      child: CircleAvatar(
                                                        radius: 20,
                                                        backgroundColor:
                                                            Colors.white,
                                                        backgroundImage: AssetImage(
                                                          'assets/images/$sourceId.png',
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    sourceName,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color:
                                                          isSelected
                                                              ? Colors.white
                                                              : Colors.grey,
                                                      fontWeight:
                                                          isSelected
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                  .normal,
                                                    ),
                                                  ),
                                                ],
                                              ),
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
}
