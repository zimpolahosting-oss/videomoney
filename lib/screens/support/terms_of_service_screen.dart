import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.termsOfService)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          _SectionCard(
            title: l10n.termsUsingTitle,
            children: [
              _BulletLine(l10n.termsUsingBullet1),
              _BulletLine(l10n.termsUsingBullet2),
              _BulletLine(l10n.termsUsingBullet3),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: l10n.termsViewsTitle,
            children: [
              _BulletLine(l10n.termsViewsBullet1),
              _BulletLine(l10n.termsViewsBullet2),
              _BulletLine(l10n.termsViewsBullet3),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: l10n.termsPayoutsTitle,
            children: [
              _BulletLine(l10n.termsPayoutsBullet1),
              _BulletLine(l10n.termsPayoutsBullet2),
              _BulletLine(l10n.termsPayoutsBullet3),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: l10n.termsSupportTitle,
            children: [
              _BulletLine(l10n.termsSupportBullet1),
              _BulletLine(l10n.termsSupportBullet2),
              _BulletLine(l10n.termsSupportBullet3),
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
