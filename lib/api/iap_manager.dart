/// In-App Purchase Manager for iOS and Android
/// 
/// Handles receipt validation, product queries, and payment processing.
/// Communicates with backend via VpnService webhook endpoint.

import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'vpn_service.dart';

// Platform-specific product IDs
const String _kAppleProductIdMonthly = 'com.example.vpn.monthly';
const String _kAppleProductIdAnnual = 'com.example.vpn.annual';
const String _kAppleProductIdLifetime = 'com.example.vpn.lifetime';

/// Manages In-App Purchases for VPN subscription
class IapManager {
  static final IapManager _instance = IapManager._internal();

  factory IapManager() {
    return _instance;
  }

  IapManager._internal();

  late VpnService _vpnService;
  final InAppPurchase _iapPlugin = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails>? _products;
  bool _isAvailable = false;

  /// Initialize IAP Manager
  Future<void> initialize(VpnService vpnService) async {
    _vpnService = vpnService;

    // Check if in-app purchases are available
    _isAvailable = await _iapPlugin.isAvailable();
    if (!_isAvailable) {
      throw Exception('In-app purchases are not available');
    }

    // Listen to purchase stream
    _subscription = _iapPlugin.purchaseStream.listen(
      _handlePurchaseUpdate,
      onError: _handlePurchaseError,
    );

    // Restore completed purchases (important for iOS)
    await _restorePurchases();

    // Query available products
    await _queryProducts();
  }

  /// Get available products
  Future<List<ProductDetails>> getProducts() async {
    if (_products == null) {
      await _queryProducts();
    }
    return _products ?? [];
  }

  /// Query available products from platform
  Future<void> _queryProducts() async {
    final Set<String> productIds = {
      _kAppleProductIdMonthly,
      _kAppleProductIdAnnual,
      _kAppleProductIdLifetime,
    };

    try {
      final ProductDetailsResponse response =
          await _iapPlugin.queryProductDetails(productIds);

      if (response.notFoundIDs.isNotEmpty) {
        print('Warning: Products not found: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      print('Loaded ${_products?.length ?? 0} products');
    } catch (e) {
      print('Error querying products: $e');
      _products = [];
    }
  }

  /// Purchase a product
  Future<bool> purchaseProduct(ProductDetails product) async {
    try {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );

      await _iapPlugin.buyNonConsumable(purchaseParam: purchaseParam);
      return true;
    } catch (e) {
      print('Error purchasing product: $e');
      return false;
    }
  }

  /// Restore completed purchases (iOS)
  Future<void> _restorePurchases() async {
    try {
      await _iapPlugin.restorePurchases();
    } catch (e) {
      print('Error restoring purchases: $e');
    }
  }

  /// Handle purchase update from platform
  void _handlePurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final PurchaseDetails purchase in purchases) {
      _processPurchase(purchase);
    }
  }

  /// Process a single purchase
  Future<void> _processPurchase(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.pending) {
      print('Purchase pending: ${purchase.productID}');
      return;
    }

    if (purchase.status == PurchaseStatus.error) {
      print('Purchase error: ${purchase.status}');
      _handlePurchaseError(purchase.error);
      return;
    }

    if (purchase.status == PurchaseStatus.restored) {
      print('Purchase restored: ${purchase.productID}');
    }

    // Send receipt to backend for validation
    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      try {
        await _sendReceiptToBackend(purchase);
      } catch (e) {
        print('Error sending receipt to backend: $e');
      }
    }

    // Mark purchase as consumed (complete the purchase flow)
    if (purchase.pendingCompletePurchase) {
      await _iapPlugin.completePurchase(purchase);
      print('Purchase completed: ${purchase.productID}');
    }
  }

  /// Send receipt to backend for validation
  Future<void> _sendReceiptToBackend(PurchaseDetails purchase) async {
    try {
      final String? receipt = purchase.verificationData.localVerificationData;

      if (receipt == null || receipt.isEmpty) {
        throw Exception('No receipt data available');
      }

      // Send to backend webhook via VpnService
      final response = await _vpnService.verifyIapReceipt(
        receipt: receipt,
        provider: 'apple',
        packageName: 'com.example.vpn',
        productId: purchase.productID,
      );

      print('Receipt validated successfully: ${response.paymentId}');
    } catch (e) {
      print('Error sending receipt to backend: $e');
      rethrow;
    }
  }

  /// Handle purchase errors
  void _handlePurchaseError(IAPError? error) {
    if (error != null) {
      print('IAP Error: ${error.code} - ${error.message}');
    }
  }

  /// Cleanup resources
  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}
