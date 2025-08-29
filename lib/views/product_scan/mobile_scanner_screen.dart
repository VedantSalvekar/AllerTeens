import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants.dart';
import '../../controllers/product_scan_controller.dart';
import '../../models/product_scan_models.dart';
import 'product_scan_result_screen.dart';

/// Modern barcode scanner screen using mobile_scanner
class MobileScannerScreen extends ConsumerStatefulWidget {
  const MobileScannerScreen({super.key});

  @override
  ConsumerState<MobileScannerScreen> createState() =>
      _MobileScannerScreenState();
}

class _MobileScannerScreenState extends ConsumerState<MobileScannerScreen> {
  late MobileScannerController scannerController;
  bool hasScanned = false;

  @override
  void initState() {
    super.initState();
    scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    // Initialize scanning state immediately to prevent timing issues
    // The original issue was that PostFrameCallback runs too late, after MobileScanner starts detecting
    Future.microtask(() {
      if (mounted) {
        ref.read(productScanControllerProvider.notifier).startBarcodeScanning();
      }
    });
  }

  @override
  void dispose() {
    ref.read(productScanControllerProvider.notifier).cancelBarcodeScanning();
    scannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset hasScanned flag when returning to this screen
    // This ensures the scanner works again if user comes back from results screen
    hasScanned = false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final scanState = ref.watch(productScanControllerProvider);

        // Listen for scan completion and navigate to results
        ref.listen<ProductScanState>(productScanControllerProvider, (
          previous,
          current,
        ) {
          if (current.lastScanResult != null &&
              (previous?.lastScanResult != current.lastScanResult)) {
            _navigateToResults(current.lastScanResult!);
          }
        });

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Scan Barcode'),
            actions: [
              // Torch toggle
              IconButton(
                onPressed: () => scannerController.toggleTorch(),
                icon: ValueListenableBuilder(
                  valueListenable: scannerController,
                  builder: (context, value, child) {
                    switch (value.torchState) {
                      case TorchState.off:
                      case TorchState.unavailable:
                        return const Icon(Icons.flash_off);
                      case TorchState.on:
                        return const Icon(Icons.flash_on);
                      case TorchState.auto:
                        return const Icon(Icons.flash_auto);
                    }
                  },
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              // Camera view
              MobileScanner(
                controller: scannerController,
                onDetect: (barcodeCapture) {
                  // Improved barcode detection logic with better timing handling
                  print(
                    '[SCANNER] Barcode detected - hasScanned: $hasScanned, isScanning: ${scanState.isScanning}',
                  );

                  if (!hasScanned) {
                    // Check if we have valid barcodes
                    final barcodes = barcodeCapture.barcodes;
                    if (barcodes.isNotEmpty &&
                        barcodes.first.rawValue != null) {
                      hasScanned = true;
                      print(
                        '[SCANNER] Processing barcode: ${barcodes.first.rawValue}',
                      );
                      ref
                          .read(productScanControllerProvider.notifier)
                          .onBarcodeDetected(barcodeCapture);
                    }
                  }
                },
              ),

              // Scanner overlay
              _buildScannerOverlay(),

              // Bottom controls
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomControls(scanState),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScannerOverlay() {
    return Stack(
      children: [
        // Dark overlay with transparent center
        Container(
          decoration: ShapeDecoration(
            shape: QrScannerOverlayShape(
              borderColor: AppColors.primary,
              borderRadius: 16,
              borderLength: 40,
              borderWidth: 4,
              cutOutSize: 250,
            ),
          ),
        ),

        // Instructions
        Positioned(
          top: 100,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Position the barcode within the frame to scan',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(ProductScanState scanState) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status indicator
            if (scanState.isLoading) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Checking for allergens...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Error display
            if (scanState.error != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        scanState.error!,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Manual entry button
            ElevatedButton.icon(
              onPressed: () => _showManualEntryDialog(),
              icon: const Icon(Icons.edit),
              label: const Text('Enter Barcode Manually'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textPrimary,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualEntryDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Barcode'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Enter barcode number',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final barcode = controller.text.trim();
              if (barcode.isNotEmpty) {
                Navigator.pop(context);
                ref
                    .read(productScanControllerProvider.notifier)
                    .lookupManualBarcode(barcode);
              }
            },
            child: const Text('Scan'),
          ),
        ],
      ),
    );
  }

  void _navigateToResults(ProductScanResult result) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ProductScanResultScreen(result: result),
      ),
    );
  }
}

/// Custom overlay shape for QR scanner
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path _getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top + borderRadius)
        ..quadraticBezierTo(
          rect.left,
          rect.top,
          rect.left + borderRadius,
          rect.top,
        )
        ..lineTo(rect.right, rect.top);
    }

    return _getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final cutOutWidth = cutOutSize < width ? cutOutSize : width - borderWidth;
    final cutOutHeight = cutOutSize < height
        ? cutOutSize
        : height - borderWidth;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutOutRect = Rect.fromLTWH(
      rect.left + (width - cutOutWidth) / 2 + borderWidth,
      rect.top + (height - cutOutHeight) / 2 + borderWidth,
      cutOutWidth - borderWidth * 2,
      cutOutHeight - borderWidth * 2,
    );

    canvas
      ..saveLayer(rect, backgroundPaint)
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(
        RRect.fromRectAndCorners(
          cutOutRect,
          topLeft: Radius.circular(borderRadius),
          topRight: Radius.circular(borderRadius),
          bottomLeft: Radius.circular(borderRadius),
          bottomRight: Radius.circular(borderRadius),
        ),
        Paint()..blendMode = BlendMode.clear,
      )
      ..restore();

    // Draw corner indicators
    final cornerLength = borderLength;
    final cornerWidth = borderWidth;

    // Top left corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.left - cornerWidth, cutOutRect.top)
        ..lineTo(cutOutRect.left, cutOutRect.top)
        ..lineTo(cutOutRect.left, cutOutRect.top + cornerLength),
      boxPaint,
    );

    // Top right corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.right, cutOutRect.top)
        ..lineTo(cutOutRect.right + cornerWidth, cutOutRect.top)
        ..lineTo(cutOutRect.right, cutOutRect.top + cornerLength),
      boxPaint,
    );

    // Bottom left corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.left, cutOutRect.bottom - cornerLength)
        ..lineTo(cutOutRect.left, cutOutRect.bottom)
        ..lineTo(cutOutRect.left - cornerWidth, cutOutRect.bottom),
      boxPaint,
    );

    // Bottom right corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.right, cutOutRect.bottom - cornerLength)
        ..lineTo(cutOutRect.right, cutOutRect.bottom)
        ..lineTo(cutOutRect.right + cornerWidth, cutOutRect.bottom),
      boxPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
