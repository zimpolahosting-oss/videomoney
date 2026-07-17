import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class MonetagAdBreakScreen extends StatefulWidget {
  const MonetagAdBreakScreen({
    super.key,
    required this.url,
  });

  final String url;

  @override
  State<MonetagAdBreakScreen> createState() => _MonetagAdBreakScreenState();
}

class _MonetagAdBreakScreenState extends State<MonetagAdBreakScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isClosing = false;
  bool _pageFinished = false;
  DateTime? _openedAt;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'MonetagBridge',
        onMessageReceived: (message) {
          final value = message.message.trim().toLowerCase();
          if (value == 'close' || value == 'done' || value == 'finished') {
            _closeAdBreakIfReady(completed: true);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            _openedAt ??= DateTime.now();
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (_) {
            _pageFinished = true;
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (error) {
            if (!(error.isForMainFrame ?? false)) return;
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.navigate;
            final closeSignal =
                uri.queryParameters['close'] == '1' ||
                uri.queryParameters['done'] == '1' ||
                uri.queryParameters['status'] == 'close' ||
                uri.queryParameters['status'] == 'done' ||
                uri.queryParameters['status'] == 'finished' ||
                uri.path.contains('ad-close') ||
                uri.path.contains('ad-finished');
            if (closeSignal) {
              _closeAdBreakIfReady(completed: true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    final platformController = _controller.platform;
    if (platformController is AndroidWebViewController) {
      platformController.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  void _closeAdBreakIfReady({required bool completed}) {
    final openedAt = _openedAt;
    final visibleLongEnough =
        openedAt != null &&
        DateTime.now().difference(openedAt) >= const Duration(seconds: 5);
    if (!_pageFinished || !visibleLongEnough) {
      return;
    }
    _closeAdBreak(completed: completed);
  }

  void _closeAdBreak({required bool completed}) {
    if (_isClosing || !mounted) return;
    _isClosing = true;
    Navigator.of(context).pop(completed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: WebViewWidget(controller: _controller),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => _closeAdBreak(completed: false),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ),
            if (_isLoading)
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
                    color: Colors.black.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Loading ad…',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
