import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:notix_inapp_flutter/notix.dart';

class MonetagInterstitialService {
  MonetagInterstitialService._();

  static final MonetagInterstitialService instance =
      MonetagInterstitialService._();

  static const int _shortsZoneId = 11339682;
  static const int _loaderTimeoutMs = 8000;

  Future<void>? _initializeFuture;
  InterstitialLoader? _loader;
  Completer<bool>? _activeShowCompleter;

  Future<void> initialize() {
    return _initializeFuture ??= _initializeInternal();
  }

  Future<void> _initializeInternal() async {
    Notix.setLogLevel(LogLevel.important);
    Notix.Interstitial.setShowResultListener((InterstitialShowResult result) {
      debugPrint('[Monetag SDK] show result: ${result.name}');
      switch (result) {
        case InterstitialShowResult.onDismiss:
          _completeActiveShow(true);
          break;
        case InterstitialShowResult.onShowError:
          _completeActiveShow(false);
          break;
        case InterstitialShowResult.onClick:
          break;
      }
    });

    _loader = await Notix.Interstitial.createLoader(_shortsZoneId);
    _loader!.startLoading();
  }

  Future<bool> showShortsInterstitial() async {
    await initialize();
    final loader = _loader;
    if (loader == null) return false;

    InterstitialData interstitialData;
    try {
      interstitialData = await loader.next(timeout: _loaderTimeoutMs);
    } catch (error, stackTrace) {
      debugPrint('[Monetag SDK] failed to get next interstitial: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }

    if (_activeShowCompleter != null && !_activeShowCompleter!.isCompleted) {
      debugPrint('[Monetag SDK] interstitial show already in progress.');
      return false;
    }

    final completer = Completer<bool>();
    _activeShowCompleter = completer;

    try {
      Notix.Interstitial.show(interstitialData);
    } catch (error, stackTrace) {
      debugPrint('[Monetag SDK] failed to show interstitial: $error');
      debugPrintStack(stackTrace: stackTrace);
      _completeActiveShow(false);
    }

    return completer.future;
  }

  void _completeActiveShow(bool value) {
    final completer = _activeShowCompleter;
    if (completer == null || completer.isCompleted) return;
    completer.complete(value);
    _activeShowCompleter = null;
  }
}
