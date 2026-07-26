import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/earnings_service.dart';
import '../../services/players_are_gamers_service.dart';

class PlayersAreGamersWebViewScreen extends StatefulWidget {
  const PlayersAreGamersWebViewScreen({
    super.key,
    required this.service,
  });

  final PlayersAreGamersService service;

  @override
  State<PlayersAreGamersWebViewScreen> createState() =>
      _PlayersAreGamersWebViewScreenState();
}

class _PlayersAreGamersWebViewScreenState
    extends State<PlayersAreGamersWebViewScreen> {
  late final WebViewController _controller;
  final WebViewCookieManager _cookieManager = WebViewCookieManager();
  final EarningsService _earningsService = EarningsService();
  bool _loading = true;
  bool _replayRewardInProgress = false;

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (_) {
                if (!mounted) return;
                setState(() {
                  _loading = true;
                });
              },
              onPageFinished: (_) async {
                await _injectSessionAndReplayBridge();
                if (!mounted) return;
                setState(() {
                  _loading = false;
                });
              },
            ),
          )
          ..addJavaScriptChannel(
            'PlayersAreGamersBridge',
            onMessageReceived: (message) {
              unawaited(_handleBridgeMessage(message.message));
            },
          );
    unawaited(_bootstrapSession());
  }

  Future<void> _bootstrapSession() async {
    try {
      final launchContext = await widget.service.buildLaunchContext();
      final targetUrl =
          launchContext?.redirectUrl ?? PlayersAreGamersService.dashboardUrl;
      for (final cookie in launchContext?.cookies ?? const []) {
        await _cookieManager.setCookie(
          WebViewCookie(
            name: cookie.name,
            value: cookie.value,
            domain: cookie.domain,
            path: cookie.path,
          ),
        );
      }
      await _controller.loadRequest(Uri.parse(targetUrl));
    } catch (_) {
      await _controller.loadRequest(Uri.parse(PlayersAreGamersService.dashboardUrl));
    }
  }

  Future<void> _injectSessionAndReplayBridge() async {
    final session = await widget.service.getStoredSession();
    if (session == null) return;
    final encodedToken = jsonEncode(session.token);
    final encodedUser = jsonEncode(session.userJson);
    await _controller.runJavaScript('''
      (function() {
        try {
          localStorage.setItem('token', $encodedToken);
          localStorage.setItem('user', $encodedUser);
          if (!window.__vmReplayHookInstalled) {
            window.__vmReplayHookInstalled = true;
            window.__vmReplayBypass = false;
            window.__vmReplayPending = null;
            window.__vmReplayHref = null;
            window.__vmReplayText = null;
            document.addEventListener('click', function(event) {
              const target = event.target && event.target.closest
                ? event.target.closest('button, a, [role="button"]')
                : null;
              if (!target || window.__vmReplayBypass) {
                return;
              }
              const text = (target.innerText || target.textContent || '').trim().toLowerCase();
              if (!text.includes('play again')) {
                return;
              }
              event.preventDefault();
              event.stopPropagation();
              const replayId = String(Date.now());
              target.setAttribute('data-vm-replay-id', replayId);
              window.__vmReplayPending = replayId;
              window.__vmReplayHref = target.href || null;
              window.__vmReplayText = text;
              PlayersAreGamersBridge.postMessage(JSON.stringify({
                type: 'playAgainRequested',
                replayId: replayId,
                href: window.__vmReplayHref
              }));
            }, true);

            window.__vmResumePlayAgain = function() {
              const replayId = window.__vmReplayPending;
              const href = window.__vmReplayHref;
              const target = replayId
                ? document.querySelector('[data-vm-replay-id="' + replayId + '"]')
                : null;
              window.__vmReplayBypass = true;
              try {
                if (target) {
                  if (href) {
                    window.location.href = href;
                  } else {
                    target.click();
                  }
                } else if (href) {
                  window.location.href = href;
                }
              } finally {
                setTimeout(function() {
                  window.__vmReplayBypass = false;
                  window.__vmReplayPending = null;
                  window.__vmReplayHref = null;
                  window.__vmReplayText = null;
                }, 500);
              }
            };
          }

          const needsDashboardRedirect =
            location.pathname.endsWith('/login.php') ||
            location.pathname.endsWith('/index.html') ||
            (document.body && document.body.innerText && document.body.innerText.includes('Please login to continue.'));
          if (needsDashboardRedirect && localStorage.getItem('token')) {
            const nextUrl = '/dashboard.php?vmSession=' + Date.now();
            if (!window.__vmLastRedirect || window.__vmLastRedirect !== nextUrl) {
              window.__vmLastRedirect = nextUrl;
              window.location.replace(nextUrl);
            }
          }
        } catch (_) {}
      })();
    ''');
  }

  Future<void> _handleBridgeMessage(String message) async {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(message) as Map<String, dynamic>;
    } catch (_) {
      payload = <String, dynamic>{};
    }

    if (payload['type'] != 'playAgainRequested' || _replayRewardInProgress) {
      return;
    }

    _replayRewardInProgress = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You need to be signed in.');
      }
      final replayId =
          payload['replayId']?.toString().trim().isNotEmpty == true
              ? payload['replayId'].toString().trim()
              : 'pag-replay-${DateTime.now().millisecondsSinceEpoch}';
      final rewarded = await _earningsService.showRewardedBonusAd(
        onAdStatus: (message) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        },
      );
      if (!rewarded) {
        return;
      }
      final rewardResult = await widget.service.grantReplayReward(
        adId: replayId,
        gameCoins: 2,
        videomoneyViews: 3,
      );
      await _controller.runJavaScript('window.__vmResumePlayAgain && window.__vmResumePlayAgain();');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            rewardResult.pagCoinsGranted
                ? 'Reward granted: +2 game coins and +3 views. Starting a new game...'
                : 'Views granted. PAG coins could not be added right now, but the next game is starting.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
        ),
      );
    } finally {
      _replayRewardInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PlayersAreGamers'),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
