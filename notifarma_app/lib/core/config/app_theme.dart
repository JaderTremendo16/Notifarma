import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand Colors - Soft, calm and senior-friendly
  static const Color primaryBlue = Color(0xFF2563EB); // Soft Royal Blue
  static const Color primaryBlueLight = Color(0xFF3B82F6);
  static const Color darkHeaderBlue = Color(0xFF1E3A8A); // Deep serene navy
  
  static const Color accentOrange = Color(0xFFEA580C); // Warm Apricot / Peach orange (soft)
  static const Color lightOrange = Color(0xFFFFF7ED); // Soft peach background
  static const Color morningBlue = Color(0xFF0284C7); // Fresh morning sky
  static const Color afternoonOrange = Color(0xFFF97316); // Warm afternoon amber
  static const Color nightIndigo = Color(0xFF6366F1); // Calm night indigo

  static const Color sosRed = Color(0xFFDC2626); // Soft Coral Red
  static const Color lightRed = Color(0xFFFEF2F2);
  static const Color successGreen = Color(0xFF059669); // Soft Emerald / Mint
  static const Color lightGreen = Color(0xFFECFDF5);

  // Light Mode Colors
  static const Color backgroundLight = Color(0xFFF8FAFC); // Clean slate soft background
  static const Color cardLight = Colors.white;
  static const Color cardGlassLight = Color(0xEBFFFFFF); // 92% White Glass
  static const Color textPrimaryLight = Color(0xFF1E293B);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color borderLight = Color(0xFFE2E8F0);

  // Dark Mode Colors
  static const Color backgroundDark = Color(0xFF0F172A); // Midnight Slate
  static const Color cardDark = Color(0xFF1E293B); // Elevated dark surface
  static const Color cardGlassDark = Color(0xEB1E293B); // Translucent dark glass
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // High contrast soft white
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Muted secondary text
  static const Color borderDark = Color(0xFF334155); // Dark stroke

  // Legacy/Default references
  static const Color background = backgroundLight;
  static const Color cardBackground = cardLight;
  static const Color textPrimary = textPrimaryLight;
  static const Color textSecondary = textSecondaryLight;
  static const Color textWhite = Colors.white;
  static const Color borderGrey = borderLight;
  static const Color bottomNavBg = Color(0xFF0F172A);
}

class AppTheme {
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.outfitTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primaryBlue,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlue,
        brightness: Brightness.light,
        primary: AppColors.primaryBlue,
        secondary: AppColors.accentOrange,
        surface: AppColors.cardLight,
        error: AppColors.sosRed,
      ),
      textTheme: _buildTextTheme(baseTextTheme, AppColors.textPrimaryLight, AppColors.textSecondaryLight),
      elevatedButtonTheme: _buildElevatedButtonTheme(AppColors.accentOrange),
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.outfitTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryBlueLight,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlue,
        brightness: Brightness.dark,
        primary: AppColors.primaryBlueLight,
        secondary: AppColors.accentOrange,
        surface: AppColors.cardDark,
        error: AppColors.sosRed,
      ),
      textTheme: _buildTextTheme(baseTextTheme, AppColors.textPrimaryDark, AppColors.textSecondaryDark),
      elevatedButtonTheme: _buildElevatedButtonTheme(AppColors.accentOrange),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderDark, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderDark, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryBlueLight, width: 2),
        ),
      ),
    );
  }

  // Alias for backward compatibility
  static ThemeData get seniorTheme => lightTheme;

  static TextTheme _buildTextTheme(TextTheme base, Color primaryColor, Color secondaryColor) {
    return base.copyWith(
      displayLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: primaryColor,
      ),
      headlineLarge: GoogleFonts.outfit(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: primaryColor,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: primaryColor,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: primaryColor,
      ),
      titleMedium: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      bodyLarge: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: primaryColor,
      ),
      bodyMedium: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
      ),
      labelLarge: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme(Color bgColor) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: GoogleFonts.outfit(
          fontSize: 19,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        elevation: 2,
      ),
    );
  }
}
