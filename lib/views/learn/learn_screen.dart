import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/learn_models.dart';
import '../../services/learn_service.dart';
import '../../shared/widgets/expandable_info_card.dart';

/// Main Learn screen with educational content tabs
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LearnService _learnService = LearnService.instance;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Content state
  LearnContent? _learnContent;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Load learn content from service
  Future<void> _loadContent() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final content = await _learnService.loadLearnContent();

      if (mounted) {
        setState(() {
          _learnContent = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load educational content: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Handle search query changes
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
    });
  }

  /// Clear search
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header with SafeArea
          Container(
            color: AppColors.primary,
            child: SafeArea(
              child: _buildHeader(),
            ),
          ),

          // Tab toggle
          _buildTabToggle(),

          // Search bar (only for educational tab)
          if (_tabController.index == 0) _buildSearchBar(),

          // Content
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  /// Build header section
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Learn',
                  style: AppTextStyles.headline2.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Refresh button
              IconButton(
                onPressed: _isLoading ? null : _loadContent,
                icon: Icon(Icons.refresh, color: AppColors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Educational resources about allergens and safety',
            style: AppTextStyles.bodyText1.copyWith(
              color: AppColors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  /// Build tab toggle for Educational/Behavioral sections
  Widget _buildTabToggle() {
    return Container(
      margin: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          setState(() {
            // Clear search when switching tabs
            if (index != 0) {
              _clearSearch();
            }
          });
        },
        labelPadding: const EdgeInsets.symmetric(vertical: 12),
        tabs: [
          Tab(
            child: Text(
              LearnTabType.educational.displayName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Tab(
            child: Text(
              LearnTabType.behavioral.displayName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        ),
        labelColor: AppColors.white,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),
    );
  }

  /// Build search bar for educational content
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
        vertical: AppConstants.smallPadding,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search allergens or topics...',
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.defaultBorderRadius,
            ),
            borderSide: BorderSide(color: AppColors.lightGrey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.defaultBorderRadius,
            ),
            borderSide: BorderSide(color: AppColors.lightGrey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.defaultBorderRadius,
            ),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          fillColor: AppColors.white,
          filled: true,
        ),
      ),
    );
  }

  /// Build main content area
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_learnContent == null) {
      return _buildEmptyState();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        // Educational tab
        EducationalContentView(
          educational: _learnContent!.educational,
          searchQuery: _searchQuery,
        ),
        // Behavioral tab
        BehavioralContentView(behavioral: _learnContent!.behavioral),
      ],
    );
  }

  /// Build error state
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: AppConstants.defaultPadding),
            Text(
              'Failed to Load Content',
              style: AppTextStyles.headline3.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              _errorMessage!,
              style: AppTextStyles.bodyText2.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            ElevatedButton(onPressed: _loadContent, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Text(
              'No Content Available',
              style: AppTextStyles.headline3.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              'Educational content is currently not available.',
              style: AppTextStyles.bodyText2.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Educational content view with allergen cards
class EducationalContentView extends StatelessWidget {
  final EducationalModule educational;
  final String searchQuery;

  const EducationalContentView({
    super.key,
    required this.educational,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final learnService = LearnService.instance;
    final filteredSections = learnService.searchAllergens(
      searchQuery,
      educational,
    );

    if (filteredSections.isEmpty && searchQuery.isNotEmpty) {
      return _buildNoSearchResults();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      itemCount: filteredSections.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppConstants.smallPadding),
      itemBuilder: (context, index) {
        final section = filteredSections[index];
        final allergenData = AllergenSectionData(
          section: section,
          icon: AllergenInfo.getIcon(section.heading),
          isAllergen: AllergenInfo.isAllergenSection(section.heading),
        );

        return ExpandableInfoCard(
          title: allergenData.title,
          icon: allergenData.icon,
          content: allergenData.content,
          accentColor: AppColors.primary,
          enableSearch: searchQuery.isNotEmpty,
          searchQuery: searchQuery,
        );
      },
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: AppConstants.defaultPadding),
            Text(
              'No Results Found',
              style: AppTextStyles.headline3.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              'Try searching with different keywords or check your spelling.',
              style: AppTextStyles.bodyText2.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Behavioral content view with lifestyle advice
class BehavioralContentView extends StatelessWidget {
  final BehavioralModule behavioral;

  const BehavioralContentView({super.key, required this.behavioral});

  @override
  Widget build(BuildContext context) {
    final sections = behavioral.meaningfulSections;

    if (sections.isEmpty) {
      return _buildEmptyBehavioral();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      itemCount: sections.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppConstants.smallPadding),
      itemBuilder: (context, index) {
        final section = sections[index];
        final title = section.heading.replaceAll(':', '').trim();

        return Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(
              AppConstants.defaultBorderRadius,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CollapsibleSection(
            title: title,
            content: section.content,
            accentColor: AppColors.primary,
          ),
        );
      },
    );
  }

  Widget _buildEmptyBehavioral() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Text(
              'No Behavioral Content',
              style: AppTextStyles.headline3.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              'Behavioral and safety advice is currently not available.',
              style: AppTextStyles.bodyText2.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
