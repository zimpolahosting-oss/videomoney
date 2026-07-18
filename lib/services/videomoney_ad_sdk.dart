import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/main/videomoney_ad_interstitial_screen.dart';

enum VideomoneyAdProvider {
  monetag,
  adcash,
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
            html: config.html!,
            baseUrl: config.baseUrl!,
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
          _log('Ad popup was closed by the user before ${provider.name} opened.');
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
    final primary = VideomoneyAdSettings.primaryProvider;
    final fallback = primary == VideomoneyAdProvider.monetag
        ? VideomoneyAdProvider.adcash
        : VideomoneyAdProvider.monetag;

    if (!VideomoneyAdSettings.enableFallback) {
      return [primary];
    }

    return [primary, fallback];
  }

  _VideomoneyProviderConfig _configFor(VideomoneyAdProvider provider) {
    switch (provider) {
      case VideomoneyAdProvider.monetag:
        return _VideomoneyProviderConfig(
          displayName: 'Monetag',
          baseUrl: VideomoneyAdSettings.monetagBaseUrl,
          html: _buildMonetagHtml(),
        );
      case VideomoneyAdProvider.adcash:
        return _VideomoneyProviderConfig(
          displayName: 'Adcash',
          baseUrl: VideomoneyAdSettings.adcashBaseUrl,
          html: _buildAdcashHtml(),
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

  String _buildMonetagHtml() {
    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta
      name="viewport"
      content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"
    >
    <style>
      html, body {
        margin: 0;
        padding: 0;
        width: 100%;
        height: 100%;
        overflow: hidden;
        background: #05070D;
        color: #ffffff;
        font-family: Arial, sans-serif;
      }
      #status {
        position: fixed;
        left: 12px;
        right: 12px;
        bottom: 12px;
        padding: 10px 12px;
        border-radius: 12px;
        background: rgba(0, 0, 0, 0.55);
        font-size: 14px;
        text-align: center;
        z-index: 2;
      }
    </style>
  </head>
  <body>
    <div id="status">Loading Monetag interstitial...</div>
    <script>
      function postBridge(type, message) {
        if (window.VideomoneyAdBridge && window.VideomoneyAdBridge.postMessage) {
          window.VideomoneyAdBridge.postMessage(JSON.stringify({
            type: type,
            message: message || ''
          }));
        }
      }

      window.addEventListener('load', function() {
        postBridge('loaded', 'Monetag wrapper loaded');
        setTimeout(function() {
          postBridge('shown', 'Monetag script had time to render');
        }, 1200);
      });

      window.addEventListener('error', function(event) {
        postBridge('error', event.message || 'Unknown Monetag page error');
      });

      (function(s){
        s.dataset.zone='11339682';
        s.src='https://al5sm.com/tag.min.js';
        s.onload = function() {
          postBridge('log', 'Monetag script loaded');
        };
        s.onerror = function() {
          postBridge('error', 'Failed to load Monetag script');
        };
      })([document.documentElement, document.body]
        .filter(Boolean)
        .pop()
        .appendChild(document.createElement('script')));
    </script>
  </body>
</html>
''';
  }

  String _buildAdcashHtml() {
    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta
      name="viewport"
      content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"
    >
    <style>
      html, body {
        margin: 0;
        padding: 0;
        width: 100%;
        height: 100%;
        overflow: hidden;
        background: #05070D;
        color: #ffffff;
        font-family: Arial, sans-serif;
      }
      #status {
        position: fixed;
        left: 12px;
        right: 12px;
        bottom: 12px;
        padding: 10px 12px;
        border-radius: 12px;
        background: rgba(0, 0, 0, 0.55);
        font-size: 14px;
        text-align: center;
        z-index: 2;
      }
    </style>
  </head>
  <body>
    <div id="status">Loading Adcash interstitial...</div>
    <script>
      function postBridge(type, message) {
        if (window.VideomoneyAdBridge && window.VideomoneyAdBridge.postMessage) {
          window.VideomoneyAdBridge.postMessage(JSON.stringify({
            type: type,
            message: message || ''
          }));
        }
      }

      window.addEventListener('load', function() {
        postBridge('loaded', 'Adcash wrapper loaded');
      });

      window.addEventListener('error', function(event) {
        postBridge('error', event.message || 'Unknown Adcash page error');
      });

      (function() {
        var script = document.createElement('script');
        script.id = 'aclib';
        script.type = 'text/javascript';
        script.src = 'https://acscdn.com/script/aclib.js';
        script.onload = function() {
          postBridge('log', 'Adcash script loaded');
          try {
            if (!window.aclib || !window.aclib.runInterstitial) {
              postBridge('error', 'aclib.runInterstitial is not available');
              return;
            }
            window.aclib.runInterstitial({
              zoneId: '11743374',
            });
            postBridge('shown', 'Adcash interstitial script executed');
          } catch (error) {
            postBridge('error', error && error.message ? error.message : 'Adcash interstitial execution failed');
          }
        };
        script.onerror = function() {
          postBridge('error', 'Failed to load Adcash script');
        };
        document.body.appendChild(script);
      })();
    </script>
  </body>
</html>
''';
  }
}

class VideomoneyAdSettings {
  const VideomoneyAdSettings._();

  static const VideomoneyAdProvider primaryProvider =
      VideomoneyAdProvider.monetag;
  static const bool enableFallback = true;
  static const Duration openTimeout = Duration(seconds: 10);
  static const String monetagBaseUrl = 'https://al5sm.com';
  static const String adcashBaseUrl = 'https://acscdn.com';
}

class _VideomoneyProviderConfig {
  const _VideomoneyProviderConfig({
    required this.displayName,
    required this.baseUrl,
    required this.html,
  });

  final String displayName;
  final String? baseUrl;
  final String? html;

  String? get validationError {
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
