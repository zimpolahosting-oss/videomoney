import 'dart:async';

import 'package:flutter/material.dart';

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
  Timer? _countdownTimer;
  int _secondsUntilAd = 0;
  bool _isStartingAd = false;
  bool _didAttemptAd = false;
  bool _allowClose = false;
  String _statusText = 'Preparing your next ad break...';

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    _secondsUntilAd = widget.adStartDelay.inSeconds;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runFlow());
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _didAttemptAd) return;
      final elapsed = DateTime.now().difference(_openedAt);
      final remaining = widget.adStartDelay - elapsed;
      final nextSeconds = remaining.inSeconds.clamp(0, widget.adStartDelay.inSeconds);
      if (_secondsUntilAd == nextSeconds) return;
      setState(() {
        _secondsUntilAd = nextSeconds;
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _runFlow() async {
    await widget.onPrepare();
    final remainingDelay = widget.adStartDelay - DateTime.now().difference(_openedAt);
    if (remainingDelay > Duration.zero) {
      await Future<void>.delayed(remainingDelay);
    }
    if (!mounted) return;
    setState(() {
      _didAttemptAd = true;
      _isStartingAd = true;
      _statusText = 'Starting ${widget.providerName}...';
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
                        size: 46,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Ad break',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _didAttemptAd
                            ? _statusText
                            : '${widget.providerName} starts in ${_secondsUntilAd.clamp(0, widget.adStartDelay.inSeconds)}s',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: _didAttemptAd
                            ? null
                            : (DateTime.now().difference(_openedAt).inMilliseconds /
                                    widget.adStartDelay.inMilliseconds)
                                .clamp(0, 1),
                        minHeight: 8,
                        backgroundColor: Colors.white12,
                        color: const Color(0xFF5BD0A5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Current playback is paused before the ad starts. When the ad is finished, this page closes automatically and the app continues.',
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
