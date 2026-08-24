import 'package:flutter/material.dart';

/// Light/dark surface tokens. Synced from [Theme] in MaterialApp.builder so
/// existing `_bg` / `_card` style locals can become getters without rewriting
/// every call site to pass BuildContext.
class AppColors {
  AppColors._();

  static Brightness _brightness = Brightness.light;

  static Brightness get brightness => _brightness;
  static bool get isDark => _brightness == Brightness.dark;

  /// Call from MaterialApp.builder whenever the theme changes.
  static void syncFrom(BuildContext context) {
    _brightness = Theme.of(context).brightness;
  }

  static void syncBrightness(Brightness brightness) {
    _brightness = brightness;
  }

  /// Mark every element dirty so screens that only read [AppColors] getters
  /// refresh immediately after a theme toggle (without navigating away).
  static void rebuildTree(BuildContext? context) {
    if (context is! Element) return;
    void mark(Element el) {
      el.markNeedsBuild();
      el.visitChildren(mark);
    }
    mark(context);
  }

  // Brand accents (same in both modes)
  static const Color orange = Color(0xFFFF9500);
  static const Color green = Color(0xFF34C759);
  static const Color blue = Color(0xFF007AFF);
  static const Color purple = Color(0xFFAF52DE);
  static const Color red = Color(0xFFFF3B30);
  static const Color teal = Color(0xFF5AC8FA);

  static Color get bg =>
      isDark ? const Color(0xFF000000) : Colors.white;

  static Color get scaffold =>
      isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

  static Color get card =>
      isDark ? const Color(0xFF1C1C1E) : Colors.white;

  static Color get border =>
      isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);

  static Color get borderSoft =>
      isDark ? const Color(0xFF2C2C2E) : const Color(0xFFECECEF);

  static Color get chipBg =>
      isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);

  static Color get textPrimary =>
      isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1C1C1E);

  static Color get textSec =>
      isDark ? const Color(0xFF98989D) : const Color(0xFF8E8E93);

  static Color get textTertiary =>
      isDark ? const Color(0xFF636366) : const Color(0xFFAEAEB2);

  static List<BoxShadow> get cardShadow => isDark
      ? const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ];
}

/// ThemeExtension so Material widgets + Theme.of(context) stay in sync.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.scaffold,
    required this.card,
    required this.border,
    required this.chipBg,
    required this.textPrimary,
    required this.textSec,
  });

  final Color bg;
  final Color scaffold;
  final Color card;
  final Color border;
  final Color chipBg;
  final Color textPrimary;
  final Color textSec;

  static const light = AppPalette(
    bg: Colors.white,
    scaffold: Color(0xFFF2F2F7),
    card: Colors.white,
    border: Color(0xFFE5E5EA),
    chipBg: Color(0xFFF2F2F7),
    textPrimary: Color(0xFF1C1C1E),
    textSec: Color(0xFF8E8E93),
  );

  static const dark = AppPalette(
    bg: Color(0xFF000000),
    scaffold: Color(0xFF000000),
    card: Color(0xFF1C1C1E),
    border: Color(0xFF38383A),
    chipBg: Color(0xFF2C2C2E),
    textPrimary: Color(0xFFF5F5F7),
    textSec: Color(0xFF98989D),
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? scaffold,
    Color? card,
    Color? border,
    Color? chipBg,
    Color? textPrimary,
    Color? textSec,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      scaffold: scaffold ?? this.scaffold,
      card: card ?? this.card,
      border: border ?? this.border,
      chipBg: chipBg ?? this.chipBg,
      textPrimary: textPrimary ?? this.textPrimary,
      textSec: textSec ?? this.textSec,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      scaffold: Color.lerp(scaffold, other.scaffold, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      chipBg: Color.lerp(chipBg, other.chipBg, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSec: Color.lerp(textSec, other.textSec, t)!,
    );
  }
}

extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
