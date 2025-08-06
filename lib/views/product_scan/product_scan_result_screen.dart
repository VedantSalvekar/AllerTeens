import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../models/product_scan_models.dart';
import '../../controllers/product_scan_controller.dart';
import 'mobile_scanner_screen.dart';

/// Screen displaying the results of a product scan with allergen analysis
class ProductScanResultScreen extends ConsumerWidget {
  final ProductScanResult result;

  const ProductScanResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: _getVerdictColor().withOpacity(0.1),
        foregroundColor: _getVerdictColor(),
        title: const Text('Scan Results'),
        elevation: 0,
        actions: [
          // Share or save action
          IconButton(
            onPressed: () => _showActionsMenu(context, ref),
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Verdict header
              _buildVerdictHeader(),

              const SizedBox(height: 24),

              // Product information
              _buildProductInfo(),

              const SizedBox(height: 24),

              // Allergen analysis
              if (result.isSuccessful) ...[
                _buildAllergenAnalysis(),
                const SizedBox(height: 24),
              ],

              // Ingredients (if available)
              if (result.isSuccessful && result.ingredients.isNotEmpty) ...[
                _buildIngredientsSection(),
                const SizedBox(height: 24),
              ],

              // Action buttons
              _buildActionButtons(context, ref),

              const SizedBox(height: 24),

              // Disclaimer
              _buildDisclaimer(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build verdict header with result summary
  Widget _buildVerdictHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _getVerdictColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getVerdictColor().withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Verdict icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _getVerdictColor().withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                result.verdict.displayIcon,
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Verdict text
          Text(
            _getVerdictTitle(),
            style: AppTextStyles.headline2.copyWith(
              color: _getVerdictColor(),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Verdict description
          Text(
            _getVerdictDescription(),
            style: AppTextStyles.bodyText1.copyWith(color: _getVerdictColor()),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build product information section
  Widget _buildProductInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product Information',
            style: AppTextStyles.headline3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 16),

          // Product name
          _buildInfoRow(
            'Product Name',
            result.productName ?? 'Unknown Product',
            Icons.shopping_cart,
          ),

          const SizedBox(height: 12),

          // Barcode
          _buildInfoRow('Barcode', result.barcode, Icons.qr_code),

          const SizedBox(height: 12),

          // Scan time
          _buildInfoRow(
            'Scanned',
            _formatDateTime(result.scannedAt),
            Icons.access_time,
          ),

          // Product image (if available)
          if (result.imageUrl != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                result.imageUrl!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 120,
                    color: AppColors.lightGrey,
                    child: const Center(child: Icon(Icons.image_not_supported)),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build allergen analysis section
  Widget _buildAllergenAnalysis() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Allergen Analysis',
                style: AppTextStyles.headline3.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Matched allergens
          if (result.matchedAllergens.isNotEmpty) ...[
            Text(
              'Detected Allergens in Your Profile:',
              style: AppTextStyles.bodyText1.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.matchedAllergens.map((allergen) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning, size: 16, color: AppColors.error),
                      const SizedBox(width: 4),
                      Text(
                        allergen,
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Product allergens
          if (result.allergens.isNotEmpty) ...[
            Text(
              'Product Allergens Listed:',
              style: AppTextStyles.bodyText1.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.allergens.map((allergen) {
                final isMatched = result.matchedAllergens.any(
                  (matched) =>
                      allergen.toLowerCase().contains(matched.toLowerCase()),
                );
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isMatched
                        ? AppColors.error.withOpacity(0.1)
                        : AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isMatched
                          ? AppColors.error.withOpacity(0.3)
                          : AppColors.warning.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    allergen,
                    style: TextStyle(
                      color: isMatched ? AppColors.error : AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Traces
          if (result.traces.isNotEmpty) ...[
            Text(
              'May Contain (Traces):',
              style: AppTextStyles.bodyText1.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.traces.map((trace) {
                final isMatched = result.matchedAllergens.any(
                  (matched) =>
                      trace.toLowerCase().contains(matched.toLowerCase()),
                );
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isMatched
                        ? AppColors.error.withOpacity(0.1)
                        : AppColors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isMatched
                          ? AppColors.error.withOpacity(0.3)
                          : AppColors.grey.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    trace,
                    style: TextStyle(
                      color: isMatched ? AppColors.error : AppColors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // No allergens found
          if (result.allergens.isEmpty && result.traces.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No allergen information found in the product database',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build ingredients section with highlighting
  Widget _buildIngredientsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Ingredients',
                style: AppTextStyles.headline3.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          ...result.ingredients.map(
            (ingredient) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.lightGrey.withOpacity(0.5)),
              ),
              child: Text(
                ingredient,
                style: AppTextStyles.bodyText2.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build action buttons
  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Scan another product
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _scanAnotherProduct(context, ref),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Another Product'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Back to home
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            icon: const Icon(Icons.home),
            label: const Text('Back to Home'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build disclaimer
  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text(
                'Important Notice',
                style: AppTextStyles.bodyText1.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• This scan is based on publicly available data\n'
            '• Always read the actual product label before consuming\n'
            '• Contact the manufacturer for the most accurate information\n'
            '• If you have severe allergies, use this as a guide only',
            style: AppTextStyles.bodyText2.copyWith(
              color: AppColors.warning,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Build info row helper
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyText2.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyText1.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Get verdict color based on result
  Color _getVerdictColor() {
    if (!result.isSuccessful) return AppColors.error;

    switch (result.verdict) {
      case AllergenVerdict.safe:
        return AppColors.success;
      case AllergenVerdict.risky:
        return AppColors.error;
      case AllergenVerdict.unknown:
        return AppColors.warning;
    }
  }

  /// Get verdict title
  String _getVerdictTitle() {
    if (!result.isSuccessful) {
      return 'Scan Failed';
    }

    switch (result.verdict) {
      case AllergenVerdict.safe:
        return 'Safe to Consume';
      case AllergenVerdict.risky:
        return 'Allergen Risk Detected';
      case AllergenVerdict.unknown:
        return 'Unable to Verify';
    }
  }

  /// Get verdict description
  String _getVerdictDescription() {
    if (!result.isSuccessful) {
      return result.errorMessage ?? 'Unable to scan this product';
    }

    switch (result.verdict) {
      case AllergenVerdict.safe:
        return 'No allergens in your profile were detected';
      case AllergenVerdict.risky:
        return 'Contains allergens from your profile';
      case AllergenVerdict.unknown:
        return 'Insufficient allergen information available';
    }
  }

  /// Format date time
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Scan another product
  void _scanAnotherProduct(BuildContext context, WidgetRef ref) {
    // Clear the last scan result
    ref.read(productScanControllerProvider.notifier).clearLastScanResult();

    // Navigate to scanner
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MobileScannerScreen()),
    );
  }

  /// Show actions menu
  void _showActionsMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('View Scan History'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to scan history screen
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete This Scan'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement delete scan functionality
              },
            ),
          ],
        ),
      ),
    );
  }
}
