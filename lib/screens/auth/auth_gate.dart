import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/firestore_service.dart';
import '../../widgets/brand_logo.dart';
import '../main/home_shell.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: _AuthLoadingView(),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text(context.l10n.unableRestoreSession)),
          );
        }

        if (snapshot.data != null) {
          return FutureBuilder<void>(
            future: firestoreService.createUserProfile(snapshot.data!),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: _AuthLoadingView(),
                );
              }

              return const HomeShell();
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
}

class _AuthLoadingView extends StatelessWidget {
  const _AuthLoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandLogo(height: 84),
          const SizedBox(height: 20),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            context.l10n.loadingWallet,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
