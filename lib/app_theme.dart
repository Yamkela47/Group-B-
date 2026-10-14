import 'package:flutter/material.dart';

class AppColors {
  static const Color gold       = Color(0xFFE8C158);
  static const Color goldDim    = Color(0xFFB8942F);
  static const Color black      = Color(0xFF000000);
  static const Color surface    = Color(0xFF101010);
  static const Color surfaceAlt = Color(0xFF171717);
  static const Color border     = Color(0xFF2A2A2A);
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color textMuted     = Color(0xFF6B6B6B);
  static const Color error      = Color(0xFFE5484D);
  static const Color success    = Color(0xFF3DD68C);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.black,
        primaryColor: AppColors.gold,
        splashColor: AppColors.gold.withOpacity(0.08),
        highlightColor: AppColors.gold.withOpacity(0.04),
        colorScheme: const ColorScheme.dark(
          primary: AppColors.gold,
          secondary: AppColors.gold,
          surface: AppColors.surface,
          error: AppColors.error,
          onPrimary: Colors.black,
          onSurface: Colors.white,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.black,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceAlt,
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.gold, width: 1.4),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.2),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.gold,
            side: const BorderSide(color: AppColors.gold, width: 1.2),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.2),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.gold),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.border, thickness: 1, space: 1,
        ),
      );
}