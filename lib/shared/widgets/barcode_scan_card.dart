import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../controllers/product_scan_controller.dart';
import '../../models/product_scan_models.dart';
import '../../views/product_scan/mobile_scanner_screen.dart';

/// Card widget for barcode scanning feature on home screen
class BarcodeScanCard extends ConsumerWidget {
  const BarcodeScanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(productScanControllerProvider);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
        vertical: AppConstants.smallPadding,
      ),
      child: Material(
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        elevation: 2,
        shadowColor: AppColors.primary.withOpacity(0.1),
        child: InkWell(
          onTap: scanState.isLoading ? null : () => _onTap(context, ref),
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          child: Container(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(
                AppConstants.defaultBorderRadius,
              ),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Icon section with animated state
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _getIconBackgroundColor(scanState),
                    borderRadius: BorderRadius.circular(
                      AppConstants.smallBorderRadius,
                    ),
                  ),
                  child: Center(child: _buildIcon(scanState)),
                ),

                const SizedBox(width: AppConstants.defaultPadding),

                // Content section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Scan Food for Allergens',
                        style: AppTextStyles.headline3.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getSubtitleText(scanState),
                        style: AppTextStyles.bodyText2.copyWith(
                          color: AppColors.textSecondary.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),

                // Action indicator
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    scanState.isLoading
                        ? Icons.hourglass_empty
                        : Icons.qr_code_scanner,
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

  /// Handle card tap
  void _onTap(BuildContext context, WidgetRef ref) {
    final controller = ref.read(productScanControllerProvider.notifier);
    controller.clearError();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MobileScannerScreen()),
    );
  }

  /// Get icon background color based on scan state
  Color _getIconBackgroundColor(ProductScanState scanState) {
    if (scanState.isLoading) {
      return AppColors.warning.withOpacity(0.1);
    }

    if (scanState.error != null) {
      return AppColors.error.withOpacity(0.1);
    }

    if (scanState.lastScanResult != null) {
      switch (scanState.lastScanResult!.verdict) {
        case AllergenVerdict.safe:
          return AppColors.success.withOpacity(0.1);
        case AllergenVerdict.risky:
          return AppColors.error.withOpacity(0.1);
        case AllergenVerdict.unknown:
          return AppColors.warning.withOpacity(0.1);
      }
    }

    return AppColors.primary.withOpacity(0.1);
  }

  /// Build icon based on scan state
  Widget _buildIcon(ProductScanState scanState) {
    if (scanState.isLoading) {
      return SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.warning),
        ),
      );
    }

    if (scanState.error != null) {
      return const Text('❌', style: TextStyle(fontSize: 32));
    }

    if (scanState.lastScanResult != null) {
      return Text(
        scanState.lastScanResult!.verdict.displayIcon,
        style: const TextStyle(fontSize: 32),
      );
    }

    return const Text('🔍', style: TextStyle(fontSize: 32));
  }

  /// Get subtitle text based on scan state
  String _getSubtitleText(ProductScanState scanState) {
    if (scanState.isLoading) {
      return 'Checking for allergens...';
    }

    if (scanState.error != null) {
      return 'Tap to try again';
    }

    if (scanState.lastScanResult != null) {
      final result = scanState.lastScanResult!;
      if (result.isSuccessful) {
        switch (result.verdict) {
          case AllergenVerdict.safe:
            return 'Last scan: No allergens detected';
          case AllergenVerdict.risky:
            return 'Last scan: Allergen risk found';
          case AllergenVerdict.unknown:
            return 'Last scan: Unable to verify';
        }
      } else {
        return 'Last scan: Product not found';
      }
    }

    return 'Scan grocery barcodes instantly';
  }
}

/// Quick scan history preview widget
class ScanHistoryPreview extends ConsumerWidget {
  const ScanHistoryPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(productScanControllerProvider);
    final recentScans = scanState.scanHistory.take(3).toList();

    if (recentScans.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
        vertical: AppConstants.smallPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Scans',
                style: AppTextStyles.headline3.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to full scan history
                  // TODO: Implement scan history screen
                },
                child: Text(
                  'View All',
                  style: AppTextStyles.bodyText2.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...recentScans.map((entry) => _buildHistoryItem(entry)),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(ScanHistoryEntry entry) {
    final result = entry.scanResult;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.lightGrey.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          // Verdict icon
          Text(
            result.verdict.displayIcon,
            style: const TextStyle(fontSize: 20),
          ),

          const SizedBox(width: 12),

          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.productName ?? 'Unknown Product',
                  style: AppTextStyles.bodyText1.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  result.verdict.displayText,
                  style: AppTextStyles.bodyText2.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Time
          Text(
            _formatTime(entry.createdAt),
            style: AppTextStyles.bodyText2.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
