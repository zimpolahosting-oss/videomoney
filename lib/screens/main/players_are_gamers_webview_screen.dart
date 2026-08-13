import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/earnings_service.dart';
import '../../services/players_are_gamers_service.dart';
import '../../services/rewarded_ad_service.dart';

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

  String _localizedRewardMessage({required bool startingGame}) {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    final values = {
      'en': startingGame
          ? 'Reward granted: +1 ad. Starting a new game...'
          : 'Reward granted: +1 ad.'
      ,
      'nl': startingGame
          ? 'Beloning gegeven: +1 ad. Nieuw spel wordt gestart...'
          : 'Beloning gegeven: +1 ad.',
      'hi': startingGame
          ? 'रिवॉर्ड दिया गया: +1 ad. नया गेम शुरू हो रहा है...'
          : 'रिवॉर्ड दिया गया: +1 ad.',
      'de': startingGame
          ? 'Belohnung erhalten: +1 Ad. Neues Spiel wird gestartet...'
          : 'Belohnung erhalten: +1 Ad.',
      'es': startingGame
          ? 'Recompensa otorgada: +1 ad. Iniciando un nuevo juego...'
          : 'Recompensa otorgada: +1 ad.',
      'fr': startingGame
          ? 'Récompense accordée : +1 ad. Lancement d’un nouveau jeu...'
          : 'Récompense accordée : +1 ad.',
      'ru': startingGame
          ? 'Награда получена: +1 ad. Запуск новой игры...'
          : 'Награда получена: +1 ad.',
      'el': startingGame
          ? 'Η ανταμοιβή δόθηκε: +1 ad. Ξεκινά νέο παιχνίδι...'
          : 'Η ανταμοιβή δόθηκε: +1 ad.',
      'pt': startingGame
          ? 'Recompensa atribuída: +1 ad. A iniciar um novo jogo...'
          : 'Recompensa atribuída: +1 ad.',
      'it': startingGame
          ? 'Ricompensa assegnata: +1 ad. Avvio di un nuovo gioco...'
          : 'Ricompensa assegnata: +1 ad.',
      'tr': startingGame
          ? 'Ödül verildi: +1 ad. Yeni oyun başlıyor...'
          : 'Ödül verildi: +1 ad.',
      'ar': startingGame
          ? 'تم منح المكافأة: +1 ad. جارٍ بدء لعبة جديدة...'
          : 'تم منح المكافأة: +1 ad.',
      'bn': startingGame
          ? 'রিওয়ার্ড দেওয়া হয়েছে: +1 ad। নতুন গেম শুরু হচ্ছে...'
          : 'রিওয়ার্ড দেওয়া হয়েছে: +1 ad।',
      'ta': startingGame
          ? 'வெகுமதி வழங்கப்பட்டது: +1 ad. புதிய விளையாட்டு தொடங்குகிறது...'
          : 'வெகுமதி வழங்கப்பட்டது: +1 ad.',
      'te': startingGame
          ? 'రివార్డ్ ఇచ్చబడింది: +1 ad. కొత్త గేమ్ ప్రారంభమవుతోంది...'
          : 'రివార్డ్ ఇచ్చబడింది: +1 ad.',
    };
    return values[code] ?? values['en']!;
  }

  String _localizedRewardSyncFailedMessage() {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    final values = {
      'en': 'Ad finished, but +1 ad could not be added. Please try again.',
      'nl': 'Advertentie klaar, maar +1 ad kon niet worden toegevoegd. Probeer opnieuw.',
      'hi': 'Ad पूरा हुआ, लेकिन +1 ad नहीं जोड़ा जा सका। फिर से प्रयास करें।',
      'de': 'Das Ad wurde beendet, aber +1 Ad konnte nicht hinzugefügt werden. Bitte erneut versuchen.',
      'es': 'El ad terminó, pero no se pudo añadir +1 ad. Inténtalo de nuevo.',
      'fr': 'L’ad est terminé, mais +1 ad n’a pas pu être ajouté. Réessayez.',
      'ru': 'Ad завершён, но +1 ad не удалось добавить. Попробуйте ещё раз.',
      'el': 'Το ad ολοκληρώθηκε, αλλά το +1 ad δεν μπόρεσε να προστεθεί. Δοκιμάστε ξανά.',
      'pt': 'O ad terminou, mas não foi possível adicionar +1 ad. Tente novamente.',
      'it': 'L’ad è terminato, ma non è stato possibile aggiungere +1 ad. Riprova.',
      'tr': 'Ad tamamlandı ancak +1 ad eklenemedi. Lütfen tekrar deneyin.',
      'ar': 'اكتمل الإعلان، لكن تعذر إضافة +1 ad. حاول مرة أخرى.',
      'bn': 'Ad শেষ হয়েছে, কিন্তু +1 ad যোগ করা যায়নি। আবার চেষ্টা করুন।',
      'ta': 'Ad முடிந்தது, ஆனால் +1 ad சேர்க்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
      'te': 'Ad పూర్తైంది, కానీ +1 ad జోడించలేకపోయాం. మళ్లీ ప్రయత్నించండి.',
    };
    return values[code] ?? values['en']!;
  }
  bool _resultRewardInProgress = false;
  bool _sessionRecoveryAttempted = false;
  bool _initialTargetOpened = false;

  @override
  void initState() {
    super.initState();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
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
                await _injectGameSpecificFixes(url);
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
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
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

  Future<void> _injectGameSpecificFixes(String? url) async {
    final current = (url ?? '').toLowerCase();
    if (!current.contains('/stone-pile/')) {
      return;
    }
    await _controller.runJavaScript('''
      (function() {
        try {
          if (window.__vmStonePileFrameCapInstalled) {
            return;
          }
          window.__vmStonePileFrameCapInstalled = true;
          const nativeRAF = window.requestAnimationFrame.bind(window);
          const nativeCAF = window.cancelAnimationFrame.bind(window);
          const activeHandles = new Map();
          let nextHandle = 1;
          let lastFrameTs = 0;
          const minFrameMs = 1000 / 60;

          window.requestAnimationFrame = function(callback) {
            const handle = nextHandle++;
            function run(ts) {
              if (!activeHandles.has(handle)) {
                return;
              }
              if (lastFrameTs === 0 || (ts - lastFrameTs) >= minFrameMs) {
                lastFrameTs = ts;
                activeHandles.delete(handle);
                callback(ts);
                return;
              }
              const rafId = nativeRAF(run);
              activeHandles.set(handle, rafId);
            }
            const rafId = nativeRAF(run);
            activeHandles.set(handle, rafId);
            return handle;
          };

          window.cancelAnimationFrame = function(handle) {
            const rafId = activeHandles.get(handle);
            if (rafId != null) {
              nativeCAF(rafId);
              activeHandles.delete(handle);
            }
          };
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
          videomoneyViews: 1,
        );
        await _controller.runJavaScript('window.__vmResumePlayAgain && window.__vmResumePlayAgain();');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _localizedRewardMessage(startingGame: true),
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
      final rewardResult = await widget.service.grantAdReward(
        adId: 'pag-result-$gameId-$runId',
        pagCoins: 2,
        videomoneyViews: 1,
        videomoneyVideosWatched: 1,
        autoCreateIfMissing: true,
      );
      if (!rewardResult.videomoneyRewardGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localizedRewardSyncFailedMessage()),
          ),
        );
        return;
      }
      _processedResultRunIds.add(runId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _localizedRewardMessage(startingGame: false),
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
      body: Stack(
        children: [
          Positioned.fill(
            child: WebViewWidget(controller: _controller),
          ),
          if (_loading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.42),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    tooltip: 'Back',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
