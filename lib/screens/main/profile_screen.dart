import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_logo.dart';

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
            : DateFormat.yMMMd().add_jm().format(appUser!.createdAt!);

        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF102219),
                      Color(0xFF08110D),
                    ],
                  ),
                  border: Border.all(color: AppTheme.outline.withOpacity(0.75)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppTheme.primary.withOpacity(0.14),
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: AppTheme.primarySoft,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.email ?? 'Unknown user',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Member since: $createdAt',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const BrandLogo(height: 52),
                    const SizedBox(height: 20),
                    _ProfileRow(
                      icon: Icons.monetization_on_outlined,
                      title: 'Coins',
                      value: '${appUser?.coins ?? 0}',
                    ),
                    _ProfileRow(
                      icon: Icons.video_collection_outlined,
                      title: 'Videos watched',
                      value: '${appUser?.videosWatched ?? 0}',
                    ),
                    const _ProfileRow(
                      icon: Icons.security_outlined,
                      title: 'Account security',
                      value: 'Protected by Firebase Authentication',
                    ),
                    const _ProfileRow(
                      icon: Icons.receipt_long_outlined,
                      title: 'Payout reviews',
                      value: 'Requests stay pending until admin approval',
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
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
            ],
          ),
        );
      },
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withOpacity(0.03),
          border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primarySoft),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 5),
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
