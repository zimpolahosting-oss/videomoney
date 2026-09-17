import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../services/earnings_service.dart';
import '../../services/firestore_service.dart';
import '../../services/rewarded_ad_service.dart';
import '../../theme/app_theme.dart';

class AdrouletteScreen extends StatefulWidget {
  const AdrouletteScreen({super.key});

  @override
  State<AdrouletteScreen> createState() => _AdrouletteScreenState();
}

class _AdrouletteScreenState extends State<AdrouletteScreen> {
  static const List<String> _providerLabels = ['AdMob', 'Appodeal', 'Gravite'];

  final _firestoreService = FirestoreService();
  final _earningsService = EarningsService();
  final _random = Random();

  Timer? _spinTimer;
  bool _isSpinning = false;
  bool _isShowingAd = false;
  String _selectedProviderLabel = _providerLabels.first;
  String _statusText = 'Tap spin to start your next ad.';

  @override
  void initState() {
    super.initState();
    _earningsService.preloadRewardedVideo();
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    super.dispose();
  }

  RewardedAdProvider _providerForLabel(String label) {
    switch (label) {
      case 'Appodeal':
        return RewardedAdProvider.appodeal;
      case 'Gravite':
        return RewardedAdProvider.gravite;
      case 'AdMob':
      default:
        return RewardedAdProvider.admob;
    }
  }

  Future<void> _spinAndShowAd(String uid) async {
    if (_isSpinning || _isShowingAd) return;

    setState(() {
      _isSpinning = true;
      _statusText = 'Spinning the wheel...';
    });

    final spinDurationMs = 2000 + _random.nextInt(2001);
    final finalIndex = _random.nextInt(_providerLabels.length);
    var index = 0;
    final completer = Completer<void>();

    _spinTimer?.cancel();
    _spinTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) return;
      setState(() {
        _selectedProviderLabel = _providerLabels[index % _providerLabels.length];
      });
      index += 1;
    });

    Future<void>.delayed(Duration(milliseconds: spinDurationMs), () async {
      _spinTimer?.cancel();
      if (!mounted) return;

      setState(() {
        _selectedProviderLabel = _providerLabels[finalIndex];
        _isSpinning = false;
        _isShowingAd = true;
        _statusText = 'Opening $_selectedProviderLabel ad...';
      });

      String? lastStatusMessage;
      final rewardGranted = await _earningsService.watchAdRouletteAd(
        uid: uid,
        provider: _providerForLabel(_selectedProviderLabel),
        onAdStatus: (message) {
          lastStatusMessage = message;
        },
      );

      if (!mounted) return;
      setState(() {
        _isShowingAd = false;
        _statusText = rewardGranted
            ? '+1 Adroulette ad counted. Tap spin for the next one.'
            : 'No completed ad counted. Tap spin to try again.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            rewardGranted
                ? '+1 Adroulette ad counted.'
                : (lastStatusMessage ?? 'No ad available right now.'),
          ),
        ),
      );

      completer.complete();
    });

    await completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('No user session found.'),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<AppUser?>(
          stream: _firestoreService.watchUser(user.uid),
          builder: (context, snapshot) {
            final appUser = snapshot.data;
            final currentAds = appUser?.adRouletteAds ?? 0;
            final progress = (currentAds / FirestoreService.minimumAdRoulettePayoutAds)
                .clamp(0.0, 1.0);
            final remaining = currentAds >= FirestoreService.minimumAdRoulettePayoutAds
                ? 0
                : FirestoreService.minimumAdRoulettePayoutAds - currentAds;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                Text(
                  'Adroulette',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Spin the wheel, wait 2-4 seconds, and the ad opens immediately. After the ad, tap again for your next turn.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: const Color(0xFF3A2C00).withOpacity(0.92),
                    border: Border.all(
                      color: const Color(0xFFE6C54A).withOpacity(0.55),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adroulette Ads',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        NumberFormat.decimalPattern().format(currentAds),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: const Color(0xFFFFE082),
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 12,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFE6C54A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        remaining == 0
                            ? 'Ready for payout at 1000 Adroulette ads.'
                            : '$remaining ads remaining to reach 1000.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 190,
                        width: 190,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFF0A8),
                              Color(0xFFE6C54A),
                              Color(0xFF8C6A00),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x443A2C00),
                              blurRadius: 28,
                              spreadRadius: -8,
                              offset: Offset(0, 18),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.casino_rounded,
                              size: 38,
                              color: Color(0xFF3A2C00),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedProviderLabel,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: const Color(0xFF3A2C00),
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _statusText,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: (_isSpinning || _isShowingAd)
                              ? null
                              : () => _spinAndShowAd(user.uid),
                          icon: Icon(
                            _isSpinning || _isShowingAd
                                ? Icons.hourglass_top_rounded
                                : Icons.casino_rounded,
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE6C54A),
                            foregroundColor: const Color(0xFF231A00),
                          ),
                          label: Text(
                            _isSpinning
                                ? 'Spinning...'
                                : _isShowingAd
                                    ? 'Ad running...'
                                    : 'Spin now',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Adroulette ads are separate from your normal VideoMoney ads and cannot be shared.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
