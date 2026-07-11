import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/app_rating.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class AppRatingScreen extends StatefulWidget {
  const AppRatingScreen({super.key});

  @override
  State<AppRatingScreen> createState() => _AppRatingScreenState();
}

class _AppRatingScreenState extends State<AppRatingScreen> {
  final _firestoreService = FirestoreService();
  int _selectedStars = 5;
  bool _isSubmitting = false;
  bool _initializedFromExistingRating = false;

  Future<void> _submit() async {
    final l10n = context.l10n;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);
    try {
      await _firestoreService.submitRating(
        uid: user.uid,
        email: user.email ?? '',
        stars: _selectedStars,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.thanksForRating)),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.rateApp)),
      body: StreamBuilder<AppRating?>(
        stream: _firestoreService.watchUserRating(user.uid),
        builder: (context, snapshot) {
          final currentRating = snapshot.data;
          if (!_initializedFromExistingRating && currentRating != null) {
            _selectedStars = currentRating.stars;
            _initializedFromExistingRating = true;
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
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
                      l10n.rateAppQuestion,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.choose1to5,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      children: List.generate(5, (index) {
                        final starValue = index + 1;
                        return IconButton.filledTonal(
                          onPressed: () {
                            setState(() => _selectedStars = starValue);
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: starValue <= _selectedStars
                                ? AppTheme.primary.withOpacity(0.18)
                                : Colors.white.withOpacity(0.04),
                          ),
                          icon: Icon(
                            starValue <= _selectedStars
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: AppTheme.primarySoft,
                            size: 30,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: Text(_isSubmitting ? l10n.saving : l10n.saveRating),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
