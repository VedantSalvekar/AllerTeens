import 'package:flutter/material.dart';
import '../../core/constants.dart';

/// Reusable pill-style button widget for allergen selection
///
/// This widget displays an allergen name in a pill-shaped button style
/// with different visual states for selected and unselected states.
/// It follows the AllerWise design system with proper colors and spacing.
class AllergenTag extends StatelessWidget {
  /// The allergen name to display
  final String allergenName;

  /// Whether this allergen is currently selected
  final bool isSelected;

  /// Callback function when the allergen is tapped
  final VoidCallback onTap;

  /// Optional custom width for the tag
  final double? width;

  /// Optional custom height for the tag
  final double? height;

  const AllergenTag({
    super.key,
    required this.allergenName,
    required this.isSelected,
    required this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.shortAnimationDuration,
        height: height ?? 44,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          // Selected state: teal background with white text
          // Unselected state: light gray background with dark text
          color: isSelected ? AppColors.primary : AppColors.lightGrey,
          borderRadius: BorderRadius.circular(22), // Pill shape
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          allergenName,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? AppColors.white : AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Helper widget to create a wrap of allergen tags
///
/// This widget creates a responsive grid of allergen tags that wraps
/// to the next line when space runs out. It's useful for displaying
/// multiple allergen options in a clean, organized manner.
class AllergenTagWrap extends StatelessWidget {
  /// List of allergen names to display
  final List<String> allergens;

  /// Set of currently selected allergens
  final Set<String> selectedAllergens;

  /// Callback when an allergen is selected/deselected
  final Function(String) onAllergenToggle;

  /// Spacing between tags
  final double spacing;

  /// Vertical spacing between rows
  final double runSpacing;

  const AllergenTagWrap({
    super.key,
    required this.allergens,
    required this.selectedAllergens,
    required this.onAllergenToggle,
    this.spacing = 12,
    this.runSpacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: allergens.map((allergen) {
        final isSelected = selectedAllergens.contains(allergen);
        return AllergenTag(
          allergenName: allergen,
          isSelected: isSelected,
          onTap: () => onAllergenToggle(allergen),
        );
      }).toList(),
    );
  }
}
