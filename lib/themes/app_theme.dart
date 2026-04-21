import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Orderix uses a single light theme aligned with the iOS-inspired design
/// language used across all views (orange brand + neutral surfaces).
/// There is intentionally no dark theme: every screen hard-codes light
/// surfaces, so exposing a dark theme would silently break contrast.
class AppTheme {
  // iOS system palette (brand)
  static const Color primaryColor   = Color(0xFFFF9500); // iOS orange
  static const Color secondaryColor = Color(0xFF8E8E93); // iOS secondary label
  static const Color accentColor    = Color(0xFF007AFF); // iOS blue
  static const Color successColor   = Color(0xFF34C759); // iOS green
  static const Color warningColor   = Color(0xFFFF9500); // iOS orange
  static const Color errorColor     = Color(0xFFFF3B30); // iOS red
  static const Color infoColor      = Color(0xFF5AC8FA); // iOS teal

  // Neutral surfaces
  static const Color background     = Color(0xFFF2F2F7);
  static const Color surface        = Colors.white;
  static const Color labelPrimary   = Color(0xFF1C1C1E);
  static const Color labelSecondary = Color(0xFF8E8E93);
  static const Color separator      = Color(0xFFE5E5EA);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.light(
      primary:     primaryColor,
      secondary:   accentColor,
      tertiary:    successColor,
      error:       errorColor,
      surface:     surface,
      onPrimary:   Colors.white,
      onSecondary: Colors.white,
      onSurface:   labelPrimary,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  );
}
