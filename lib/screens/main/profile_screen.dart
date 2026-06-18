import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_routes.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firestoreService = FirestoreService();
    final authService = AuthService();

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user session found.')),
      );
    }

    return StreamBuilder<AppUser?>(
      stream: firestoreService.watchUser(user.uid),
      builder: (context, snapshot) {
        final appUser = snapshot.data;
        final initial = ((user.email?.isNotEmpty ?? false) ? user.email! : 'U')
            .substring(0, 1)
            .toUpperCase();
        final createdAt = appUser?.createdAt == null
            ? 'Not available yet'
            : DateFormat.yMMMd().format(appUser!.createdAt!);
        final emailVerified = user.emailVerified;

        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                const _TopTitle(title: 'Profile'),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF11261C),
                        Color(0xFF08120E),
                        Color(0xFF04100A),
                      ],
                    ),
                    border: Border.all(color: AppTheme.outline.withOpacity(0.9)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.12),
                        blurRadius: 28,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'VideoMoney',
                              style: TextStyle(
                                color: AppTheme.primarySoft,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).pushNamed(AppRoutes.settings);
                            },
                            icon: const Icon(
                              Icons.settings_outlined,
                              color: AppTheme.primarySoft,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AppTheme.primary.withOpacity(0.14),
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: AppTheme.primarySoft,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.email ?? 'Unknown user',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Member since: $createdAt',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  emailVerified ? 'Email verified' : 'Email not verified',
                                  style: TextStyle(
                                    color: emailVerified
                                        ? AppTheme.primarySoft
                                        : Colors.orangeAccent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VideoMoney',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.visibility_outlined,
                        title: 'Current Views',
                        value: NumberFormat.decimalPattern()
                            .format(appUser?.views ?? 0),
                      ),
                      _InfoRow(
                        icon: Icons.ondemand_video_outlined,
                        title: 'Videos Watched',
                        value: NumberFormat.decimalPattern()
                            .format(appUser?.videosWatched ?? 0),
                      ),
                      const _InfoRow(
                        icon: Icons.security_outlined,
                        title: 'Security',
                        value: 'Firebase Protected',
                        valueColor: AppTheme.primarySoft,
                      ),
                      const _InfoRow(
                        icon: Icons.verified_user_outlined,
                        title: 'Payout Review',
                        value: 'Admin Approval',
                        valueColor: AppTheme.primarySoft,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
                  ),
                  child: Column(
                    children: [
                      _MenuTile(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        subtitle: 'Notifications, privacy, and app settings',
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.settings);
                        },
                      ),
                      _MenuTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Help & Support',
                        subtitle: 'Contact admin and send messages',
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.helpSupport);
                        },
                      ),
                      _MenuTile(
                        icon: Icons.bug_report_outlined,
                        title: 'Report Bug',
                        subtitle: 'Report a problem or a bug',
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.reportBug);
                        },
                      ),
                      _MenuTile(
                        icon: Icons.star_rate_outlined,
                        title: 'Rate App',
                        subtitle: 'Rate VideoMoney on Google Play',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Rating flow will be enabled in the store build.'),
                            ),
                          );
                        },
                      ),
                      _MenuTile(
                        icon: Icons.info_outline,
                        title: 'About VideoMoney',
                        subtitle: 'App details, policies, and contact',
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.about);
                        },
                      ),
                      if (appUser?.isAdmin ?? false)
                        _MenuTile(
                          icon: Icons.admin_panel_settings_outlined,
                          title: 'Admin Dashboard',
                          subtitle: 'Review payout requests',
                          onTap: () {
                            Navigator.of(context)
                                .pushNamed(AppRoutes.adminDashboard);
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF7B7B),
                      side: BorderSide(color: const Color(0xFFFF7B7B).withOpacity(0.35)),
                    ),
                    onPressed: () async {
                      await authService.signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopTitle extends StatelessWidget {
  const _TopTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primarySoft, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withOpacity(0.12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.22)),
              ),
              child: Icon(icon, color: AppTheme.primarySoft),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
