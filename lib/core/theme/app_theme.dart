import 'package:flutter/material.dart';

/// App theme configurations for PassKeep featuring a sleek, borderless minimalist design
/// with a monochromatic palette (Black, White, Slate / Zinc Grey).
abstract final class AppTheme {
  // Monochromatic Light Palette
  static const Color lightBackground = Color(0xFFF4F4F5); // Zinc 100
  static const Color lightSurface = Color(0xFFFFFFFF); // Pure White Card
  static const Color lightInputFill = Color(0xFFE4E4E7); // Zinc 200
  static const Color lightPrimary = Color(0xFF09090B); // Rich Black Action
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF09090B); // Zinc 950
  static const Color lightTextMuted = Color(0xFF71717A); // Zinc 500
  static const Color lightDivider = Color(0xFFE4E4E7);
  static const Color lightDestructive = Color(0xFFDC2626); // Muted Red

  // Monochromatic Dark Palette
  static const Color darkBackground = Color(0xFF09090B); // Zinc 950 Deep Black
  static const Color darkSurface = Color(0xFF18181B); // Zinc 900 Surface Card
  static const Color darkInputFill = Color(0xFF27272A); // Zinc 800
  static const Color darkPrimary = Color(0xFFFFFFFF); // Pure White Action
  static const Color darkOnPrimary = Color(0xFF09090B);
  static const Color darkTextPrimary = Color(0xFFFAFAFA); // Zinc 50
  static const Color darkTextMuted = Color(0xFFA1A1AA); // Zinc 400
  static const Color darkDivider = Color(0xFF27272A);
  static const Color darkDestructive = Color(0xFFF87171);

  /// Minimalist Borderless Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: darkPrimary,
        onPrimary: darkOnPrimary,
        secondary: Color(0xFFA1A1AA),
        onSecondary: Color(0xFF09090B),
        error: darkDestructive,
        onError: Color(0xFF09090B),
        surface: darkSurface,
        onSurface: darkTextPrimary,
        surfaceContainerHighest: darkInputFill,
        onSurfaceVariant: darkTextMuted,
        outline: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide.none,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInputFill,
        hintStyle: const TextStyle(color: darkTextMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: darkDivider,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: darkOnPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkBackground,
        elevation: 0,
        indicatorColor: darkInputFill,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: darkTextPrimary, fontSize: 12, fontWeight: FontWeight.bold);
          }
          return const TextStyle(color: darkTextMuted, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: darkTextPrimary, size: 22);
          }
          return const IconThemeData(color: darkTextMuted, size: 22);
        }),
      ),
    );
  }

  /// Minimalist Borderless Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: lightPrimary,
        onPrimary: lightOnPrimary,
        secondary: Color(0xFF71717A),
        onSecondary: Color(0xFFFFFFFF),
        error: lightDestructive,
        onError: Color(0xFFFFFFFF),
        surface: lightSurface,
        onSurface: lightTextPrimary,
        surfaceContainerHighest: lightInputFill,
        onSurfaceVariant: lightTextMuted,
        outline: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide.none,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightInputFill,
        hintStyle: const TextStyle(color: lightTextMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: lightDivider,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: lightOnPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightBackground,
        elevation: 0,
        indicatorColor: lightInputFill,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: lightTextPrimary, fontSize: 12, fontWeight: FontWeight.bold);
          }
          return const TextStyle(color: lightTextMuted, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: lightTextPrimary, size: 22);
          }
          return const IconThemeData(color: lightTextMuted, size: 22);
        }),
      ),
    );
  }
}
