import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MonetagAdBreakScreen extends StatefulWidget {
  const MonetagAdBreakScreen({
    super.key,
    required this.url,
  });

  final String url;

  @override
  State<MonetagAdBreakScreen> createState() => _MonetagAdBreakScreenState();
}

class _MonetagAdBreakScreenState extends State<MonetagAdBreakScreen>
    with WidgetsBindingObserver {
  bool _isClosing = false;
  bool _isOpening = true;
  bool _browserOpened = false;
  DateTime? _browserOpenedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.delayed(const Duration(milliseconds: 300), _openAdInAppBrowser);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_browserOpened) {
      return;
    }
    final openedAt = _browserOpenedAt;
    final wasOpenLongEnough =
        openedAt != null &&
        DateTime.now().difference(openedAt) >= const Duration(seconds: 1);
    if (wasOpenLongEnough) {
      _closeAdBreak(completed: true);
    }
  }

  Future<void> _openAdInAppBrowser() async {
    if (_browserOpened || _isClosing || !mounted) return;
    final uri = Uri.parse(widget.url);
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
    setState(() {
      _isOpening = false;
      _browserOpened = launched;
      _browserOpenedAt = launched ? DateTime.now() : null;
    });
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the in-app browser.'),
        ),
      );
    }
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
              child: Container(color: Colors.black),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ad break',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'The ad opens in the in-app browser. After viewing it, come back to VideoMoney to continue watching shorts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _browserOpened ? null : _openAdInAppBrowser,
                        child: Text(_browserOpened ? 'Ad opened' : 'Open ad'),
                      ),
                    ),
                  ],
                ),
              ),
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
                          'Opening in-app browser…',
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
