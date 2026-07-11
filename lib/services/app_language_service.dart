import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

class AppLanguageService extends ChangeNotifier {
  AppLanguageService._();

  static final AppLanguageService instance = AppLanguageService._();

  static const String _preferenceKey = 'preferred_app_language_code';
  static const String automaticValue = 'auto';

  String? _preferredLanguageCode;

  String? get preferredLanguageCode => _preferredLanguageCode;
  bool get isAutomatic => _preferredLanguageCode == null;

  Locale? get localeOverride =>
      _preferredLanguageCode == null ? null : Locale(_preferredLanguageCode!);

  String get selectedLanguageCodeOrAuto =>
      _preferredLanguageCode ?? automaticValue;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getString(_preferenceKey);
    if (savedValue == null || savedValue.trim().isEmpty) {
      _preferredLanguageCode = null;
      return;
    }

    final normalizedValue = savedValue.toLowerCase().trim();
    if (_supportedLanguageCodes.contains(normalizedValue)) {
      _preferredLanguageCode = normalizedValue;
      return;
    }

    _preferredLanguageCode = null;
    await prefs.remove(_preferenceKey);
  }

  Future<void> setPreferredLanguageCode(String? languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedValue = languageCode?.toLowerCase().trim();

    if (normalizedValue == null ||
        normalizedValue.isEmpty ||
        !_supportedLanguageCodes.contains(normalizedValue)) {
      _preferredLanguageCode = null;
      await prefs.remove(_preferenceKey);
    } else {
      _preferredLanguageCode = normalizedValue;
      await prefs.setString(_preferenceKey, normalizedValue);
    }

    notifyListeners();
  }

  static final Set<String> _supportedLanguageCodes = {
    for (final locale in AppLocalizations.supportedLocales) locale.languageCode,
  };

  static const Map<String, String> _nativeLanguageNames = {
    'en': 'English',
    'nl': 'Nederlands',
    'hi': 'हिन्दी',
    'de': 'Deutsch',
    'es': 'Español',
    'fr': 'Français',
    'ru': 'Русский',
    'el': 'Ελληνικά',
    'pt': 'Português',
    'it': 'Italiano',
    'tr': 'Türkçe',
    'ar': 'العربية',
    'bn': 'বাংলা',
    'ta': 'தமிழ்',
    'te': 'తెలుగు',
  };

  List<AppLanguageOption> get supportedLanguageOptions {
    return AppLocalizations.supportedLocales
        .map(
          (locale) => AppLanguageOption(
            code: locale.languageCode,
            label: _nativeLanguageNames[locale.languageCode] ??
                locale.languageCode.toUpperCase(),
          ),
        )
        .toList(growable: false);
  }
}

class AppLanguageOption {
  const AppLanguageOption({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}
