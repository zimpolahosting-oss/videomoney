import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

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
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            child: Text(initial),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.email ?? 'Unknown user',
                                  style:
                                      Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text('Member since: $createdAt'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.monetization_on_outlined),
                        title: const Text('Coins'),
                        trailing: Text('${appUser?.coins ?? 0}'),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.video_collection_outlined),
                        title: const Text('Videos watched'),
                        trailing: Text('${appUser?.videosWatched ?? 0}'),
                      ),
                      const SizedBox(height: 12),
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
              ),
            ],
          ),
        );
      },
    );
  }
}
