import 'package:flutter/material.dart';
import '../../core/constants.dart';

/// Reusable quick action card widget for the Home Screen
class QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String iconPath;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? textColor;
  final double height;
  final bool isEnabled;

  const QuickActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.iconPath,
    required this.onTap,
    this.backgroundColor,
    this.textColor,
    this.height = 120.0,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
        vertical: AppConstants.smallPadding,
      ),
      child: Material(
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        elevation: 2,
        shadowColor: AppColors.primary.withOpacity(0.1),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          child: Container(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            decoration: BoxDecoration(
              color: backgroundColor ?? AppColors.surface,
              borderRadius: BorderRadius.circular(
                AppConstants.defaultBorderRadius,
              ),
              border: Border.all(color: AppColors.lightGrey, width: 1),
            ),
            child: Row(
              children: [
                // Icon section
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(
                      AppConstants.smallBorderRadius,
                    ),
                  ),
                  child: Center(child: _buildIcon()),
                ),

                const SizedBox(width: AppConstants.defaultPadding),

                // Content section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.headline3.copyWith(
                          color: textColor ?? AppColors.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodyText2.copyWith(
                          color: (textColor ?? AppColors.textSecondary)
                              .withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow indicator
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    // Check if iconPath is an emoji or asset path
    if (iconPath.startsWith('assets/')) {
      return Image.asset(
        iconPath,
        width: 32,
        height: 32,
        color: AppColors.primary,
      );
    } else {
      // Treat as emoji
      return Text(iconPath, style: const TextStyle(fontSize: 32));
    }
  }
}

/// Specialized Track Symptoms Card
class TrackSymptomsCard extends StatelessWidget {
  final VoidCallback onTap;

  const TrackSymptomsCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return QuickActionCard(
      title: 'Track Symptoms',
      subtitle: 'Feeling okay today?',
      iconPath: '📋', // Clipboard emoji
      onTap: onTap,
      backgroundColor: AppColors.surface,
    );
  }
}

/// Specialized View Logs Card
class ViewLogsCard extends StatelessWidget {
  final VoidCallback onTap;

  const ViewLogsCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return QuickActionCard(
      title: 'View Logs',
      subtitle: 'Check your history',
      iconPath: '📅', // Calendar emoji
      onTap: onTap,
      backgroundColor: AppColors.surface,
    );
  }
}

/// Specialized Emergency Card
class EmergencyCard extends StatelessWidget {
  final VoidCallback onTap;

  const EmergencyCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return QuickActionCard(
      title: 'Emergency',
      subtitle: 'Quick access to help',
      iconPath: '🚨', // Emergency emoji
      onTap: onTap,
      backgroundColor: AppColors.error.withOpacity(0.1),
      textColor: AppColors.error,
    );
  }
}

/// Specialized Medication Card
class MedicationCard extends StatelessWidget {
  final VoidCallback onTap;

  const MedicationCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return QuickActionCard(
      title: 'Medication',
      subtitle: 'Track your usage',
      iconPath: '💊', // Pill emoji
      onTap: onTap,
      backgroundColor: AppColors.surface,
    );
  }
}

/// Grid layout for quick action cards
class QuickActionGrid extends StatelessWidget {
  final List<Widget> cards;
  final int crossAxisCount;
  final double childAspectRatio;

  const QuickActionGrid({
    super.key,
    required this.cards,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.6,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: AppConstants.defaultPadding,
          mainAxisSpacing: AppConstants.defaultPadding,
        ),
        itemCount: cards.length,
        itemBuilder: (context, index) => cards[index],
      ),
    );
  }
}

/// List layout for quick action cards
class QuickActionList extends StatelessWidget {
  final List<Widget> cards;
  final EdgeInsets padding;

  const QuickActionList({
    super.key,
    required this.cards,
    this.padding = const EdgeInsets.all(AppConstants.defaultPadding),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(children: cards),
    );
  }
}

/// Section header for quick actions
class QuickActionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  const QuickActionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
        vertical: AppConstants.smallPadding,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.headline3.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: AppTextStyles.bodyText2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: Text(
                'See All',
                style: AppTextStyles.bodyText2.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
