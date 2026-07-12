import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_money/services/app_language_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.clearLocaleTestValue();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'uses supported device language on first launch without overriding locale',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.binding.platformDispatcher.localeTestValue = const Locale('es');

      await AppLanguageService.instance.initialize();

      expect(AppLanguageService.instance.preferredLanguageCode, isNull);
      expect(AppLanguageService.instance.localeOverride, isNull);
      expect(AppLanguageService.instance.selectedLanguageCode, 'es');
    },
  );

  testWidgets(
    'falls back to English when device language is unsupported',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.binding.platformDispatcher.localeTestValue = const Locale('ja');

      await AppLanguageService.instance.initialize();

      expect(AppLanguageService.instance.preferredLanguageCode, isNull);
      expect(AppLanguageService.instance.localeOverride, isNull);
      expect(AppLanguageService.instance.selectedLanguageCode, 'en');
    },
  );

  testWidgets(
    'keeps manual language preference over device language',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'preferred_app_language_code': 'fr',
      });
      tester.binding.platformDispatcher.localeTestValue = const Locale('es');

      await AppLanguageService.instance.initialize();

      expect(AppLanguageService.instance.preferredLanguageCode, 'fr');
      expect(AppLanguageService.instance.localeOverride, const Locale('fr'));
      expect(AppLanguageService.instance.selectedLanguageCode, 'fr');
    },
  );
}
