import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/product_scan_models.dart';
import '../services/auth_service.dart';
import '../controllers/auth_controller.dart';

/// State for product scanning
class ProductScanState {
  final bool isScanning;
  final bool isLoading;
  final ProductScanResult? lastScanResult;
  final List<ScanHistoryEntry> scanHistory;
  final String? error;

  const ProductScanState({
    this.isScanning = false,
    this.isLoading = false,
    this.lastScanResult,
    this.scanHistory = const [],
    this.error,
  });

  ProductScanState copyWith({
    bool? isScanning,
    bool? isLoading,
    ProductScanResult? lastScanResult,
    List<ScanHistoryEntry>? scanHistory,
    String? error,
  }) {
    return ProductScanState(
      isScanning: isScanning ?? this.isScanning,
      isLoading: isLoading ?? this.isLoading,
      lastScanResult: lastScanResult ?? this.lastScanResult,
      scanHistory: scanHistory ?? this.scanHistory,
      error: error ?? this.error,
    );
  }

  ProductScanState clearError() {
    return copyWith(error: null);
  }
}

/// Controller for managing product scanning functionality
class ProductScanController extends StateNotifier<ProductScanState> {
  final AuthService _authService;

  static const String _openFoodFactsBaseUrl =
      'https://world.openfoodfacts.org/api/v0/product';
  static const String _scanHistoryCollection = 'scan_history';

  ProductScanController(this._authService) : super(const ProductScanState()) {
    _initializeController();
  }

  /// Initialize controller and load user-specific data
  Future<void> _initializeController() async {
    await _loadScanHistory();
  }

  /// Start barcode scanning using camera (simplified for mobile_scanner)
  void startBarcodeScanning() {
    // Remove the check for isScanning to allow reinitialization
    // Only prevent starting if actively loading a previous scan
    if (state.isLoading) {
      print('[SCAN] Scanner not started - currently loading previous scan');
      return;
    }
    
    state = state.copyWith(isScanning: true, error: null);
    print('[SCAN] Camera scanner opened - isScanning: true');
  }

  /// Handle barcode detected from mobile scanner
  Future<void> onBarcodeDetected(BarcodeCapture barcodeCapture) async {
    if (state.isLoading || !state.isScanning) return;

    final List<Barcode> barcodes = barcodeCapture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    print('[SCAN] Barcode detected: $barcode');
    state = state.copyWith(isScanning: false);
    await _processBarcodeResult(barcode);
  }

  /// Cancel barcode scanning
  void cancelBarcodeScanning() {
    print('[SCAN] User cancelled scanning');
    state = state.copyWith(isScanning: false);
  }

  /// Process barcode by looking up product information
  Future<void> _processBarcodeResult(String barcode) async {
    state = state.copyWith(isScanning: false, isLoading: true);

    try {
      // Get user allergens directly from user profile
      print(' [SCAN] Loading user profile for allergen check...');
      final user = await _authService.getCurrentUserModel();
      if (user == null) {
        print('[SCAN] No user found - user needs to log in');
        state = state.copyWith(
          isLoading: false,
          error: 'Please log in to scan products',
        );
        return;
      }

      print(' [SCAN] User loaded: ${user.name}, ID: ${user.id}');

      final userAllergens = user.allergies;
      print(' [SCAN] User allergens from profile: $userAllergens');

      if (userAllergens.isEmpty) {
        print('[SCAN] No allergens found in user profile');
        state = state.copyWith(
          isLoading: false,
          error: 'Please set up your allergen profile first in Settings',
        );
        return;
      }

      print(' [SCAN] Found ${userAllergens.length} allergens: $userAllergens');

      // Fetch product data from OpenFoodFacts API
      final productData = await _fetchProductFromApi(barcode);

      ProductScanResult scanResult;

      if (productData != null) {
        print('Product found: ${productData['product_name']}');
        // Create successful scan result
        scanResult = ProductScanResult.fromOpenFoodFacts(
          barcode: barcode,
          productData: productData,
          userAllergens: userAllergens,
        );
        print('Scan result created with verdict: ${scanResult.verdict}');
        print('Matched allergens: ${scanResult.matchedAllergens}');
      } else {
        print('Product not found in OpenFoodFacts database');
        // Product not found in database
        scanResult = ProductScanResult.failure(
          barcode: barcode,
          errorMessage:
              'Product not found in database. Try scanning again or enter the barcode manually.',
        );
      }

      // Save scan result to history
      await _saveScanToHistory(scanResult);

      state = state.copyWith(isLoading: false, lastScanResult: scanResult);
    } catch (e) {
      print('Error processing barcode: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to process barcode: $e',
      );
    }
  }

  /// Manually enter barcode for lookup
  Future<void> lookupManualBarcode(String barcode) async {
    if (barcode.trim().isEmpty) {
      state = state.copyWith(error: 'Please enter a valid barcode');
      return;
    }

    await _processBarcodeResult(barcode.trim());
  }

