import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../services/firestore_service.dart';
import '../../services/players_are_gamers_service.dart';
import '../../services/presence_service.dart';
import '../../theme/app_theme.dart';
import 'games_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const String _lastSeenPayoutNotificationKey =
      'last_seen_payout_notification_id';
  static const String _introSeenKey = 'fullscreen_intro_seen_v1';
  static const Duration _secondaryTabWarmupDelay = Duration(seconds: 3);

  final FirestoreService _firestoreService = FirestoreService();
  final PlayersAreGamersService _playersAreGamersService = PlayersAreGamersService();
  late final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _homeReady = false;
  final Set<int> _visitedTabs = <int>{0};
  final Set<int> _readyTabs = <int>{0};
  final Map<int, Timer> _tabWarmupTimers = <int, Timer>{};
  int _homeTabRecoveryToken = 0;
  bool _hasHandledFirstResume = false;
  bool _resumeNoticeVisible = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _payoutNotificationSubscription;
  String? _lastSeenPayoutNotificationId;
  bool _isInForeground = true;
  Timer? _homeStartupTimer;
  Timer? _presenceStartupTimer;
  Timer? _notificationsStartupTimer;
  Timer? _pagSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _homeStartupTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _homeReady = true;
      });
    });
    _presenceStartupTimer = Timer(const Duration(seconds: 12), () {
      _startPresence();
    });
    _notificationsStartupTimer = Timer(const Duration(seconds: 14), () {
      unawaited(_initializePayoutNotifications());
    });
    _pagSyncTimer = Timer(const Duration(seconds: 16), () {
      unawaited(_syncPlayersAreGamersProfile());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowFullscreenIntro());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _payoutNotificationSubscription?.cancel();
    _homeStartupTimer?.cancel();
    _presenceStartupTimer?.cancel();
    _notificationsStartupTimer?.cancel();
    _pagSyncTimer?.cancel();
    _pageController.dispose();
    for (final timer in _tabWarmupTimers.values) {
      timer.cancel();
    }
    _tabWarmupTimers.clear();
    unawaited(PresenceService.instance.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        final returningFromBackground = !_isInForeground;
        _isInForeground = true;
        if (!_hasHandledFirstResume) {
          _hasHandledFirstResume = true;
        } else if (returningFromBackground) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_showResumeNotice());
          });
        }
        _startPresence();
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _isInForeground = false;
        unawaited(PresenceService.instance.stop());
        break;
    }
  }

  Future<void> _initializePayoutNotifications() async {
    await _restoreLastSeenPayoutNotification();
    if (!mounted) return;
    _listenForPayoutNotifications();
  }

  Future<void> _restoreLastSeenPayoutNotification() async {
    final prefs = await SharedPreferences.getInstance();
    _lastSeenPayoutNotificationId =
        prefs.getString(_lastSeenPayoutNotificationKey);
  }

  Future<void> _storeLastSeenPayoutNotification(String notificationId) async {
    _lastSeenPayoutNotificationId = notificationId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSeenPayoutNotificationKey, notificationId);
  }

  void _startPresence() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    if (!_isInForeground || uid == null) {
      return;
    }
    unawaited(PresenceService.instance.start(uid: uid));
  }

  Future<void> _syncPlayersAreGamersProfile() async {
    try {
      await _playersAreGamersService.refreshProfile(includeStats: false);
    } catch (_) {}
  }

  Future<void> _maybeShowFullscreenIntro() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadySeen = prefs.getBool(_introSeenKey) ?? false;
    if (alreadySeen || !mounted) return;

    final copy = _FullscreenIntroCopy.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: const Color(0x331AE47A)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2200FF88),
                  blurRadius: 28,
                  spreadRadius: -12,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  copy.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                _IntroRow(
                  icon: Icons.swipe_left_alt_rounded,
                  title: copy.pagesTitle,
                  message: copy.pagesBody,
                ),
                const SizedBox(height: 12),
                _IntroRow(
                  icon: Icons.swap_vert_rounded,
                  title: copy.videosTitle,
                  message: copy.videosBody,
                ),
                const SizedBox(height: 12),
                _IntroRow(
                  icon: Icons.splitscreen_rounded,
                  title: copy.splitTitle,
                  message: copy.splitBody,
                ),
                const SizedBox(height: 12),
                _IntroRow(
                  icon: Icons.visibility_outlined,
                  title: copy.rulesTitle,
                  message: copy.rulesBody,
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(copy.closeLabel),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    await prefs.setBool(_introSeenKey, true);
  }

  Future<void> _showResumeNotice() async {
    if (!mounted || _resumeNoticeVisible) return;
    _resumeNoticeVisible = true;
    final copy = _ResumeNoticeCopy.of(context);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(copy.title),
            content: Text(copy.body),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(copy.closeLabel),
              ),
            ],
          );
        },
      );
    } finally {
      _resumeNoticeVisible = false;
    }
  }

  void _listenForPayoutNotifications() {
    _payoutNotificationSubscription?.cancel();
    _payoutNotificationSubscription = _firestoreService
        .watchLatestPayoutLiveNotifications()
        .listen((snapshot) {
      if (!mounted || snapshot.docs.isEmpty) return;

      final doc = snapshot.docs.first;
      if (_lastSeenPayoutNotificationId == null) {
        unawaited(_storeLastSeenPayoutNotification(doc.id));
        return;
      }
      if (doc.id == _lastSeenPayoutNotificationId) return;

      final data = doc.data();
      final message = (data['message'] as String? ?? '').trim();
      if (message.isEmpty) return;

      unawaited(_storeLastSeenPayoutNotification(doc.id));
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 94),
        ),
      );
    });
  }

  void _openTab(int index, {bool animate = false}) {
    final previousIndex = _currentIndex;
    setState(() {
      _currentIndex = index;
      _visitedTabs.add(index);
      if (index == 0 && previousIndex != 0) {
        _homeTabRecoveryToken++;
      }
    });
    if (index == 0 || _readyTabs.contains(index) || _tabWarmupTimers.containsKey(index)) {
      if (animate && _pageController.hasClients) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    _tabWarmupTimers[index] = Timer(_secondaryTabWarmupDelay, () {
      _tabWarmupTimers.remove(index);
      if (!mounted) return;
      setState(() {
        _readyTabs.add(index);
      });
    });
    if (animate && _pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => _openTab(index),
        children: [
          _buildTab(index: 0),
          _buildTab(index: 1),
          _buildTab(index: 2),
          _buildTab(index: 3),
        ],
      ),
    );
  }

  Widget _buildTab({required int index}) {
    if (!_visitedTabs.contains(index) && index != 0) {
      return _TabStartupPlaceholder(index: index);
    }

    return switch (index) {
      0 => _homeReady
          ? HomeScreen(
              isActiveTab: _currentIndex == 0,
              recoveryToken: _homeTabRecoveryToken,
            )
          : const _HomeStartupPlaceholder(),
      1 || 2 || 3 => _readyTabs.contains(index)
          ? switch (index) {
              1 => const GamesScreen(),
              2 => const WalletScreen(),
              3 => const ProfileScreen(),
              _ => const SizedBox.shrink(),
            }
          : _TabStartupPlaceholder(index: index),
      _ => const SizedBox.shrink(),
    };
  }
}

