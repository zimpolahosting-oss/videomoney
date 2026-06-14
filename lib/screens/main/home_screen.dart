import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/firestore_service.dart';
import '../../widgets/stat_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final service = FirestoreService();

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user session found.')),
      );
    }

    return StreamBuilder<AppUser?>(
      stream: service.watchUser(user.uid),
      builder: (context, snapshot) {
        final appUser = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Home'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(user.email ?? 'Signed-in user'),
                      const SizedBox(height: 20),
                      Text(
                        '${appUser?.coins ?? 0} coins',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Open the Earn tab to watch a rewarded video.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_circle_fill),
                        label: const Text('Watch Video'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StatCard(
                title: 'Coin balance',
                value: '${appUser?.coins ?? 0}',
                icon: Icons.monetization_on,
                color: Colors.amber.shade700,
              ),
              StatCard(
                title: 'Videos watched',
                value: '${appUser?.videosWatched ?? 0}',
                icon: Icons.ondemand_video,
                color: Colors.redAccent,
              ),
            ],
          ),
        );
      },
    );
  }
}
