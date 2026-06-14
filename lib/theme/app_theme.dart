import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF040A07);
  static const Color surface = Color(0xFF0D1511);
  static const Color surfaceStrong = Color(0xFF16221C);
  static const Color primary = Color(0xFF22D37A);
  static const Color primarySoft = Color(0xFF7AF2B2);
  static const Color coin = Color(0xFFFFD166);
  static const Color outline = Color(0xFF264235);
  static const Color textMuted = Color(0xFFA7C7B6);

  static ThemeData darkTheme() {
    const colorScheme = ColorScheme.dark(
      primary: primary,
      secondary: primarySoft,
      surface: surface,
      error: Color(0xFFFF7B7B),
      onPrimary: Color(0xFF04110A),
      onSecondary: Color(0xFF04110A),
      onSurface: Color(0xFFF2F9F4),
      onError: Colors.white,
      outline: outline,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      canvasColor: background,
      dividerColor: outline.withOpacity(0.45),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: outline.withOpacity(0.5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceStrong,
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textMuted),
        helperStyle: const TextStyle(color: textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: outline.withOpacity(0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: outline.withOpacity(0.6)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          borderSide: BorderSide(color: Color(0xFFFF7B7B)),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          borderSide: BorderSide(color: Color(0xFFFF7B7B), width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: const Color(0xFF021008),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: outline.withOpacity(0.9)),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceStrong,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: outline.withOpacity(0.6)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withOpacity(0.16),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          return TextStyle(
            fontWeight: FontWeight.w600,
            color: states.contains(MaterialState.selected)
                ? Colors.white
                : textMuted,
          );
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(MaterialState.selected)
                ? primary
                : textMuted,
          );
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ).copyWith(
        displaySmall: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          height: 1.05,
        ),
        headlineMedium: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
        titleLarge: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          color: textMuted,
        ),
      ),
    );
  }
}
