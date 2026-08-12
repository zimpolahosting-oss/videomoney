import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class ShortsAdBreakScreen extends StatefulWidget {
  const ShortsAdBreakScreen({
    super.key,
    required this.providerName,
    required this.onPrepare,
    required this.onStartAd,
    this.adStartDelay = const Duration(seconds: 6),
    this.minimumVisibleDuration = const Duration(seconds: 10),
  });

  final String providerName;
  final Future<void> Function() onPrepare;
  final Future<bool> Function(BuildContext context) onStartAd;
  final Duration adStartDelay;
  final Duration minimumVisibleDuration;

  @override
  State<ShortsAdBreakScreen> createState() => _ShortsAdBreakScreenState();
}

class _ShortsAdBreakScreenState extends State<ShortsAdBreakScreen> {
  late final DateTime _openedAt;
  bool _isStartingAd = false;
  bool _didAttemptAd = false;
  bool _allowClose = false;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.onPrepare());
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _startAdFlow() async {
    if (_isStartingAd) return;
    if (!mounted) return;
    setState(() {
      _didAttemptAd = true;
      _isStartingAd = true;
      _statusText =
          Localizations.localeOf(context).languageCode.toLowerCase() == 'nl'
          ? 'Advertentie wordt gestart...'
          : 'Starting ad...';
    });
    final completed = await widget.onStartAd(context);
    final remainingMinimum =
        widget.minimumVisibleDuration - DateTime.now().difference(_openedAt);
    if (remainingMinimum > Duration.zero) {
      await Future<void>.delayed(remainingMinimum);
    }
    if (!mounted) return;
    _allowClose = true;
    Navigator.of(context).pop(completed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDutch = Localizations.localeOf(context).languageCode.toLowerCase() == 'nl';
    final statusText = _statusText.isNotEmpty
        ? _statusText
        : (isDutch
              ? 'Druk op de knop om je volgende advertentie te bekijken.'
              : 'Tap the button to watch your next ad.');
    return WillPopScope(
      onWillPop: () async => _allowClose,
      child: Scaffold(
        backgroundColor: const Color(0xFF030806),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF11161B),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.ondemand_video_rounded,
                        size: 18,
                        color: AppTheme.primarySoft,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Ad Ready',
                        style: TextStyle(
                          color: AppTheme.primarySoft,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.96, end: 1.04),
                        duration: const Duration(milliseconds: 1100),
                        curve: Curves.easeInOut,
                        builder: (context, scale, child) {
                          return Transform.scale(scale: scale, child: child);
                        },
                        onEnd: () {
                          if (!mounted || _didAttemptAd) return;
                          setState(() {});
                        },
                        child: Container(
                          height: 84,
                          width: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primary.withOpacity(0.12),
                            border: Border.all(
                              color: AppTheme.primary.withOpacity(0.30),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.redeem_rounded,
                            size: 40,
                            color: AppTheme.primarySoft,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        isDutch ? 'Kijk een advertentie om verder te gaan' : 'Watch ad to continue',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        statusText,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isStartingAd ? null : _startAdFlow,
                          icon: Icon(
                            _isStartingAd
                                ? Icons.hourglass_top_rounded
                                : Icons.play_circle_fill_rounded,
                          ),
                          label: Text(
                            _isStartingAd
                                ? (isDutch ? 'Advertentie start...' : 'Starting ad...')
                                : (isDutch ? 'Bekijk advertentie' : 'Watch ad now'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        isDutch
                            ? 'Na 3 shorts start de advertentie alleen wanneer je op deze knop drukt. Als de advertentie volledig is afgerond, gaat de app automatisch verder.'
                            : 'After 3 shorts, the ad only starts when you press this button. When the ad is fully completed, the app continues automatically.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white60,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_isStartingAd) ...[
                        const SizedBox(height: 18),
                        const CircularProgressIndicator(color: Color(0xFF5BD0A5)),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
