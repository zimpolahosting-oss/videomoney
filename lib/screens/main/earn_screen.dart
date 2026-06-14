import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/firestore_service.dart';
import '../../services/rewarded_ad_service.dart';
import '../../widgets/stat_card.dart';

class EarnScreen extends StatefulWidget {
  const EarnScreen({super.key});

  @override
  State<EarnScreen> createState() => _EarnScreenState();
}

class _EarnScreenState extends State<EarnScreen> {
  final _firestoreService = FirestoreService();
  final _rewardedAdService = RewardedAdService();
  bool _isLoading = false;

  Future<void> _watchVideo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    final rewardGranted = await _rewardedAdService.showRewardedAd(
      onUserEarnedReward: () async {
        await _firestoreService.rewardUser(uid: user.uid, coinsReward: 200);
      },
      onAdStatus: (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          rewardGranted
              ? 'You earned 200 coins.'
              : 'Rewarded ad was not completed.',
        ),
      ),
    );

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user session found.')),
      );
    }

    return StreamBuilder<AppUser?>(
      stream: _firestoreService.watchUser(user.uid),
      builder: (context, snapshot) {
        final appUser = snapshot.data;

        return Scaffold(
          appBar: AppBar(title: const Text('Earn')),
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
                        'Watch rewarded videos',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Complete a rewarded ad to receive 200 coins.',
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _watchVideo,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                            _isLoading ? 'Loading ad...' : 'Watch Video',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StatCard(
                title: 'Current balance',
                value: '${appUser?.coins ?? 0} coins',
                icon: Icons.savings,
                color: Colors.green,
              ),
              StatCard(
                title: 'Total rewarded videos',
                value: '${appUser?.videosWatched ?? 0}',
                icon: Icons.movie_filter,
                color: Colors.deepPurple,
              ),
            ],
          ),
        );
      },
    );
  }
}
