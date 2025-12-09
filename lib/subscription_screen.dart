import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'api/iap_manager.dart';
import 'api/vpn_service.dart';
import 'api/models.dart';

/// SubscriptionScreen — отображает доступные тарифы и позволяет
/// выполнить покупку через In-App Purchases (Apple IAP или Google Play).
class SubscriptionScreen extends StatefulWidget {
  final VpnService vpnService;
  final IapManager iapManager;

  const SubscriptionScreen({
    super.key,
    required this.vpnService,
    required this.iapManager,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<ProductDetails>? _products;
  bool _loading = true;
  String? _error;
  UserSubscriptionOut? _currentSubscription;
  String? _purchasingProductId;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
  }

  Future<void> _loadSubscriptionData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Load available products
      final products = await widget.iapManager.getProducts();

      // Load current subscription status
      final subscription = await widget.vpnService.getActiveSubscription();

      if (mounted) {
        setState(() {
          _products = products;
          _currentSubscription = subscription;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _handlePurchase(ProductDetails product) async {
    setState(() {
      _purchasingProductId = product.id;
    });

    try {
      final success = await widget.iapManager.purchaseProduct(product);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('purchase_initiated'.tr())),
        );
        // Reload subscription status after a delay
        await Future.delayed(const Duration(seconds: 2));
        _loadSubscriptionData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('purchase_error'.tr(args: [e.toString()])),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _purchasingProductId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('subscription'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('subscription'.tr())),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('error'.tr()),
              const SizedBox(height: 8),
              Text(_error ?? ''),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadSubscriptionData,
                child: Text('retry'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('subscription'.tr()),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Current subscription status
            if (_currentSubscription != null)
              _buildCurrentSubscriptionCard()
            else
              _buildNoSubscriptionCard(),

            const SizedBox(height: 24),

            // Available plans
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'available_plans'.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (_products != null && _products!.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _products!.length,
                      itemBuilder: (context, index) {
                        final product = _products![index];
                        return _buildPlanCard(product);
                      },
                    )
                  else
                    Center(
                      child: Text('no_tariffs_available'.tr()),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSubscriptionCard() {
    final subscription = _currentSubscription!;
    
    // Calculate days remaining
    final endedAt = subscription.endedAt;
    int daysRemaining = 0;
    bool isLifetime = false;
    
    if (endedAt != null) {
      final ended = DateTime.tryParse(endedAt);
      if (ended != null) {
        daysRemaining = ended.difference(DateTime.now()).inDays;
        if (daysRemaining < 0) daysRemaining = 0;
      }
    } else {
      isLifetime = true;
    }
    
    final tariffName = subscription.tariffName;

    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'subscription_active'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tariffName),
                if (!isLifetime)
                  Text(
                    '$daysRemaining ${'days'.tr()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  )
                else
                  Text(
                    'lifetime_access'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
            if (!isLifetime && daysRemaining < 7)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'subscription_expiring_soon'.tr(),
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSubscriptionCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.orange.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'no_active_subscription'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.orange, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'choose_plan_below'.tr(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(ProductDetails product) {
    final isAnnual = product.id.contains('annual');
    final isPurchasing = _purchasingProductId == product.id;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            product.description,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      product.price,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                    ),
                    if (isAnnual)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'best_value'.tr(),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isPurchasing ? null : () => _handlePurchase(product),
                child: isPurchasing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('purchase'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
