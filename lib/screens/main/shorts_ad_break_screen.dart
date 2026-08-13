import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class ShortsAdBreakScreen extends StatefulWidget {
  const ShortsAdBreakScreen({
    super.key,
    required this.providerName,
    required this.onPrepare,
    required this.onStartAd,
    this.autoStart = false,
    this.adStartDelay = const Duration(seconds: 6),
    this.minimumVisibleDuration = const Duration(seconds: 10),
  });

  final String providerName;
  final Future<void> Function() onPrepare;
  final Future<bool> Function(BuildContext context) onStartAd;
  final bool autoStart;
  final Duration adStartDelay;
  final Duration minimumVisibleDuration;

  @override
  State<ShortsAdBreakScreen> createState() => _ShortsAdBreakScreenState();
}

class _ShortsAdBreakScreenState extends State<ShortsAdBreakScreen> {
  late final DateTime _openedAt;
  bool _isStartingAd = false;
  bool _didAttemptAd = false;
  bool _allowClose = false;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.onPrepare());
      if (widget.autoStart) {
        unawaited(_startAdFlowAfterDelay());
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _tr(String key) {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    const values = {
      'en': {
        'adReady': 'Ad ready',
        'tapNextAd': 'Tap the button to watch your next ad.',
        'startingAd': 'Starting ad...',
        'continueTitle': 'Watch ad to continue',
        'watchNow': 'Watch ad now',
        'afterThreeShorts':
            'After 3 shorts, the ad only starts when you press this button. When the ad is fully completed, the app continues automatically.',
      },
      'nl': {
        'adReady': 'Ad klaar',
        'tapNextAd': 'Druk op de knop om je volgende advertentie te bekijken.',
        'startingAd': 'Advertentie wordt gestart...',
        'continueTitle': 'Kijk een advertentie om verder te gaan',
        'watchNow': 'Bekijk advertentie',
        'afterThreeShorts':
            'Na 3 shorts start de advertentie alleen wanneer je op deze knop drukt. Als de advertentie volledig is afgerond, gaat de app automatisch verder.',
      },
      'hi': {
        'adReady': 'Ad तैयार',
        'tapNextAd': 'अपना अगला ad देखने के लिए बटन दबाएँ।',
        'startingAd': 'Ad शुरू हो रहा है...',
        'continueTitle': 'जारी रखने के लिए ad देखें',
        'watchNow': 'अभी ad देखें',
        'afterThreeShorts':
            '3 shorts के बाद ad तभी शुरू होगा जब आप इस बटन को दबाएँगे। Ad पूरा होने पर ऐप अपने आप आगे बढ़ेगी।',
      },
      'de': {
        'adReady': 'Ad bereit',
        'tapNextAd': 'Tippe auf die Schaltfläche, um dein nächstes Ad anzusehen.',
        'startingAd': 'Ad wird gestartet...',
        'continueTitle': 'Ad ansehen, um fortzufahren',
        'watchNow': 'Ad jetzt ansehen',
        'afterThreeShorts':
            'Nach 3 Shorts startet das Ad nur, wenn du diese Schaltfläche drückst. Wenn das Ad vollständig abgeschlossen ist, läuft die App automatisch weiter.',
      },
      'es': {
        'adReady': 'Ad listo',
        'tapNextAd': 'Pulsa el botón para ver tu próximo ad.',
        'startingAd': 'Iniciando ad...',
        'continueTitle': 'Mira un ad para continuar',
        'watchNow': 'Ver ad ahora',
        'afterThreeShorts':
            'Después de 3 shorts, el ad solo empieza cuando pulses este botón. Cuando el ad se complete por completo, la app continuará automáticamente.',
      },
      'fr': {
        'adReady': 'Ad prêt',
        'tapNextAd': 'Appuyez sur le bouton pour regarder votre prochain ad.',
        'startingAd': 'Démarrage de l’ad...',
        'continueTitle': 'Regardez un ad pour continuer',
        'watchNow': 'Voir l’ad',
        'afterThreeShorts':
            'Après 3 shorts, l’ad ne démarre que lorsque vous appuyez sur ce bouton. Quand l’ad est entièrement terminé, l’app continue automatiquement.',
      },
      'ru': {
        'adReady': 'Ad готов',
        'tapNextAd': 'Нажмите кнопку, чтобы посмотреть следующий ad.',
        'startingAd': 'Запуск ad...',
        'continueTitle': 'Посмотрите ad, чтобы продолжить',
        'watchNow': 'Смотреть ad',
        'afterThreeShorts':
            'После 3 shorts ad запустится только после нажатия этой кнопки. Когда ad будет полностью завершён, приложение продолжит работу автоматически.',
      },
      'el': {
        'adReady': 'Το ad είναι έτοιμο',
        'tapNextAd': 'Πάτησε το κουμπί για να δεις το επόμενο ad.',
        'startingAd': 'Το ad ξεκινά...',
        'continueTitle': 'Δες ένα ad για να συνεχίσεις',
        'watchNow': 'Δες ad τώρα',
        'afterThreeShorts':
            'Μετά από 3 shorts, το ad ξεκινά μόνο όταν πατήσεις αυτό το κουμπί. Όταν το ad ολοκληρωθεί πλήρως, η εφαρμογή συνεχίζει αυτόματα.',
      },
      'pt': {
        'adReady': 'Ad pronto',
        'tapNextAd': 'Toque no botão para ver o seu próximo ad.',
        'startingAd': 'A iniciar o ad...',
        'continueTitle': 'Veja um ad para continuar',
        'watchNow': 'Ver ad agora',
        'afterThreeShorts':
            'Após 3 shorts, o ad só começa quando tocar neste botão. Quando o ad for concluído por completo, a app continua automaticamente.',
      },
      'it': {
        'adReady': 'Ad pronto',
        'tapNextAd': 'Tocca il pulsante per guardare il tuo prossimo ad.',
        'startingAd': 'Avvio dell’ad...',
        'continueTitle': 'Guarda un ad per continuare',
        'watchNow': 'Guarda ad',
        'afterThreeShorts':
            'Dopo 3 shorts, l’ad parte solo quando premi questo pulsante. Quando l’ad è completato interamente, l’app continua automaticamente.',
      },
      'tr': {
        'adReady': 'Ad hazır',
        'tapNextAd': 'Sonraki ad için düğmeye basın.',
        'startingAd': 'Ad başlatılıyor...',
        'continueTitle': 'Devam etmek için ad izle',
        'watchNow': 'Şimdi ad izle',
        'afterThreeShorts':
            '3 shortstan sonra ad yalnızca bu düğmeye bastığınızda başlar. Ad tamamen tamamlandığında uygulama otomatik olarak devam eder.',
      },
      'ar': {
        'adReady': 'الإعلان جاهز',
        'tapNextAd': 'اضغط الزر لمشاهدة الإعلان التالي.',
        'startingAd': 'جارٍ بدء الإعلان...',
        'continueTitle': 'شاهد إعلانًا للمتابعة',
        'watchNow': 'شاهد الإعلان الآن',
        'afterThreeShorts':
            'بعد 3 shorts لن يبدأ الإعلان إلا عند الضغط على هذا الزر. عند اكتمال الإعلان بالكامل سيواصل التطبيق تلقائيًا.',
      },
      'bn': {
        'adReady': 'Ad প্রস্তুত',
        'tapNextAd': 'পরের ad দেখতে বোতামে চাপ দিন।',
        'startingAd': 'Ad শুরু হচ্ছে...',
        'continueTitle': 'চালিয়ে যেতে একটি ad দেখুন',
        'watchNow': 'এখন ad দেখুন',
        'afterThreeShorts':
            '3টি shorts-এর পরে ad শুধু এই বোতাম চাপলে শুরু হবে। Ad পুরো শেষ হলে অ্যাপ নিজে থেকেই এগোবে।',
      },
      'ta': {
        'adReady': 'Ad தயாராக உள்ளது',
        'tapNextAd': 'அடுத்த ad பார்க்க பட்டனை அழுத்தவும்.',
        'startingAd': 'Ad தொடங்குகிறது...',
        'continueTitle': 'தொடர ஒரு ad பாருங்கள்',
        'watchNow': 'இப்போது ad பார்க்கவும்',
        'afterThreeShorts':
            '3 shorts பிறகு இந்த பட்டனை அழுத்தினால் மட்டுமே ad தொடங்கும். Ad முழுமையாக முடிந்ததும் app தானாகத் தொடரும்.',
      },
      'te': {
        'adReady': 'Ad సిద్ధంగా ఉంది',
        'tapNextAd': 'తర్వాతి ad చూడటానికి బటన్ నొక్కండి.',
        'startingAd': 'Ad ప్రారంభమవుతోంది...',
        'continueTitle': 'కొనసాగడానికి ad చూడండి',
        'watchNow': 'ఇప్పుడే ad చూడండి',
        'afterThreeShorts':
            '3 shorts తర్వాత ఈ బటన్ నొక్కినప్పుడే ad ప్రారంభమవుతుంది. Ad పూర్తిగా ముగిసిన తర్వాత app ఆటోమేటిక్‌గా కొనసాగుతుంది.',
      },
    };
    return values[code]?[key] ?? values['en']![key]!;
  }

  Future<void> _startAdFlow() async {
    if (_isStartingAd) return;
    if (!mounted) return;
    setState(() {
      _didAttemptAd = true;
      _isStartingAd = true;
      _statusText = _tr('startingAd');
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

  Future<void> _startAdFlowAfterDelay() async {
    if (widget.adStartDelay > Duration.zero) {
      await Future<void>.delayed(widget.adStartDelay);
    }
    if (!mounted || _didAttemptAd || _isStartingAd) return;
    await _startAdFlow();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusText = _statusText.isNotEmpty
        ? _statusText
        : widget.autoStart
        ? _tr('startingAd')
        : _tr('tapNextAd');
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
                        size: 18,
                        color: AppTheme.primarySoft,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _tr('adReady'),
                        style: TextStyle(
                          color: AppTheme.primarySoft,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.96, end: 1.04),
                        duration: const Duration(milliseconds: 1100),
                        curve: Curves.easeInOut,
                        builder: (context, scale, child) {
                          return Transform.scale(scale: scale, child: child);
                        },
                        onEnd: () {
                          if (!mounted || _didAttemptAd) return;
                          setState(() {});
                        },
                        child: Container(
                          height: 84,
                          width: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primary.withOpacity(0.12),
                            border: Border.all(
                              color: AppTheme.primary.withOpacity(0.30),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.redeem_rounded,
                            size: 40,
                            color: AppTheme.primarySoft,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _tr('continueTitle'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        statusText,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      if (!widget.autoStart) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isStartingAd ? null : _startAdFlow,
                            icon: Icon(
                              _isStartingAd
                                  ? Icons.hourglass_top_rounded
                                  : Icons.play_circle_fill_rounded,
                            ),
                            label: Text(
                              _isStartingAd ? _tr('startingAd') : _tr('watchNow'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      Text(
                        _tr('afterThreeShorts'),
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