  /// Fetch product data from OpenFoodFacts API
  Future<Map<String, dynamic>?> _fetchProductFromApi(String barcode) async {
    try {
      final url = '$_openFoodFactsBaseUrl/$barcode.json';
      print('Fetching product data from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'AllerWise/1.0.0 (allergen management app)'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final status = data['status'] as int?;

        if (status == 1 && data['product'] != null) {
          return data['product'] as Map<String, dynamic>;
        } else {
          print('Product not found or invalid response');
          return null;
        }
      } else {
        print('API request failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching product data: $e');
      rethrow;
    }
  }

  /// Save scan result to Firebase scan history
  Future<void> _saveScanToHistory(ProductScanResult scanResult) async {
    try {
      final user = await _authService.getCurrentUserModel();
      if (user == null) {
        print('No authenticated user found, skipping history save');
        return;
      }

      final historyEntry = ScanHistoryEntry(
        id: '', // Will be set by Firestore
        userId: user.id,
        scanResult: scanResult,
        createdAt: DateTime.now(),
      );

      final firestore = FirebaseFirestore.instance;
      final docRef = await firestore
          .collection(_scanHistoryCollection)
          .add(historyEntry.toFirestore());

      // Update the entry with the generated ID
      final updatedEntry = ScanHistoryEntry(
        id: docRef.id,
        userId: user.id,
        scanResult: scanResult,
        createdAt: historyEntry.createdAt,
      );

      // Add to local state
      final updatedHistory = [updatedEntry, ...state.scanHistory];
      state = state.copyWith(scanHistory: updatedHistory);

      print('Scan result saved to history with ID: ${docRef.id}');
    } catch (e) {
      print('Error saving scan to history: $e');
      // Don't throw error - scanning should still work even if history save fails
    }
  }

  /// Load scan history from Firebase
  Future<void> _loadScanHistory() async {
    try {
      final user = await _authService.getCurrentUserModel();
      if (user == null) {
        print('[SCAN] No user found, clearing scan history');
        state = state.copyWith(scanHistory: []);
        return;
      }

      print('[SCAN] Loading scan history for user: ${user.id}');
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore
          .collection(_scanHistoryCollection)
          .where('userId', isEqualTo: user.id)
          .orderBy('createdAt', descending: true)
          .limit(50) // Limit to recent 50 scans
          .get();

      final history = querySnapshot.docs.map((doc) {
        return ScanHistoryEntry.fromFirestore(id: doc.id, data: doc.data());
      }).toList();

      state = state.copyWith(scanHistory: history);
      print(
        '[SCAN] Loaded ${history.length} scan history entries for user ${user.id}',
      );
    } catch (e) {
      print('[SCAN] Error loading scan history: $e');
      // Don't update error state for history loading failure
      state = state.copyWith(scanHistory: []);
    }
  }

  /// Get scan history for display
  List<ScanHistoryEntry> getScanHistory({int? limit}) {
    final history = state.scanHistory;
    if (limit != null && history.length > limit) {
      return history.take(limit).toList();
    }
    return history;
  }

  /// Clear scan history
  Future<void> clearScanHistory() async {
    try {
      final user = await _authService.getCurrentUserModel();
      if (user == null) return;

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // Delete all user's scan history
      final querySnapshot = await firestore
          .collection(_scanHistoryCollection)
          .where('userId', isEqualTo: user.id)
          .get();

      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      state = state.copyWith(scanHistory: []);
      print('Scan history cleared');
    } catch (e) {
      print('Error clearing scan history: $e');
      state = state.copyWith(error: 'Failed to clear history: $e');
    }
  }

  /// Delete specific scan from history
  Future<void> deleteScanFromHistory(String scanId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection(_scanHistoryCollection).doc(scanId).delete();

      // Remove from local state
      final updatedHistory = state.scanHistory
          .where((entry) => entry.id != scanId)
          .toList();

      state = state.copyWith(scanHistory: updatedHistory);
      print('Scan deleted from history: $scanId');
    } catch (e) {
      print('Error deleting scan from history: $e');
      state = state.copyWith(error: 'Failed to delete scan: $e');
    }
  }

  /// Clear the last scan result
  void clearLastScanResult() {
    state = state.copyWith(lastScanResult: null);
  }

  /// Clear any error messages
  void clearError() {
    state = state.clearError();
  }

  /// Refresh scan history
  Future<void> refreshScanHistory() async {
    await _loadScanHistory();
  }

  /// Reset controller state (call when user logs out or changes)
  void resetControllerState() {
    print('[SCAN] Resetting controller state for user change');
    state = const ProductScanState();
  }

  /// Initialize for new user (call when user logs in)
  Future<void> initializeForUser() async {
    print('[SCAN] Initializing controller for new user');
    resetControllerState();
    await _loadScanHistory();
  }
}

/// Provider for the product scan controller
final productScanControllerProvider =
    StateNotifierProvider<ProductScanController, ProductScanState>((ref) {
      final authService = ref.watch(authServiceProvider);
      final controller = ProductScanController(authService);

      // Listen for auth state changes and reset controller when user changes
      ref.listen(authControllerProvider, (previous, current) {
        if (previous?.user?.id != current.user?.id) {
          print('[SCAN] User changed, resetting scan controller');
          controller.resetControllerState();
          if (current.user != null) {
            controller.initializeForUser();
          }
        }
      });

      return controller;
    });

/// Provider for the auth service
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});
