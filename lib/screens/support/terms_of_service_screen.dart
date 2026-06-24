import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          _SectionCard(
            title: 'Using VideoMoney',
            children: const [
              _BulletLine('You must use accurate account information.'),
              _BulletLine(
                'One person may not abuse multiple accounts, bots, scripts, VPN rotation, or emulator farms to generate extra views.',
              ),
              _BulletLine(
                'Rewarded ads, Firebase authentication, and payout review remain protected by the existing platform setup.',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Views and rewards',
            children: const [
              _BulletLine(
                'Views shown in the app are promotional reward units used inside VideoMoney.',
              ),
              _BulletLine(
                'Estimated earnings are informational only and can change based on platform performance, policy, fraud checks, and payout review.',
              ),
              _BulletLine(
                'Daily bonus rewards are limited to eligible activity and can be removed if abuse is detected.',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Payouts and review',
            children: const [
              _BulletLine('Minimum payout remains 10,000 views.'),
              _BulletLine(
                'All payout requests require manual admin approval and can be approved, rejected, or marked paid.',
              ),
              _BulletLine(
                'Rejected payout requests may be refunded back to the user balance when allowed by the admin workflow.',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Support and messages',
            children: const [
              _BulletLine(
                'Help & Support, bug reports, admin replies, and push notifications can be stored in your in-app inbox.',
              ),
              _BulletLine(
                'By enabling notifications, you allow VideoMoney to send app updates, support replies, and daily reminder messages to your device.',
              ),
              _BulletLine(
                'Serious misuse, harassment, or fraudulent activity can lead to restriction of app access.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 8, color: AppTheme.primarySoft),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
