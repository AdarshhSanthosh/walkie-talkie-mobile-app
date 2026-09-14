import 'package:flutter/material.dart';

/// App theming, matched to the "Holler" design reference
/// (https://friend-chatterbox.lovable.app): warm cream background, a coral/
/// orange accent for the TALK button and highlights, and a soft mint green
/// for online presence. Dark mode inverts the same palette.
class AppColors {
  static const orange = Color(0xFFF85A3A); // TALK button, avatar badges, links
  static const green = Color(0xFF49C796); // online presence dot

  // Light ("Holler" default)
  static const creamBg = Color(0xFFF4EEDF); // page background
  static const cardBg = Color(0xFFFBF7ED); // list-item / card background
  static const cardBgMuted = Color(0xFFE7DCBE); // offline / muted row background
  static const pillBg = Color(0xFFFAE7DB); // "on channel" pill background
  static const textDark = Color(0xFF2E2822);
  static const textMuted = Color(0xFF8A8578);

  // Dark
  static const darkBg = Color(0xFF1C1A16);
  static const darkCard = Color(0xFF272420);
  static const darkCardMuted = Color(0xFF322E27);
  static const darkPillBg = Color(0xFF4A2E22);
  static const darkTextMuted = Color(0xFFA79E8E);
}

/// Brightness-aware accessors for the tokens above, so screens don't need
/// to branch on `Theme.of(context).brightness` themselves.
extension AppColorsX on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  Color get cardMutedBg => _isDark ? AppColors.darkCardMuted : AppColors.cardBgMuted;
  Color get pillBg => _isDark ? AppColors.darkPillBg : AppColors.pillBg;
  Color get textMuted => _isDark ? AppColors.darkTextMuted : AppColors.textMuted;
}

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      brightness: Brightness.light,
      primary: AppColors.orange,
      onPrimary: Colors.white,
      surface: AppColors.cardBg,
      onSurface: AppColors.textDark,
    );
    return _themeFrom(scheme, scaffoldBg: AppColors.creamBg, cardBg: AppColors.cardBg);
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      brightness: Brightness.dark,
      primary: AppColors.orange,
      onPrimary: Colors.white,
      surface: AppColors.darkCard,
      onSurface: const Color(0xFFF4EEDF),
    );
    return _themeFrom(scheme, scaffoldBg: AppColors.darkBg, cardBg: AppColors.darkCard);
  }

  static ThemeData _themeFrom(
    ColorScheme scheme, {
    required Color scaffoldBg,
    required Color cardBg,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: ThemeData(brightness: scheme.brightness).textTheme.apply(
            fontFamily: 'Roboto',
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface,
          ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