class _HomeStartupPlaceholder extends StatelessWidget {
  const _HomeStartupPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _TabStartupPlaceholder extends StatelessWidget {
  const _TabStartupPlaceholder({
    required this.index,
  });

  final int index;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (index) {
      1 => 'Games',
      2 => l10n.wallet,
      3 => l10n.profile,
      _ => l10n.loading,
    };
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text('$label ${l10n.loading.toLowerCase()}'),
          ],
        ),
      ),
    );
  }
}

class _IntroRow extends StatelessWidget {
  const _IntroRow({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: AppTheme.primary.withOpacity(0.14),
          ),
          child: Icon(icon, color: AppTheme.primarySoft),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FullscreenIntroCopy {
  const _FullscreenIntroCopy({
    required this.title,
    required this.subtitle,
    required this.pagesTitle,
    required this.pagesBody,
    required this.videosTitle,
    required this.videosBody,
    required this.splitTitle,
    required this.splitBody,
    required this.rulesTitle,
    required this.rulesBody,
    required this.closeLabel,
  });

  final String title;
  final String subtitle;
  final String pagesTitle;
  final String pagesBody;
  final String videosTitle;
  final String videosBody;
  final String splitTitle;
  final String splitBody;
  final String rulesTitle;
  final String rulesBody;
  final String closeLabel;

  static _FullscreenIntroCopy of(BuildContext context) {
    const english = _FullscreenIntroCopy(
      title: 'Welcome to fullscreen mode',
      subtitle:
          'Swipe instead of tapping buttons. Videos, Games, Wallet and Profile are now full-screen pages.',
      pagesTitle: 'Left or right',
      pagesBody: 'Swipe sideways to move between Videos, Games, Wallet and Profile.',
      videosTitle: 'Up or down',
      videosBody:
          'Swipe up or down inside Videos to move through shorts. Switching still does not count as a watched short.',
      splitTitle: 'Games split screen',
      splitBody:
          'On larger screens you can enable split screen inside Games to keep a smaller Videos panel open.',
      rulesTitle: 'Ad rules stay the same',
      rulesBody:
          'Reward rules do not change. Shorts only count after the normal watch conditions are met.',
      closeLabel: 'Got it',
    );

    const localized = <String, _FullscreenIntroCopy>{
      'nl': _FullscreenIntroCopy(
        title: 'Welkom in fullscreen-modus',
        subtitle:
            'Swipe in plaats van op knoppen te tikken. Video’s, Games, Wallet en Profiel zijn nu fullscreen pagina’s.',
        pagesTitle: 'Links of rechts',
        pagesBody:
            'Swipe horizontaal om te wisselen tussen Video’s, Games, Wallet en Profiel.',
        videosTitle: 'Omhoog of omlaag',
        videosBody:
            'Swipe in Video’s omhoog of omlaag om door shorts te gaan. Wisselen telt nog steeds niet als bekeken short.',
        splitTitle: 'Games split screen',
        splitBody:
            'Op grotere schermen kun je in Games split screen aanzetten om ook een kleinere Video-paneel open te houden.',
        rulesTitle: 'Advertentieregels blijven gelijk',
        rulesBody:
            'De beloningsregels veranderen niet. Shorts tellen pas mee als aan de normale kijkvoorwaarden is voldaan.',
        closeLabel: 'Begrepen',
      ),
      'hi': _FullscreenIntroCopy(
        title: 'फुलस्क्रीन मोड में आपका स्वागत है',
        subtitle:
            'बटन दबाने के बजाय swipe करें। Videos, Games, Wallet और Profile अब full-screen pages हैं।',
        pagesTitle: 'बाएँ या दाएँ',
        pagesBody: 'Videos, Games, Wallet और Profile के बीच जाने के लिए sideways swipe करें।',
        videosTitle: 'ऊपर या नीचे',
        videosBody:
            'Videos के अंदर ऊपर या नीचे swipe करके shorts बदलें। बदलना अभी भी watched short नहीं गिना जाता।',
        splitTitle: 'Games split screen',
        splitBody:
            'Games में split screen चालू करने पर Games और Videos एक साथ खुल सकते हैं.',
        rulesTitle: 'Ad rules वही हैं',
        rulesBody:
            'Reward rules नहीं बदलते। Shorts तभी गिने जाते हैं जब normal watch conditions पूरी हों।',
        closeLabel: 'ठीक है',
      ),
      'de': _FullscreenIntroCopy(
        title: 'Willkommen im Vollbildmodus',
        subtitle:
            'Wische statt auf Schaltflächen zu tippen. Videos, Games, Wallet und Profil sind jetzt Vollbildseiten.',
        pagesTitle: 'Links oder rechts',
        pagesBody:
            'Wische seitlich, um zwischen Videos, Games, Wallet und Profil zu wechseln.',
        videosTitle: 'Hoch oder runter',
        videosBody:
            'Wische in Videos nach oben oder unten, um durch Shorts zu gehen. Das Wechseln zählt weiterhin nicht als gesehener Short.',
        splitTitle: 'Games-Split-Screen',
        splitBody:
            'Wenn du den Split-Screen in Games aktivierst, können Games und Videos gleichzeitig geöffnet sein.',
        rulesTitle: 'Ad-Regeln bleiben gleich',
        rulesBody:
            'Die Reward-Regeln ändern sich nicht. Shorts zählen erst, wenn die normalen Wiedergabebedingungen erfüllt sind.',
        closeLabel: 'Verstanden',
      ),
      'es': _FullscreenIntroCopy(
        title: 'Bienvenido al modo de pantalla completa',
        subtitle:
            'Desliza en lugar de tocar botones. Videos, Games, Wallet y Perfil ahora son páginas de pantalla completa.',
        pagesTitle: 'Izquierda o derecha',
        pagesBody:
            'Desliza horizontalmente para moverte entre Videos, Games, Wallet y Perfil.',
        videosTitle: 'Arriba o abajo',
        videosBody:
            'Desliza hacia arriba o abajo dentro de Videos para cambiar de shorts. Cambiar sigue sin contar como short visto.',
        splitTitle: 'Pantalla dividida en Games',
        splitBody:
            'Al activar la pantalla dividida en Games, Games y Videos pueden quedar abiertos al mismo tiempo.',
        rulesTitle: 'Las reglas de anuncios siguen igual',
        rulesBody:
            'Las reglas de recompensa no cambian. Los shorts solo cuentan cuando se cumplen las condiciones normales de visualización.',
        closeLabel: 'Entendido',
      ),
      'fr': _FullscreenIntroCopy(
        title: 'Bienvenue en mode plein écran',
        subtitle:
            'Glisse au lieu d’appuyer sur des boutons. Videos, Games, Wallet et Profil sont maintenant des pages plein écran.',
        pagesTitle: 'Gauche ou droite',
        pagesBody:
            'Glisse horizontalement pour passer entre Videos, Games, Wallet et Profil.',
        videosTitle: 'Haut ou bas',
        videosBody:
            'Glisse vers le haut ou le bas dans Videos pour changer de shorts. Le changement ne compte toujours pas comme un short regardé.',
        splitTitle: 'Écran partagé Games',
        splitBody:
            'Quand tu actives l’écran partagé dans Games, Games et Videos peuvent rester ouverts en même temps.',
        rulesTitle: 'Les règles pub restent les mêmes',
        rulesBody:
            'Les règles de récompense ne changent pas. Les shorts ne comptent que lorsque les conditions normales de visionnage sont remplies.',
        closeLabel: 'Compris',
      ),
      'ru': _FullscreenIntroCopy(
        title: 'Добро пожаловать в полноэкранный режим',
        subtitle:
            'Смахивайте вместо нажатия кнопок. Videos, Games, Wallet и Профиль теперь полноэкранные страницы.',
        pagesTitle: 'Влево или вправо',
        pagesBody:
            'Смахивайте в стороны, чтобы переходить между Videos, Games, Wallet и Профилем.',
        videosTitle: 'Вверх или вниз',
        videosBody:
            'Смахивайте вверх или вниз внутри Videos, чтобы листать shorts. Переключение по-прежнему не считается просмотренным short.',
        splitTitle: 'Split screen в Games',
        splitBody:
            'Когда вы включаете split screen в Games, Games и Videos могут быть открыты одновременно.',
        rulesTitle: 'Правила рекламы те же',
        rulesBody:
            'Правила наград не меняются. Shorts засчитываются только при выполнении обычных условий просмотра.',
        closeLabel: 'Понятно',
      ),
      'el': _FullscreenIntroCopy(
        title: 'Καλώς ήρθες σε λειτουργία πλήρους οθόνης',
        subtitle:
            'Κάνε swipe αντί να πατάς κουμπιά. Τα Videos, Games, Wallet και Profile είναι πλέον σελίδες πλήρους οθόνης.',
        pagesTitle: 'Αριστερά ή δεξιά',
        pagesBody:
            'Κάνε οριζόντιο swipe για να αλλάζεις μεταξύ Videos, Games, Wallet και Profile.',
        videosTitle: 'Πάνω ή κάτω',
        videosBody:
            'Κάνε swipe πάνω ή κάτω μέσα στα Videos για να αλλάζεις shorts. Η αλλαγή ακόμη δεν μετρά ως προβεβλημένο short.',
        splitTitle: 'Games split screen',
        splitBody:
            'Όταν ενεργοποιείς split screen στο Games, τα Games και Videos μπορούν να μείνουν ανοιχτά μαζί.',
        rulesTitle: 'Οι κανόνες διαφημίσεων μένουν ίδιοι',
        rulesBody:
            'Οι κανόνες ανταμοιβής δεν αλλάζουν. Τα shorts μετρούν μόνο όταν ολοκληρωθούν οι κανονικές συνθήκες προβολής.',
        closeLabel: 'Εντάξει',
      ),
      'pt': _FullscreenIntroCopy(
        title: 'Bem-vindo ao modo de tela cheia',
        subtitle:
            'Deslize em vez de tocar em botões. Videos, Games, Wallet e Perfil agora são páginas em tela cheia.',
        pagesTitle: 'Esquerda ou direita',
        pagesBody:
            'Deslize para os lados para alternar entre Videos, Games, Wallet e Perfil.',
        videosTitle: 'Para cima ou para baixo',
        videosBody:
            'Deslize para cima ou para baixo dentro de Videos para passar pelos shorts. Trocar ainda não conta como short assistido.',
        splitTitle: 'Tela dividida em Games',
        splitBody:
            'Quando você ativa a tela dividida em Games, Games e Videos podem ficar abertos ao mesmo tempo.',
        rulesTitle: 'As regras de anúncios continuam iguais',
        rulesBody:
            'As regras de recompensa não mudam. Os shorts só contam quando as condições normais de visualização são cumpridas.',
        closeLabel: 'Entendi',
      ),
      'it': _FullscreenIntroCopy(
        title: 'Benvenuto nella modalità schermo intero',
        subtitle:
            'Scorri invece di toccare i pulsanti. Videos, Games, Wallet e Profilo ora sono pagine a schermo intero.',
        pagesTitle: 'Sinistra o destra',
        pagesBody:
            'Scorri lateralmente per passare tra Videos, Games, Wallet e Profilo.',
        videosTitle: 'Su o giù',
        videosBody:
            'Scorri in alto o in basso dentro Videos per cambiare shorts. Il cambio non conta ancora come short guardato.',
        splitTitle: 'Games split screen',
        splitBody:
            'Quando attivi lo split screen in Games, Games e Videos possono restare aperti insieme.',
        rulesTitle: 'Le regole degli annunci restano uguali',
        rulesBody:
            'Le regole delle ricompense non cambiano. Gli shorts contano solo quando vengono rispettate le normali condizioni di visione.',
        closeLabel: 'Capito',
      ),
      'tr': _FullscreenIntroCopy(
        title: 'Tam ekran moduna hoş geldin',
        subtitle:
            'Düğmelere basmak yerine kaydır. Videos, Games, Wallet ve Profil artık tam ekran sayfalar.',
        pagesTitle: 'Sola ya da sağa',
        pagesBody:
            'Videos, Games, Wallet ve Profil arasında geçmek için yana kaydır.',
        videosTitle: 'Yukarı ya da aşağı',
        videosBody:
            'Videos içinde shorts değiştirmek için yukarı veya aşağı kaydır. Değiştirmek hâlâ izlenmiş short sayılmaz.',
        splitTitle: 'Games bölünmüş ekran',
        splitBody:
            'Games içinde bölünmüş ekranı açtığında Games ve Videos aynı anda açık kalabilir.',
        rulesTitle: 'Reklam kuralları aynı',
        rulesBody:
            'Ödül kuralları değişmez. Shorts yalnızca normal izleme koşulları tamamlandığında sayılır.',
        closeLabel: 'Tamam',
      ),
      'ar': _FullscreenIntroCopy(
        title: 'مرحبًا بك في وضع ملء الشاشة',
        subtitle:
            'اسحب بدلًا من الضغط على الأزرار. أصبحت Videos وGames وWallet وProfile الآن صفحات بملء الشاشة.',
        pagesTitle: 'يمين أو يسار',
        pagesBody:
            'اسحب أفقيًا للتنقل بين Videos وGames وWallet وProfile.',
        videosTitle: 'أعلى أو أسفل',
        videosBody:
            'اسحب لأعلى أو لأسفل داخل Videos للتنقل بين المقاطع القصيرة. التبديل ما زال لا يُحتسب كمقطع تمت مشاهدته.',
        splitTitle: 'تقسيم الشاشة في Games',
        splitBody:
            'عند تفعيل تقسيم الشاشة داخل Games يمكن أن يبقى Games وVideos مفتوحين في الوقت نفسه.',
        rulesTitle: 'قواعد الإعلانات كما هي',
        rulesBody:
            'قواعد المكافآت لا تتغير. لا تُحتسب المقاطع إلا بعد استيفاء شروط المشاهدة العادية.',
        closeLabel: 'حسنًا',
      ),
      'bn': _FullscreenIntroCopy(
        title: 'ফুলস্ক্রিন মোডে স্বাগতম',
        subtitle:
            'বাটন চাপার বদলে swipe করুন। Videos, Games, Wallet আর Profile এখন ফুলস্ক্রিন পেজ।',
        pagesTitle: 'বাম বা ডান',
        pagesBody:
            'Videos, Games, Wallet আর Profile এর মধ্যে যেতে পাশে swipe করুন।',
        videosTitle: 'উপরে বা নিচে',
        videosBody:
            'Videos এর মধ্যে shorts বদলাতে উপরে বা নিচে swipe করুন। বদলানো এখনও watched short হিসেবে ধরা হবে না।',
        splitTitle: 'Games split screen',
        splitBody:
            'Games-এ split screen চালু করলে Games আর Videos একসাথে খোলা থাকতে পারে।',
        rulesTitle: 'Ad rules একই থাকবে',
        rulesBody:
            'Reward rules বদলাবে না। স্বাভাবিক watch conditions পূরণ হলেই শুধু shorts গণনা হবে।',
        closeLabel: 'ঠিক আছে',
      ),
      'ta': _FullscreenIntroCopy(
        title: 'முழுத்திரை முறைக்கு வரவேற்கிறோம்',
        subtitle:
            'பட்டன்களை தட்டுவதற்குப் பதில் swipe செய்யுங்கள். Videos, Games, Wallet மற்றும் Profile இப்போது முழுத்திரை பக்கங்கள்.',
        pagesTitle: 'இடம் அல்லது வலம்',
        pagesBody:
            'Videos, Games, Wallet மற்றும் Profile இடையே செல்ல பக்கமாக swipe செய்யுங்கள்.',
        videosTitle: 'மேல் அல்லது கீழ்',
        videosBody:
            'Videos உள்ளே shorts மாற்ற மேல் அல்லது கீழ் swipe செய்யுங்கள். மாற்றுவது இன்னும் பார்த்த short ஆக கணக்கிடப்படாது.',
        splitTitle: 'Games split screen',
        splitBody:
            'Games-ல் split screen ஐ இயக்கும் போது Games மற்றும் Videos ஒரே நேரத்தில் திறந்தே இருக்கலாம்.',
        rulesTitle: 'Ad விதிகள் அதேபோலவே இருக்கும்',
        rulesBody:
            'Reward விதிகள் மாறாது. சாதாரணமாக பார்க்க வேண்டிய நிபந்தனைகள் முடிந்த பிறகே shorts கணக்கிடப்படும்.',
        closeLabel: 'சரி',
      ),
      'te': _FullscreenIntroCopy(
        title: 'ఫుల్‌స్క్రీన్ మోడ్‌కు స్వాగతం',
        subtitle:
            'బటన్‌లు నొక్కడం బదులుగా swipe చేయండి. Videos, Games, Wallet మరియు Profile ఇప్పుడు ఫుల్‌స్క్రీన్ పేజీలు.',
        pagesTitle: 'ఎడమ లేదా కుడి',
        pagesBody:
            'Videos, Games, Wallet మరియు Profile మధ్య మారడానికి పక్కకు swipe చేయండి.',
        videosTitle: 'పైకి లేదా కిందికి',
        videosBody:
            'Videos లో shorts మార్చడానికి పైకి లేదా కిందికి swipe చేయండి. మార్చడం ఇంకా watched short గా లెక్కించబడదు.',
        splitTitle: 'Games split screen',
        splitBody:
            'Games లో split screen ఆన్ చేస్తే Games మరియు Videos ఒకేసారి తెరిచి ఉండవచ్చు.',
        rulesTitle: 'Ad నియమాలు అలాగే ఉంటాయి',
        rulesBody:
            'Reward నియమాలు మారవు. సాధారణ watch conditions పూర్తయ్యాకే shorts లెక్కలో చేరతాయి.',
        closeLabel: 'సరే',
      ),
    };

    return localized[Localizations.localeOf(context).languageCode.toLowerCase()] ??
        english;
  }
}

class _ResumeNoticeCopy {
  const _ResumeNoticeCopy({
    required this.title,
    required this.body,
    required this.closeLabel,
  });

  final String title;
  final String body;
  final String closeLabel;

  static _ResumeNoticeCopy of(BuildContext context) {
    const english = _ResumeNoticeCopy(
      title: 'You are back',
      body:
          'Don’t worry. If the app jumped to the background, just reopen it and you should be fine.',
      closeLabel: 'OK',
    );

    const localized = <String, _ResumeNoticeCopy>{
      'nl': _ResumeNoticeCopy(
        title: 'Je bent terug',
        body:
            'Geen zorgen. Als de app naar de achtergrond sprong, open hem gewoon opnieuw en dan zit je goed.',
        closeLabel: 'OK',
      ),
      'hi': _ResumeNoticeCopy(
        title: 'आप वापस आ गए',
        body:
            'चिंता मत करें। अगर ऐप बैकग्राउंड में चला गया था, तो उसे फिर से खोलें और सब ठीक होना चाहिए।',
        closeLabel: 'ठीक है',
      ),
      'de': _ResumeNoticeCopy(
        title: 'Du bist zurück',
        body:
            'Keine Sorge. Wenn die App in den Hintergrund gesprungen ist, öffne sie einfach erneut und alles sollte wieder in Ordnung sein.',
        closeLabel: 'OK',
      ),
      'es': _ResumeNoticeCopy(
        title: 'Has vuelto',
        body:
            'No te preocupes. Si la app se fue al fondo, solo vuelve a abrirla y debería estar bien.',
        closeLabel: 'OK',
      ),
      'fr': _ResumeNoticeCopy(
        title: 'Tu es de retour',
        body:
            'Ne t’inquiète pas. Si l’app est passée en arrière-plan, rouvre-la simplement et tout devrait aller bien.',
        closeLabel: 'OK',
      ),
      'ru': _ResumeNoticeCopy(
        title: 'Вы вернулись',
        body:
            'Не переживайте. Если приложение ушло в фон, просто откройте его снова, и всё должно быть нормально.',
        closeLabel: 'OK',
      ),
      'el': _ResumeNoticeCopy(
        title: 'Επέστρεψες',
        body:
            'Μην ανησυχείς. Αν η εφαρμογή πήγε στο παρασκήνιο, απλώς άνοιξέ την ξανά και λογικά όλα θα είναι εντάξει.',
        closeLabel: 'OK',
      ),
      'pt': _ResumeNoticeCopy(
        title: 'Você voltou',
        body:
            'Não se preocupe. Se o app foi para o segundo plano, basta abri-lo novamente e deve ficar tudo bem.',
        closeLabel: 'OK',
      ),
      'it': _ResumeNoticeCopy(
        title: 'Sei tornato',
        body:
            'Non preoccuparti. Se l’app è finita in background, basta riaprirla e dovrebbe andare tutto bene.',
        closeLabel: 'OK',
      ),
      'tr': _ResumeNoticeCopy(
        title: 'Geri döndün',
        body:
            'Merak etme. Uygulama arka plana geçtiyse tekrar açman yeterli, büyük ihtimalle her şey normale döner.',
        closeLabel: 'Tamam',
      ),
      'ar': _ResumeNoticeCopy(
        title: 'لقد عدت',
        body:
            'لا تقلق. إذا انتقل التطبيق إلى الخلفية، فقط افتحه من جديد ويُفترض أن يكون كل شيء بخير.',
        closeLabel: 'حسنًا',
      ),
      'bn': _ResumeNoticeCopy(
        title: 'তুমি ফিরে এসেছ',
        body:
            'চিন্তা করো না। যদি অ্যাপ ব্যাকগ্রাউন্ডে চলে যায়, আবার খুলে নাও, তাহলে ঠিক থাকার কথা।',
        closeLabel: 'ওকে',
      ),
      'ta': _ResumeNoticeCopy(
        title: 'நீங்கள் திரும்பிவிட்டீர்கள்',
        body:
            'கவலைப்பட வேண்டாம். ஆப் பின்னணிக்கு சென்றிருந்தால், அதை மீண்டும் திறக்கவும், எல்லாம் சரியாக இருக்க வேண்டும்.',
        closeLabel: 'சரி',
      ),
      'te': _ResumeNoticeCopy(
        title: 'మీరు తిరిగి వచ్చారు',
        body:
            'ఆందోళన పడకండి. యాప్ బ్యాక్‌గ్రౌండ్‌లోకి వెళ్లి ఉంటే, దాన్ని మళ్లీ తెరిస్తే సాధారణంగా బాగానే ఉంటుంది.',
        closeLabel: 'సరే',
      ),
    };

    return localized[Localizations.localeOf(context).languageCode.toLowerCase()] ??
        english;
  }
}
