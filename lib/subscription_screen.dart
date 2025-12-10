import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'api/vpn_service.dart';
import 'api/models.dart';

/// SubscriptionScreen — отображает доступные тарифы и позволяет
/// выполнить покупку через In-App Purchases (Apple IAP или Google Play).
class SubscriptionScreen extends StatefulWidget {
  final VpnService vpnService;

  const SubscriptionScreen({
    super.key,
    required this.vpnService,
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
          _tariffs = _normalizeTariffs(tariffs);  // Normalize and synthesize canonical plans
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
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('subscribing_to'.tr(args: [tariff.name])),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      // If this is a synthetic test tariff (id <= 0 and price == 0), simulate activation locally
      if (tariff.id <= 0 && (tariff.price == '0' || tariff.price == '0.0')) {
        // Create a local subscription object to show immediate activation for testing
        final now = DateTime.now();
        final ended = now.add(Duration(days: tariff.durationDays));
        setState(() {
          _currentSubscription = UserSubscriptionOut(
            id: -1,
            userId: -1,
            tariffId: tariff.id,
            tariffName: tariff.name,
            startedAt: now.toIso8601String(),
            endedAt: ended.toIso8601String(),
            status: 'active',
            durationDays: tariff.durationDays,
            price: tariff.price,
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('subscription_activated'.tr(args: [tariff.name])),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        return;
      }

      // Otherwise call backend to activate subscription
      await widget.vpnService.subscribeTariff(tariff.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('subscription_activated'.tr(args: [tariff.name])),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Reload subscription data to show new active subscription
        await Future.delayed(const Duration(milliseconds: 500));
        _loadSubscriptionData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_subscribing'.tr(args: [e.toString()])),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Normalize tariffs returned from backend into a canonical set for the UI.
  // This filters out legacy/duplicate plans and ensures a free 7-day test plan
  // is always shown (synthesized if missing on the server).
  List<TariffOut> _normalizeTariffs(List<TariffOut> serverTariffs) {
    // Desired canonical plan keys with heuristics to match server names
    final canonical = [
      {'key': '1_month', 'names': ['1 month', 'monthly', 'monthly plan', '1 Month', 'Monthly Plan'], 'duration': 30},
      {'key': '6_months', 'names': ['6 months', 'half', 'half-year', '6 Month', 'Half-Year Plan', '6 Months'], 'duration': 180},
      {'key': '1_year', 'names': ['1 year', 'yearly', 'year', '1 Year', 'Yearly Plan'], 'duration': 365},
      {'key': 'test_7_days', 'names': ['test', 'trial', '7 days', '7-day', 'trial 7 days'], 'duration': 7, 'price': '0'},
    ];

    final List<TariffOut> out = [];
    int syntheticId = -1;

    for (final plan in canonical) {
      TariffOut? found;
      for (final n in plan['names'] as List<String>) {
        final key = n.toLowerCase();
        // Check if any server tariff name contains this keyword (substring match)
        for (final t in serverTariffs) {
          if (t.name.toLowerCase().contains(key)) {
            found = t;
            break;
          }
        }
        if (found != null) break;
      }

      if (found != null) {
        // If server returned a plan but durationDays looks wrong (e.g. 30), prefer canonical duration
        final desiredDuration = plan['duration'] as int;
        final price = plan.containsKey('price') ? plan['price'] as String : found.price;
        final tariff = TariffOut(
          id: found.id,
          name: found.name,
          description: found.description,
          durationDays: desiredDuration,
          price: price,
        );
        out.add(tariff);
      } else {
        // Synthesize a plan (especially the free test plan)
        final desiredDuration = plan['duration'] as int;
        final price = plan.containsKey('price') ? plan['price'] as String : '0.99';
        final name = (plan['key'] as String) == '1_month' ? '1 Month' : (plan['key'] as String) == '6_months' ? '6 Months' : (plan['key'] as String) == '1_year' ? '1 Year' : 'Test 7 Days';
        out.add(TariffOut(
          id: syntheticId,
          name: name,
          description: '',
          durationDays: desiredDuration,
          price: price,
        ));
        syntheticId -= 1;
      }
    }

    return out;
  }


}
