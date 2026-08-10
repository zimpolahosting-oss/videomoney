import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/main/videomoney_ad_interstitial_screen.dart';

enum VideomoneyAdProvider {
  monetag,
}

class VideomoneyAdCallbacks {
  const VideomoneyAdCallbacks({
    this.onLoaded,
    this.onShown,
    this.onClosed,
    this.onFailed,
  });

  final ValueChanged<VideomoneyAdProvider>? onLoaded;
  final ValueChanged<VideomoneyAdProvider>? onShown;
  final ValueChanged<VideomoneyAdProvider>? onClosed;
  final void Function(VideomoneyAdProvider provider, String reason)? onFailed;
}

class VideomoneyAdSdk {
  VideomoneyAdSdk._();

  static final VideomoneyAdSdk instance = VideomoneyAdSdk._();

  Future<bool> showInterstitial({
    required BuildContext context,
    VideomoneyAdCallbacks callbacks = const VideomoneyAdCallbacks(),
  }) async {
    final providers = _orderedProviders();
    _log(
      'Starting interstitial flow. Primary provider: '
      '${VideomoneyAdSettings.primaryProvider.name}.',
    );

    for (final provider in providers) {
      final config = _configFor(provider);
      final validationError = config.validationError;
      if (validationError != null) {
        _emitFailure(callbacks, provider, validationError);
        continue;
      }
      _log('Provider ${provider.name} is ready. Opening ad popup.');

      final result = await Navigator.of(context).push<VideomoneyAdScreenResult>(
        MaterialPageRoute<VideomoneyAdScreenResult>(
          fullscreenDialog: true,
          builder: (_) => VideomoneyAdInterstitialScreen(
            providerName: config.displayName,
            html: config.html,
            baseUrl: config.baseUrl,
            launchUrl: config.launchUrl,
            timeout: VideomoneyAdSettings.openTimeout,
            onLoaded: () {
              _log('Provider ${provider.name} reported loaded.');
              callbacks.onLoaded?.call(provider);
            },
            onShown: () {
              _log('Provider ${provider.name} reported shown.');
              callbacks.onShown?.call(provider);
            },
            onFailed: (reason) {
              _emitFailure(callbacks, provider, reason);
            },
          ),
        ),
      );

      switch (result) {
        case VideomoneyAdScreenResult.shownAndReturned:
          _log('Provider ${provider.name} completed and returned to app.');
          callbacks.onClosed?.call(provider);
          return true;
        case VideomoneyAdScreenResult.closedBeforeShow:
          _log(
            'Ad popup was closed before ${provider.name} qualified for reward.',
          );
          callbacks.onClosed?.call(provider);
          return false;
        case VideomoneyAdScreenResult.failed:
          break;
        case VideomoneyAdScreenResult.timedOut:
          break;
        case null:
          _emitFailure(
            callbacks,
            provider,
            'Ad popup returned no result.',
          );
          break;
      }
    }

    _log('All configured providers failed.');
    return false;
  }

  List<VideomoneyAdProvider> _orderedProviders() {
    return [VideomoneyAdSettings.primaryProvider];
  }

  _VideomoneyProviderConfig _configFor(VideomoneyAdProvider provider) {
    switch (provider) {
      case VideomoneyAdProvider.monetag:
        return const _VideomoneyProviderConfig(
          displayName: 'Monetag',
          launchUrl: VideomoneyAdSettings.monetagDirectLinkUrl,
        );
    }
  }

  void _emitFailure(
    VideomoneyAdCallbacks callbacks,
    VideomoneyAdProvider provider,
    String reason,
  ) {
    _log('Provider ${provider.name} failed: $reason');
    callbacks.onFailed?.call(provider, reason);
  }

  void _log(String message) {
    debugPrint('[VideomoneyAds] $message');
  }

}

class VideomoneyAdSettings {
  const VideomoneyAdSettings._();

  static const VideomoneyAdProvider primaryProvider =
      VideomoneyAdProvider.monetag;
  static const Duration openTimeout = Duration(seconds: 10);
  static const String monetagDirectLinkUrl = 'https://omg10.com/4/11320247';
}

class _VideomoneyProviderConfig {
  const _VideomoneyProviderConfig({
    required this.displayName,
    this.baseUrl,
    this.html,
    this.launchUrl,
  });

  final String displayName;
  final String? baseUrl;
  final String? html;
  final String? launchUrl;

  String? get validationError {
    final directValue = launchUrl?.trim() ?? '';
    if (directValue.isNotEmpty) {
      final launchUri = Uri.tryParse(directValue);
      if (launchUri == null || !launchUri.hasScheme) {
        return '$displayName direct link is invalid.';
      }
      return null;
    }

    final value = html?.trim() ?? '';
    if (value.isEmpty) {
      return '$displayName ad page is not configured yet.';
    }
    final uri = Uri.tryParse(baseUrl ?? '');
    if (uri == null || !uri.hasScheme) {
      return '$displayName base URL is invalid.';
    }
    return null;
  }
}
