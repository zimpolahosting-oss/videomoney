import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_user.dart';
import '../../services/earnings_service.dart';
import '../../services/firestore_service.dart';
import '../../services/players_are_gamers_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/watermark_hero_card.dart';
import 'shorts_ad_break_screen.dart';

class EarnScreen extends StatefulWidget {
  const EarnScreen({super.key});

  @override
  State<EarnScreen> createState() => _EarnScreenState();
}

class _EarnScreenState extends State<EarnScreen> {
  final _firestoreService = FirestoreService();
  final _earningsService = EarningsService();
  final _playersAreGamersService = PlayersAreGamersService();
  bool _isLoading = false;

  String _localizedEarnText(String key) {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    const values = {
      'en': {
        'earn_ads': 'Earn ads',
        'watch_rewarded':
            'Watch a rewarded ad to count 1 ad toward your payout.',
        'earn_step': '1 ad counted',
        'ads_only': 'Ads only',
        'completed_ads': 'Only fully completed ads count toward your balance.',
        'balance': 'Balance',
        'reward_confirmed': 'Reward confirmed. +1 ad counted.',
      },
      'nl': {
        'earn_ads': 'Verdien ads',
        'watch_rewarded':
            'Kijk een rewarded advertentie om 1 ad te tellen voor je uitbetaling.',
        'earn_step': '1 ad telt mee',
        'ads_only': 'Alleen ads',
        'completed_ads':
            'Alleen volledig bekeken advertenties tellen mee voor je saldo.',
        'balance': 'Saldo',
        'reward_confirmed': 'Beloning bevestigd. +1 ad geteld.',
      },
      'hi': {
        'earn_ads': 'Ads कमाएँ',
        'watch_rewarded':
            'अपनी payout के लिए 1 ad गिनने हेतु rewarded ad देखें।',
        'earn_step': '1 ad गिना गया',
        'ads_only': 'सिर्फ ads',
        'completed_ads': 'केवल पूरी तरह देखे गए ads ही आपके बैलेंस में गिने जाते हैं।',
        'balance': 'बैलेंस',
        'reward_confirmed': 'रिवॉर्ड पुष्टि हुई। +1 ad गिना गया।',
      },
      'de': {
        'earn_ads': 'Ads verdienen',
        'watch_rewarded':
            'Sieh dir ein Rewarded Ad an, damit 1 Ad für deine Auszahlung zählt.',
        'earn_step': '1 Ad gezählt',
        'ads_only': 'Nur Ads',
        'completed_ads':
            'Nur vollständig angesehene Ads zählen für dein Guthaben.',
        'balance': 'Guthaben',
        'reward_confirmed': 'Belohnung bestätigt. +1 Ad gezählt.',
      },
      'es': {
        'earn_ads': 'Gana ads',
        'watch_rewarded':
            'Mira un ad recompensado para contar 1 ad hacia tu pago.',
        'earn_step': '1 ad contado',
        'ads_only': 'Solo ads',
        'completed_ads':
            'Solo los ads completados por completo cuentan para tu saldo.',
        'balance': 'Saldo',
        'reward_confirmed': 'Recompensa confirmada. +1 ad contado.',
      },
      'fr': {
        'earn_ads': 'Gagner des ads',
        'watch_rewarded':
            'Regardez un ad récompensé pour compter 1 ad vers votre paiement.',
        'earn_step': '1 ad compté',
        'ads_only': 'Ads uniquement',
        'completed_ads':
            'Seuls les ads entièrement terminés comptent pour votre solde.',
        'balance': 'Solde',
        'reward_confirmed': 'Récompense confirmée. +1 ad compté.',
      },
      'ru': {
        'earn_ads': 'Зарабатывайте ads',
        'watch_rewarded':
            'Смотрите rewarded ad, чтобы 1 ad засчитался к выплате.',
        'earn_step': '1 ad засчитан',
        'ads_only': 'Только ads',
        'completed_ads':
            'Только полностью завершённые ads засчитываются в ваш баланс.',
        'balance': 'Баланс',
        'reward_confirmed': 'Награда подтверждена. +1 ad засчитан.',
      },
      'el': {
        'earn_ads': 'Κέρδισε ads',
        'watch_rewarded':
            'Δες ένα rewarded ad ώστε να μετρήσει 1 ad για την πληρωμή σου.',
        'earn_step': '1 ad μετρήθηκε',
        'ads_only': 'Μόνο ads',
        'completed_ads':
            'Μόνο τα ads που ολοκληρώνονται πλήρως μετρούν στο υπόλοιπό σου.',
        'balance': 'Υπόλοιπο',
        'reward_confirmed': 'Η ανταμοιβή επιβεβαιώθηκε. +1 ad μετρήθηκε.',
      },
      'pt': {
        'earn_ads': 'Ganhar ads',
        'watch_rewarded':
            'Veja um ad recompensado para contar 1 ad para o seu pagamento.',
        'earn_step': '1 ad contado',
        'ads_only': 'Só ads',
        'completed_ads':
            'Apenas os ads totalmente concluídos contam para o seu saldo.',
        'balance': 'Saldo',
        'reward_confirmed': 'Recompensa confirmada. +1 ad contado.',
      },
      'it': {
        'earn_ads': 'Guadagna ads',
        'watch_rewarded':
            'Guarda un ad rewarded per contare 1 ad verso il tuo pagamento.',
        'earn_step': '1 ad conteggiato',
        'ads_only': 'Solo ads',
        'completed_ads':
            'Solo gli ads completati interamente contano per il tuo saldo.',
        'balance': 'Saldo',
        'reward_confirmed': 'Ricompensa confermata. +1 ad conteggiato.',
      },
      'tr': {
        'earn_ads': 'Ads kazan',
        'watch_rewarded':
            'Ödemeniz için 1 ad sayılması adına rewarded ad izleyin.',
        'earn_step': '1 ad sayıldı',
        'ads_only': 'Sadece ads',
        'completed_ads':
            'Yalnızca tamamen tamamlanan ads bakiyenize sayılır.',
        'balance': 'Bakiye',
        'reward_confirmed': 'Ödül onaylandı. +1 ad sayıldı.',
      },
      'ar': {
        'earn_ads': 'اكسب ads',
        'watch_rewarded':
            'شاهد ad بمكافأة ليتم احتساب 1 ad نحو دفعتك.',
        'earn_step': 'تم احتساب 1 ad',
        'ads_only': 'ads فقط',
        'completed_ads':
            'فقط ads المكتملة بالكامل تُحتسب في رصيدك.',
        'balance': 'الرصيد',
        'reward_confirmed': 'تم تأكيد المكافأة. تم احتساب +1 ad.',
      },
      'bn': {
        'earn_ads': 'Ads আয় করুন',
        'watch_rewarded':
            'আপনার payout-এর জন্য 1 ad গণনা করতে একটি rewarded ad দেখুন।',
        'earn_step': '1 ad গণনা হয়েছে',
        'ads_only': 'শুধু ads',
        'completed_ads':
            'শুধু পুরোপুরি দেখা ads-ই আপনার ব্যালেন্সে গণনা হবে।',
        'balance': 'ব্যালেন্স',
        'reward_confirmed': 'রিওয়ার্ড নিশ্চিত। +1 ad গণনা হয়েছে।',
      },
      'ta': {
        'earn_ads': 'Ads சம்பாதிக்கவும்',
        'watch_rewarded':
            'உங்கள் payout-க்கு 1 ad சேர்க்க rewarded ad பாருங்கள்.',
        'earn_step': '1 ad எண்ணப்பட்டது',
        'ads_only': 'Ads மட்டும்',
        'completed_ads':
            'முழுமையாக முடிக்கப்பட்ட ads மட்டுமே உங்கள் இருப்பில் சேரும்.',
        'balance': 'இருப்பு',
        'reward_confirmed': 'வெகுமதி உறுதிசெய்யப்பட்டது. +1 ad எண்ணப்பட்டது.',
      },
      'te': {
        'earn_ads': 'Ads సంపాదించండి',
        'watch_rewarded':
            'మీ payout కోసం 1 ad లెక్కించబడేందుకు rewarded ad చూడండి.',
        'earn_step': '1 ad లెక్కించబడింది',
        'ads_only': 'Ads మాత్రమే',
        'completed_ads':
            'పూర్తిగా ముగిసిన ads మాత్రమే మీ బ్యాలెన్స్‌లో లెక్కించబడతాయి.',
        'balance': 'బ్యాలెన్స్',
        'reward_confirmed': 'రివార్డ్ నిర్ధారించబడింది. +1 ad లెక్కించబడింది.',
      },
    };
    return values[code]?[key] ?? values['en']![key]!;
  }

