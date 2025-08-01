import 'package:flutter/material.dart';
import '../../core/constants.dart';

/// Reusable expandable card widget for educational content
class ExpandableInfoCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? icon;
  final List<String> content;
  final bool isInitiallyExpanded;
  final Color? accentColor;
  final VoidCallback? onTap;
  final bool enableSearch;
  final String searchQuery;

  const ExpandableInfoCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.content,
    this.isInitiallyExpanded = false,
    this.accentColor,
    this.onTap,
    this.enableSearch = false,
    this.searchQuery = '',
  });

  @override
  State<ExpandableInfoCard> createState() => _ExpandableInfoCardState();
}

class _ExpandableInfoCardState extends State<ExpandableInfoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isInitiallyExpanded;
    _animationController = AnimationController(
      duration: AppConstants.defaultAnimationDuration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
    widget.onTap?.call();
  }

  /// Highlight search query in text
  Widget _buildHighlightedText(String text) {
    if (!widget.enableSearch || widget.searchQuery.isEmpty) {
      return Text(
        text,
        style: AppTextStyles.bodyText1.copyWith(
          color: AppColors.textPrimary,
          height: 1.6,
        ),
      );
    }

    final query = widget.searchQuery.toLowerCase();
    final lowerText = text.toLowerCase();
    
    if (!lowerText.contains(query)) {
      return Text(
        text,
        style: AppTextStyles.bodyText1.copyWith(
          color: AppColors.textPrimary,
          height: 1.6,
        ),
      );
    }

    final spans = <TextSpan>[];
    int start = 0;
    int index = lowerText.indexOf(query);
    
    while (index != -1) {
      // Add text before highlight
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: AppTextStyles.bodyText1.copyWith(
            color: AppColors.textPrimary,
            height: 1.6,
          ),
        ));
      }
      
      // Add highlighted text
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: AppTextStyles.bodyText1.copyWith(
          color: AppColors.white,
          backgroundColor: widget.accentColor ?? AppColors.primary,
          height: 1.6,
        ),
      ));
      
      start = index + query.length;
      index = lowerText.indexOf(query, start);
    }
    
    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: AppTextStyles.bodyText1.copyWith(
          color: AppColors.textPrimary,
          height: 1.6,
        ),
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accentColor ?? AppColors.primary;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _isExpanded 
              ? accentColor.withOpacity(0.3)
              : AppColors.lightGrey.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: _toggleExpansion,
            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
            child: Container(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Row(
                children: [
                  // Icon
                  if (widget.icon != null) ...[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
                      ),
                      child: Center(
                        child: Text(
                          widget.icon!,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.defaultPadding),
                  ],
                  
                  // Title and subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: AppTextStyles.headline3.copyWith(
                            color: accentColor,
                            fontSize: 18,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle!,
                            style: AppTextStyles.bodyText2.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Expand/collapse indicator
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _animation.value * 3.14159, // 180 degrees
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: accentColor,
                          size: 28,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable content
          SizeTransition(
            sizeFactor: _animation,
            child: Container(
              padding: const EdgeInsets.only(
                left: AppConstants.defaultPadding,
                right: AppConstants.defaultPadding,
                bottom: AppConstants.defaultPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Divider
                  Container(
                    height: 1,
                    color: AppColors.lightGrey,
                    margin: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
                  ),
                  
                  // Content paragraphs
                  if (widget.content.isEmpty) ...[
                    Text(
                      'No content available for this section.',
                      style: AppTextStyles.bodyText2.copyWith(
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ] else ...[
                    ...widget.content.map((paragraph) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: _buildHighlightedText(paragraph),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple collapsible list for behavioral content sections
class CollapsibleSection extends StatefulWidget {
  final String title;
  final List<String> content;
  final Color? accentColor;
  final bool isInitiallyExpanded;
  final String? searchQuery;

  const CollapsibleSection({
    super.key,
    required this.title,
    required this.content,
    this.accentColor,
    this.isInitiallyExpanded = false,
    this.searchQuery,
  });

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isInitiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accentColor ?? AppColors.primary;
    
    return ExpansionTile(
      title: Text(
        widget.title,
        style: AppTextStyles.headline3.copyWith(
          color: accentColor,
          fontSize: 18,
        ),
      ),
      initiallyExpanded: _isExpanded,
      onExpansionChanged: (expanded) {
        setState(() {
          _isExpanded = expanded;
        });
      },
      backgroundColor: AppColors.surface,
      collapsedBackgroundColor: AppColors.surface,
      iconColor: accentColor,
      collapsedIconColor: accentColor.withOpacity(0.7),
      childrenPadding: const EdgeInsets.only(
        left: AppConstants.defaultPadding,
        right: AppConstants.defaultPadding,
        bottom: AppConstants.defaultPadding,
      ),
      children: [
        if (widget.content.isEmpty) ...[
          Text(
            'No content available for this section.',
            style: AppTextStyles.bodyText2.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ] else ...[
          ...widget.content.map((paragraph) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                paragraph,
                style: AppTextStyles.bodyText1.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}