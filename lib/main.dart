import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app_routes.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'services/app_language_service.dart';
import 'services/notification_service.dart';
import 'services/presence_service.dart';
import 'services/rewarded_ad_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VideoMoneyBootstrap());
}

class VideoMoneyBootstrap extends StatefulWidget {
  const VideoMoneyBootstrap({super.key});

  @override
  State<VideoMoneyBootstrap> createState() => _VideoMoneyBootstrapState();
}

class _VideoMoneyBootstrapState extends State<VideoMoneyBootstrap> {
  late final Future<void> _initializeFuture = _initialize();

  Future<void> _initialize() async {
    await AppLanguageService.instance.initialize();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await PresenceService.instance.initialize();
    await NotificationService.instance.initialize();
    await MobileAds.instance.initialize();
    await RewardedAdService().preloadRewardedAd();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguageService.instance,
      builder: (context, _) {
        return MaterialApp(
          onGenerateTitle: (context) => context.l10n.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme(),
          locale: AppLanguageService.instance.localeOverride,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: FutureBuilder<void>(
            future: _initializeFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _StartupStatusScreen(showLoader: true);
              }

              if (snapshot.hasError) {
                return _StartupStatusScreen(
                  message:
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                  isError: true,
                );
              }

              return const VideoMoneyApp();
            },
          ),
        );
      },
    );
  }
}

class VideoMoneyApp extends StatelessWidget {
  const VideoMoneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      initialRoute: AppRoutes.authGate,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}

class _StartupStatusScreen extends StatelessWidget {
  const _StartupStatusScreen({
    this.message,
    this.showLoader = false,
    this.isError = false,
  });

  final String? message;
  final bool showLoader;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showLoader) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    isError
                        ? context.l10n.startupFailed
                        : context.l10n.startingApp,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message ?? context.l10n.preparingStartup,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
