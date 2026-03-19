import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF1B5E20);
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color accent = Color(0xFFFFD700);
  static const Color background = Color(0xFF0A0E21);
  static const Color surface = Color(0xFF1D1E33);
  static const Color surfaceLight = Color(0xFF2A2D45);
  static const Color cardBronze = Color(0xFFCD7F32);
  static const Color cardSilver = Color(0xFFC0C0C0);
  static const Color cardGold = Color(0xFFFFD700);
  static const Color cardElite = Color(0xFF9C27B0);
  static const Color cardLegend = Color(0xFFFF6D00);
  static const Color error = Color(0xFFCF6679);
  static const Color success = Color(0xFF4CAF50);

  // Glass colors
  static Color get glassSurface => Colors.white.withValues(alpha: 0.06);
  static Color get glassBorder => Colors.white.withValues(alpha: 0.12);
  static Color get glassSurfaceLight => Colors.white.withValues(alpha: 0.10);

  static Color getRarityColor(String rarity) {
    switch (rarity) {
      case 'bronze':
        return cardBronze;
      case 'silver':
        return cardSilver;
      case 'gold':
        return cardGold;
      case 'elite':
        return cardElite;
      case 'legend':
        return cardLegend;
      default:
        return cardBronze;
    }
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
      ),
      textTheme: GoogleFonts.rajdhaniTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
              fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          displayMedium: TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          titleLarge: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
          titleMedium: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
          bodyLarge: TextStyle(fontSize: 16, color: Colors.white70),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
          labelLarge: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface.withValues(alpha: 0.4),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.5)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface.withValues(alpha: 0.4),
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: accent,
        unselectedItemColor: Colors.white54,
        elevation: 0,
      ),
    );
  }
}
