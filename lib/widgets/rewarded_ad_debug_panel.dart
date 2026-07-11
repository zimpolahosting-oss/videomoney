import 'package:flutter/material.dart';

import '../services/earnings_service.dart';
import '../services/rewarded_ad_service.dart';
import '../theme/app_theme.dart';

class RewardedAdDebugPanel extends StatelessWidget {
  const RewardedAdDebugPanel({
    super.key,
    required this.earningsService,
  });

  final EarningsService earningsService;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RewardedAdDebugState>(
      valueListenable: earningsService.rewardedAdDebugListenable,
      builder: (context, debugState, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: AppTheme.primary.withOpacity(0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.bug_report_outlined,
                    color: AppTheme.primarySoft,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ad Debug',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Selected next: ${debugState.selectedNetwork}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Last shown: ${debugState.lastShownNetwork}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                debugState.loadedNetworks.isEmpty
                    ? 'Loaded now: none'
                    : 'Loaded now: ${debugState.loadedNetworks.join(', ')}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Last event: ${debugState.lastEvent}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: debugState.skipDirectAdMobForTesting,
                onChanged: (value) {
                  earningsService.setSkipDirectAdMobForTesting(value);
                },
                title: const Text('Skip direct AdMob'),
                subtitle: const Text(
                  'Turn this on to force-test Appodeal, Appnext, Meta, and Start.io first.',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
