import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app_routes.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
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
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService.instance.initialize();
    await MobileAds.instance.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VideoMoney',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      home: FutureBuilder<void>(
        future: _initializeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _StartupStatusScreen(
              title: 'Starting VideoMoney',
              message: 'Preparing Firebase, wallet data, and rewarded ads...',
              showLoader: true,
            );
          }

          if (snapshot.hasError) {
            return _StartupStatusScreen(
              title: 'Startup failed',
              message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            );
          }

          return const VideoMoneyApp();
        },
      ),
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
    required this.title,
    required this.message,
    this.showLoader = false,
  });

  final String title;
  final String message;
  final bool showLoader;

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
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
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
