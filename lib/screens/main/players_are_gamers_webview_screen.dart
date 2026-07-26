import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/earnings_service.dart';
import '../../services/players_are_gamers_service.dart';

class PlayersAreGamersWebViewScreen extends StatefulWidget {
  const PlayersAreGamersWebViewScreen({
    super.key,
    required this.service,
    this.initialUrl,
    this.landscapeOnly = false,
  });

  final PlayersAreGamersService service;
  final String? initialUrl;
  final bool landscapeOnly;

  @override
  State<PlayersAreGamersWebViewScreen> createState() =>
      _PlayersAreGamersWebViewScreenState();
}

class _PlayersAreGamersWebViewScreenState
    extends State<PlayersAreGamersWebViewScreen> {
  late final WebViewController _controller;
  final WebViewCookieManager _cookieManager = WebViewCookieManager();
  final EarningsService _earningsService = EarningsService();
  final Set<String> _processedResultRunIds = <String>{};
  bool _loading = true;
  bool _replayRewardInProgress = false;
  bool _resultRewardInProgress = false;
  bool _sessionRecoveryAttempted = false;
  bool _initialTargetOpened = false;

  @override
  void initState() {
    super.initState();
    if (widget.landscapeOnly) {
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
    }
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
              onPageFinished: (url) async {
                if (_isAutoLoginResponsePage(url)) {
                  await _completeAutoLoginResponse();
                  return;
                }
                await _injectSessionAndReplayBridge();
                if (_shouldOpenInitialTarget(url)) {
                  _initialTargetOpened = true;
                  await _controller.loadRequest(
                    Uri.parse(widget.initialUrl!),
                    headers: const {
                      'Cache-Control': 'no-cache',
                      'Pragma': 'no-cache',
                    },
                  );
                  return;
                }
                if (_looksLikeLoginPage(url) && !_sessionRecoveryAttempted) {
                  _sessionRecoveryAttempted = true;
                  await _bootstrapSession();
                  return;
                }
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

  @override
  void dispose() {
    if (widget.landscapeOnly) {
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
        ]),
      );
    }
    super.dispose();
  }

  Future<void> _bootstrapSession() async {
    try {
      final token = await widget.service.getSessionToken(
        forceRefresh: _sessionRecoveryAttempted,
      );
      if (token == null || token.isEmpty) {
        throw Exception('No PlayersAreGamers session token available.');
      }
      await _cookieManager.clearCookies();
      await _controller.loadRequest(
        Uri.parse(PlayersAreGamersService.autoLoginUrl),
        method: LoadRequestMethod.post,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
        body: Uint8List.fromList(
          utf8.encode(jsonEncode({'token': token})),
        ),
      );
    } catch (_) {
      await _controller.loadRequest(Uri.parse(PlayersAreGamersService.dashboardUrl));
    }
  }

  Future<void> _completeAutoLoginResponse() async {
    try {
      final rawBody = await _controller.runJavaScriptReturningResult(
        '(function() { return document.body ? document.body.innerText : ""; })();',
      );
      final body = _normalizeJavaScriptResult(rawBody).trim();
      final payload =
          body.isEmpty ? <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>;
      final redirectUrl =
          (payload['redirectUrl'] ?? payload['redirect_url'] ?? '').toString().trim();

      if (redirectUrl.isEmpty) {
        if (!_sessionRecoveryAttempted) {
          _sessionRecoveryAttempted = true;
          await _bootstrapSession();
          return;
        }
        await _controller.loadRequest(Uri.parse(PlayersAreGamersService.dashboardUrl));
        return;
      }

      await _controller.loadRequest(
        Uri.parse(redirectUrl),
        headers: const {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      );
    } catch (_) {
      if (!_sessionRecoveryAttempted) {
        _sessionRecoveryAttempted = true;
        await _bootstrapSession();
        return;
      }
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
            location.pathname.endsWith('/index.html');
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

  bool _looksLikeLoginPage(String? url) {
    final value = (url ?? '').toLowerCase();
    return value.contains('/login.php') || value.contains('/index.html');
  }

  bool _isAutoLoginResponsePage(String? url) {
    final value = (url ?? '').toLowerCase();
    return value.contains('/auto-login.php');
  }

  bool _shouldOpenInitialTarget(String? currentUrl) {
    final target = widget.initialUrl;
    if (target == null || target.isEmpty || _initialTargetOpened) {
      return false;
    }
    final current = (currentUrl ?? '').trim();
    if (current.isEmpty) {
      return false;
    }
    if (_isAutoLoginResponsePage(current)) {
      return false;
    }
    if (_looksLikeLoginPage(current)) {
      return false;
    }
    return !_sameUrl(current, target);
  }

  bool _sameUrl(String a, String b) {
    final left = Uri.tryParse(a);
    final right = Uri.tryParse(b);
    if (left == null || right == null) {
      return a == b;
    }
    return left.scheme == right.scheme &&
        left.host == right.host &&
        left.path == right.path &&
        left.query == right.query;
  }

  String _normalizeJavaScriptResult(Object? value) {
    if (value == null) return '';
    final raw = value.toString();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is String) return decoded;
    } catch (_) {}
    return raw;
  }

  Future<void> _handleBridgeMessage(String message) async {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(message) as Map<String, dynamic>;
    } catch (_) {
      payload = <String, dynamic>{};
    }

    final type = payload['type']?.toString();
    if (type == 'playAgainRequested') {
      if (_replayRewardInProgress) {
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
        await widget.service.grantReplayReward(
          adId: replayId,
          gameCoins: 2,
          videomoneyViews: 3,
        );
        await _controller.runJavaScript('window.__vmResumePlayAgain && window.__vmResumePlayAgain();');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reward granted: +3 views. Starting a new game...',
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
      return;
    }

    if (type == 'vmGameResultShown') {
      await _handleGameResultShown(payload);
    }
  }

  Future<void> _handleGameResultShown(Map<String, dynamic> payload) async {
    if (_resultRewardInProgress) return;

    final runId =
        payload['runId']?.toString().trim().isNotEmpty == true
            ? payload['runId'].toString().trim()
            : 'pag-result-${DateTime.now().millisecondsSinceEpoch}';
    if (_processedResultRunIds.contains(runId)) {
      return;
    }

    _resultRewardInProgress = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You need to be signed in.');
      }

      final rewarded = await _earningsService.showRewardedBonusAd(
        provider: RewardedAdProvider.admob,
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

      final gameId =
          payload['gameId']?.toString().trim().isNotEmpty == true
              ? payload['gameId'].toString().trim()
              : 'unknown-game';
      await widget.service.grantAdReward(
        adId: 'pag-result-$gameId-$runId',
        pagCoins: 2,
        videomoneyViews: 3,
        videomoneyVideosWatched: 1,
        autoCreateIfMissing: true,
      );
      _processedResultRunIds.add(runId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reward granted: +3 views.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      _resultRewardInProgress = false;
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
