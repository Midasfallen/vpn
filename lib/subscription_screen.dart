import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

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
  List<TariffOut>? _tariffs;  // Тарифы из API
  bool _loading = true;
  String? _error;
  UserSubscriptionOut? _currentSubscription;


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
      // Load tariffs from backend API
      final tariffs = await widget.vpnService.listTariffs();

      // Load current subscription status
      final subscription = await widget.vpnService.getActiveSubscription();

      if (mounted) {
        setState(() {
          _tariffs = tariffs;  // Сохраняем тарифы из API
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

            // Available plans from API
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
                  if (_tariffs != null && _tariffs!.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _tariffs!.length,
                      itemBuilder: (context, index) {
                        final tariff = _tariffs![index];
                        return _buildTariffCard(tariff);
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

  Widget _buildTariffCard(TariffOut tariff) {
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
                        tariff.name,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (tariff.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            tariff.description,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${tariff.durationDays} ${'days'.tr()}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${tariff.price}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
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
                onPressed: () => _selectTariff(tariff),
                child: Text('select_plan'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTariff(TariffOut tariff) async {
    // For now, just show a message
    // In future, integrate with payment system
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${tariff.name} selected')),
    );
  }

}
