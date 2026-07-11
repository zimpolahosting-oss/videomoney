import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutVideoMoney)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VideoMoney',
                  style: TextStyle(
                    color: AppTheme.primarySoft,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.aboutTagline,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                _Line(label: l10n.version, value: '1.0.1+6'),
                _Line(label: l10n.minimumPayoutLabel, value: '10,000 ${l10n.viewsUnit}'),
                _Line(label: l10n.processingTimeLabel, value: '30 days'),
                _Line(label: l10n.reviewLabel, value: l10n.adminApproval),
                const SizedBox(height: 14),
                Text(
                  l10n.estimatedEarningsOnlyPolicies,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRoutes.privacyPolicy);
                      },
                      icon: const Icon(Icons.privacy_tip_outlined),
                      label: Text(l10n.privacyPolicy),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context)
                            .pushNamed(AppRoutes.termsOfService);
                      },
                      icon: const Icon(Icons.description_outlined),
                      label: Text(l10n.termsOfService),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
