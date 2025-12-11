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
      print('[DEBUG] SubscriptionScreen: Loaded ${tariffs.length} tariffs from backend');
      for (final t in tariffs) {
        print('[DEBUG] Tariff: id=${t.id}, name=${t.name}, price=${t.price}, durationDays=${t.durationDays}');
      }

      // Load current subscription status
      final subscription = await widget.vpnService.getActiveSubscription();
      print('[DEBUG] SubscriptionScreen: Active subscription: $subscription');
      
      if (subscription == null) {
        print('[DEBUG] SubscriptionScreen: NO active subscription (null)');
      } else {
        print('[DEBUG] SubscriptionScreen: Found subscription:');
        print('[DEBUG]   - status: ${subscription.status}');
        print('[DEBUG]   - tariffName: ${subscription.tariffName}');
        print('[DEBUG]   - endedAt: ${subscription.endedAt}');
      }

      if (mounted) {
        setState(() {
          _tariffs = _normalizeTariffs(tariffs);  // Normalize and synthesize canonical plans
          _loading = false;
        });
      }
    } catch (e, stackTrace) {
      print('[ERROR] SubscriptionScreen: Failed to load subscription data: $e');
      print('[ERROR] SubscriptionScreen: Stack trace: $stackTrace');
      
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
        child: Padding(
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('subscribing_to'.tr(args: [tariff.name])),
          duration: const Duration(seconds: 1),
        ),
      );
    }

    try {
      print('[DEBUG] Selecting tariff: id=${tariff.id}, name=${tariff.name}, price=${tariff.price}, durationDays=${tariff.durationDays}');
      
      // Call backend to activate subscription
      final response = await widget.vpnService.subscribeTariff(tariff.id);
      print('[DEBUG] Subscribe response: $response');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('subscription_activated'.tr(args: [tariff.name])),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Pop and signal to HomeScreen to refresh subscription status
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted && context.mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e, stackTrace) {
      print('[ERROR] Failed to subscribe: $e');
      print('[ERROR] Stack trace: $stackTrace');
      
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
      {'key': 'test_7_days', 'names': ['test', 'trial', '7 days', '7-day', 'trial 7 days', 'free'], 'duration': 7, 'price': '0'},
    ];

    final List<TariffOut> out = [];

    for (final plan in canonical) {
      TariffOut? found;
      
      // First, try to find a tariff from server that matches this plan
      for (final n in plan['names'] as List<String>) {
        final key = n.toLowerCase();
        for (final t in serverTariffs) {
          // Check if tariff name contains this keyword (substring match, case-insensitive)
          if (t.name.isNotEmpty && t.name.toLowerCase().contains(key)) {
            found = t;
            break;
          }
        }
        if (found != null) break;
      }

      if (found != null) {
        // Found a server tariff — use it with potentially corrected duration
        final desiredDuration = plan['duration'] as int;
        final price = plan.containsKey('price') ? plan['price'] as String : found.price;
        
        print('[DEBUG] Normalized tariff from server: id=${found.id}, name=${found.name} → duration=$desiredDuration, price=$price');
        
        final tariff = TariffOut(
          id: found.id,  // Use real server ID
          name: found.name,
          description: found.description,
          durationDays: desiredDuration,
          price: price,
        );
        out.add(tariff);
      }
      // NOTE: We NO LONGER synthesize missing plans — only show what the server provides
    }

    return out;
  }


}
