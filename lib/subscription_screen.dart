import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'api/vpn_service.dart';
import 'api/logging.dart';
import 'api/models.dart';
import 'theme/colors.dart';

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
      ApiLogger.debug('SubscriptionScreen: Loaded ${tariffs.length} tariffs');

      // Load current subscription status
      final subscription = await widget.vpnService.getActiveSubscription();
      
      if (subscription == null) {
        ApiLogger.debug('SubscriptionScreen: No active subscription');
      } else {
        ApiLogger.debug('SubscriptionScreen: Active subscription found - tariff=${subscription.tariffName}');
      }

      if (mounted) {
        setState(() {
          _tariffs = _normalizeTariffs(tariffs);  // Normalize and synthesize canonical plans
          _loading = false;
        });
      }
    } catch (e, stackTrace) {
      ApiLogger.error('SubscriptionScreen: Failed to load subscription data: $e', e, stackTrace);
      
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
        backgroundColor: AppColors.darkBg,
        appBar: AppBar(
          title: Text('subscription'.tr()),
          backgroundColor: AppColors.darkBgSecondary,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.darkBg,
        appBar: AppBar(
          title: Text('subscription'.tr()),
          backgroundColor: AppColors.darkBgSecondary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'error'.tr(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? '',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
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
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text('subscription'.tr()),
        backgroundColor: AppColors.darkBgSecondary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'available_plans'.tr(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              if (_tariffs != null && _tariffs!.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _tariffs!.length,
                  itemBuilder: (context, index) {
                    final tariff = _tariffs![index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildTariffCard(tariff),
                    );
                  },
                )
              else
                Center(
                  child: Text(
                    'no_tariffs_available'.tr(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTariffCard(TariffOut tariff) {
    final isFree = tariff.price == '0' || tariff.price.isEmpty;
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderLight,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGold.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Name and Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tariff.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (tariff.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            tariff.description,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: isFree ? AppColors.success.withValues(alpha: 0.15) : AppColors.accentGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    isFree ? 'Free' : '\$${tariff.price}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isFree ? AppColors.success : AppColors.accentGold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Duration info
            Container(
              decoration: BoxDecoration(
                color: AppColors.darkBgTertiary,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                '${tariff.durationDays} ${'days'.tr()}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentCyan,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Select button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: AppColors.darkBg,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () => _selectTariff(tariff),
              child: Text(
                'select_plan'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
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
          backgroundColor: AppColors.info,
        ),
      );
    }

    try {
      ApiLogger.debug('SubscriptionScreen: Selected tariff id=${tariff.id}, name=${tariff.name}');
      
      // Call backend to activate subscription
      await widget.vpnService.subscribeTariff(tariff.id);
      ApiLogger.debug('SubscriptionScreen: Subscribe response received');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('subscription_activated'.tr(args: [tariff.name])),
            backgroundColor: AppColors.success,
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
      ApiLogger.error('SubscriptionScreen: Failed to subscribe: $e', e, stackTrace);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_subscribing'.tr(args: [e.toString()])),
            backgroundColor: AppColors.error,
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
        
        ApiLogger.debug('SubscriptionScreen: Normalized tariff id=${found.id}, name=${found.name}, duration=$desiredDuration');
        
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
