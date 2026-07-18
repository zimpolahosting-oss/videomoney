import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

enum VideomoneyAdScreenResult {
  shownAndReturned,
  closedBeforeShow,
  failed,
  timedOut,
}

class VideomoneyAdInterstitialScreen extends StatefulWidget {
  const VideomoneyAdInterstitialScreen({
    super.key,
    required this.providerName,
    this.html,
    this.baseUrl,
    this.launchUrl,
    required this.timeout,
    required this.onLoaded,
    required this.onShown,
    required this.onFailed,
  });

  final String providerName;
  final String? html;
  final String? baseUrl;
  final String? launchUrl;
  final Duration timeout;
  final VoidCallback onLoaded;
  final VoidCallback onShown;
  final ValueChanged<String> onFailed;

  @override
  State<VideomoneyAdInterstitialScreen> createState() =>
      _VideomoneyAdInterstitialScreenState();
}

class _VideomoneyAdInterstitialScreenState
    extends State<VideomoneyAdInterstitialScreen> with WidgetsBindingObserver {
  Timer? _timeoutTimer;
  WebViewController? _controller;
  bool _isClosing = false;
  bool _isOpening = true;
  bool _adLoaded = false;
  bool _adShown = false;
  bool _fallbackOpening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timeoutTimer = Timer(widget.timeout, _handleTimeout);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF05070D))
      ..setOnConsoleMessage((message) {
        _log('[console][${message.level.name}] ${message.message}');
      })
      ..addJavaScriptChannel(
        'VideomoneyAdBridge',
        onMessageReceived: (message) => _handleBridgeMessage(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            _log('Page started: $url');
            if (_isDirectLinkMode && !_adLoaded) {
              _adLoaded = true;
              setState(() => _isOpening = false);
              widget.onLoaded();
            }
            if (_isDirectLinkMode && !_adShown) {
              _adShown = true;
              widget.onShown();
            }
          },
          onPageFinished: (url) {
            _log('Page finished: $url');
          },
          onWebResourceError: (error) {
            _log(
              'Web resource error: code=${error.errorCode} '
              'mainFrame=${error.isForMainFrame} desc=${error.description}',
            );
            if (!(error.isForMainFrame ?? false)) return;
            if (_isDirectLinkMode) {
              unawaited(
                _fallbackToInAppBrowser(
                  '${widget.providerName} embedded load failed: ${error.description}',
                ),
              );
              return;
            }
            widget.onFailed(
              '${widget.providerName} main frame error: ${error.description}',
            );
            _close(VideomoneyAdScreenResult.failed);
          },
          onNavigationRequest: (request) {
            _log('Navigation request: ${request.url}');
            final uri = Uri.tryParse(request.url);
            if (uri == null) {
              return NavigationDecision.prevent;
            }
            final isHttp = uri.scheme == 'http' || uri.scheme == 'https';
            if (isHttp) {
              return NavigationDecision.navigate;
            }
            if (_isDirectLinkMode) {
              _log('Blocked non-http navigation inside ad shell: ${request.url}');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    final platformController = _controller!.platform;
    if (platformController is AndroidWebViewController) {
      platformController.setMediaPlaybackRequiresUserGesture(false);
    }

    if (_isDirectLinkMode) {
      Future<void>.delayed(const Duration(milliseconds: 250), _loadDirectLinkInShell);
    } else {
      _controller!.loadHtmlString(widget.html!, baseUrl: widget.baseUrl!);
    }
  }

  bool get _isDirectLinkMode => (widget.launchUrl?.trim().isNotEmpty ?? false);

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _log('Lifecycle changed: $state');
  }

  Future<void> _loadDirectLinkInShell() async {
    if (!_isDirectLinkMode || _isClosing || !mounted || _controller == null) return;
    final uri = Uri.parse(widget.launchUrl!);
    _log('Loading ${widget.providerName} direct link in shell: $uri');
    await _controller!.loadRequest(uri);
  }

  Future<void> _fallbackToInAppBrowser(String reason) async {
    if (!_isDirectLinkMode || _isClosing || !mounted || _fallbackOpening) return;
    _fallbackOpening = true;
    _log('Falling back to in-app browser: $reason');
    widget.onFailed(reason);
    final uri = Uri.parse(widget.launchUrl!);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.inAppBrowserView,
      webViewConfiguration: const WebViewConfiguration(
        enableJavaScript: true,
        enableDomStorage: true,
      ),
      browserConfiguration: const BrowserConfiguration(
        showTitle: false,
      ),
    );
    if (!mounted) return;
    if (!launched) {
      widget.onFailed(
        'Could not open ${widget.providerName} fallback browser.',
      );
      _close(VideomoneyAdScreenResult.failed);
      return;
    }
    _adLoaded = true;
    _adShown = true;
    setState(() => _isOpening = false);
    widget.onShown();
    _close(VideomoneyAdScreenResult.shownAndReturned);
  }

  void _handleBridgeMessage(String rawMessage) {
    _log('Bridge message: $rawMessage');
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map<String, dynamic>) return;
      final type = decoded['type'] as String? ?? '';
      final message = decoded['message'] as String? ?? '';

      switch (type) {
        case 'loaded':
          if (!_adLoaded) {
            _adLoaded = true;
            setState(() => _isOpening = false);
            widget.onLoaded();
          }
          break;
        case 'shown':
          if (!_adShown) {
            _adShown = true;
            setState(() => _isOpening = false);
            widget.onShown();
          }
          break;
        case 'close':
          _close(VideomoneyAdScreenResult.shownAndReturned);
          break;
        case 'error':
          widget.onFailed(
            message.isEmpty
                ? '${widget.providerName} reported an unknown script error.'
                : message,
          );
          _close(VideomoneyAdScreenResult.failed);
          break;
        case 'log':
          _log(message);
          break;
      }
    } catch (error) {
      _log('Failed to parse bridge message: $error');
    }
  }

  void _handleTimeout() {
    if ((_adLoaded || _adShown) || _isClosing || !mounted) return;
    _log('${widget.providerName} timed out before ad load.');
    widget.onFailed(
      '${widget.providerName} timed out before the ad could load.',
    );
    _close(VideomoneyAdScreenResult.timedOut);
  }

  void _close(VideomoneyAdScreenResult result) {
    if (_isClosing || !mounted) return;
    _isClosing = true;
    _timeoutTimer?.cancel();
    Navigator.of(context).pop(result);
  }

  void _log(String message) {
    debugPrint('[VideomoneyAds/UI] $message');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070D),
      body: SafeArea(
        child: Stack(
          children: [
            if (_controller != null)
              Positioned.fill(
                child: WebViewWidget(
                  controller: _controller!,
                ),
              )
            else
              const Positioned.fill(
                child: ColoredBox(color: Color(0xFF05070D)),
              ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x22000000),
                        Color(0x00000000),
                        Color(0x2A000000),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => _close(
                    (_adLoaded || _adShown)
                        ? VideomoneyAdScreenResult.shownAndReturned
                        : VideomoneyAdScreenResult.closedBeforeShow,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ),
            Center(
              child: AnimatedOpacity(
                opacity: _isOpening ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: !_isOpening,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.10),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.28),
                              blurRadius: 32,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                widget.providerName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: 56,
                              height: 56,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.lightBlueAccent.shade100,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Preparing ad',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isDirectLinkMode
                                  ? 'Please wait while VideoMoney loads the official ${widget.providerName} page inside the app. '
                                        'Use the X button above to close and continue.'
                                  : 'Please wait while VideoMoney loads your interstitial ad. '
                                        'If this provider fails, the SDK will try the fallback automatically.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_isOpening)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.60),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _isDirectLinkMode
                        ? 'Loading ${widget.providerName} inside app…'
                        : 'Loading ${widget.providerName} ad…',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