  @override
  void initState() {
    super.initState();
    _earningsService.preloadRewardedVideo();
  }

  Future<void> _watchVideo() async {
    final l10n = context.l10n;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isLoading) return;

    setState(() => _isLoading = true);
    String? lastStatusMessage;

    final rewardGranted =
        await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            fullscreenDialog: false,
            builder: (pageContext) => ShortsAdBreakScreen(
              providerName: 'Rewarded ad',
              onPrepare: () async {},
              onStartAd: (_, __) {
                return _earningsService.watchRewardedVideo(
                  uid: user.uid,
                  onAdStatus: (message) {
                    lastStatusMessage = message;
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  },
                );
              },
            ),
          ),
        ) ??
        false;

    if (!mounted) return;

    if (rewardGranted) {
      await _playersAreGamersService.grantAdReward(
        adId: 'vm-earn-ad-${DateTime.now().millisecondsSinceEpoch}',
        pagCoins: 2,
        videomoneyViews: 0,
        autoCreateIfMissing: true,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _localizedEarnText('reward_confirmed'),
          ),
        ),
      );
    } else if (lastStatusMessage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.rewardedAdNotCompleted)),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(child: Text(l10n.noUserSessionFound)),
      );
    }

    return StreamBuilder<AppUser?>(
      stream: _firestoreService.watchUser(user.uid),
      builder: (context, snapshot) {
        final appUser = snapshot.data;
        final totalVideos = appUser?.videosWatched ?? 0;
        final todayKey = FirestoreService.formatLocalDateKey(DateTime.now());
        final dailyCount = (appUser?.dailyProgressDate == todayKey)
            ? (appUser?.dailyVideosWatched ?? 0)
            : 0;
        final dailyProgress = (dailyCount / FirestoreService.dailyBonusTargetVideos)
            .clamp(0, 1)
            .toDouble();

        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                _TopTitle(title: l10n.earn),
                const SizedBox(height: 14),
                SizedBox(
                  height: 214,
                  child: WatermarkHeroCard(
                    imageAsset: 'assets/illustrations/earn_phone.jpg',
                    imageOpacity: 0.17,
                    imageScale: 1.36,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'VideoMoney',
                                style: TextStyle(
                                  color: AppTheme.primarySoft,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.of(context).pushNamed(AppRoutes.about);
                              },
                              icon: const Icon(
                                Icons.info_outline_rounded,
                                color: AppTheme.primarySoft,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 230),
                          child: Text(
                            _localizedEarnText('earn_ads'),
                            style: Theme.of(context).textTheme.headlineMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 235),
                          child: Text(
                            _localizedEarnText('watch_rewarded'),
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isLoading ? null : _watchVideo,
                            icon: Icon(
                              _isLoading
                                  ? Icons.hourglass_top_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            label: Text(
                              _isLoading ? l10n.loading : l10n.watchVideo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.howItWorks,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 14,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          SizedBox(
                            width: 92,
                            child: _HowStep(
                              icon: Icons.play_circle_outline,
                              title: l10n.watch,
                              subtitle: l10n.watchVideo,
                            ),
                          ),
                          SizedBox(
                            width: 92,
                            child: _HowStep(
                              icon: Icons.visibility_outlined,
                              title: l10n.earnStep,
                              subtitle: _localizedEarnText('earn_step'),
                            ),
                          ),
                          SizedBox(
                            width: 92,
                            child: _HowStep(
                              icon: Icons.account_balance_wallet_outlined,
                              title: l10n.cashOut,
                              subtitle: '${FirestoreService.minimumPayoutCoins} ads',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.emoji_events_outlined,
                              color: AppTheme.primarySoft),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.dailyChallenge,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: AppTheme.primary.withOpacity(0.12),
                              border: Border.all(
                                color: AppTheme.primary.withOpacity(0.28),
                              ),
                            ),
                            child: Text(
                              _localizedEarnText('ads_only'),
                              style: const TextStyle(
                                color: AppTheme.primarySoft,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _localizedEarnText('completed_ads'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${appUser?.views ?? 0} / ${FirestoreService.minimumPayoutCoins} ads',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            _localizedEarnText('balance'),
                            style: const TextStyle(color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: ((appUser?.views ?? 0) / FirestoreService.minimumPayoutCoins)
                              .clamp(0, 1)
                              .toDouble(),
                          backgroundColor: Colors.white.withOpacity(0.08),
                          valueColor:
                              const AlwaysStoppedAnimation(AppTheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.ondemand_video_outlined,
                          color: AppTheme.primarySoft),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.totalVideosWatched,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        NumberFormat.decimalPattern().format(totalVideos),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopTitle extends StatelessWidget {
  const _TopTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _HowStep extends StatelessWidget {
  const _HowStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primary.withOpacity(0.12),
            border: Border.all(color: AppTheme.primary.withOpacity(0.22)),
          ),
          child: Icon(icon, color: AppTheme.primarySoft),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
