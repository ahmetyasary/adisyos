/// Shared "Apple-inspired" surface design tokens, aligned with the Dashboard
/// redesign so every screen speaks the same visual language:
///   • white page background
///   • flat white cards with a hairline border + a very light shadow
///   • flat, single-colour icon badges (no gradients)
///
/// Views historically defined these tokens privately (and diverged over time).
/// Prefer these shared tokens for any new surface work.
import 'package:flutter/material.dart';

// ── Palette ───────────────────────────────────────────────────
const Color kBg = Colors.white;
const Color kCard = Colors.white;
const Color kBorder = Color(0xFFECECEF);
const Color kChipBg = Color(0xFFF2F2F7);
const Color kTextPrimary = Color(0xFF1C1C1E);
const Color kTextSec = Color(0xFF8E8E93);

// iOS system accents
const Color kOrange = Color(0xFFFF9500);
const Color kGreen = Color(0xFF34C759);
const Color kBlue = Color(0xFF007AFF);
const Color kPurple = Color(0xFFAF52DE);
const Color kRed = Color(0xFFFF3B30);
const Color kTeal = Color(0xFF5AC8FA);

// ── Card shadow / decoration ──────────────────────────────────
const List<BoxShadow> kCardShadow = [
  BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
  BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 1)),
];

/// The canonical flat, bordered card decoration (18px radius).
const BoxDecoration kCardDeco = BoxDecoration(
  color: kCard,
  borderRadius: BorderRadius.all(Radius.circular(18)),
  border: Border.fromBorderSide(BorderSide(color: kBorder, width: 1)),
  boxShadow: kCardShadow,
);

/// A card decoration with a custom corner radius but the same border + shadow.
BoxDecoration cardDeco({double radius = 18}) => BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: kBorder, width: 1),
      boxShadow: kCardShadow,
    );

// ── Icon badge ────────────────────────────────────────────────

/// A flat, single-colour rounded-square icon badge — the Dashboard KPI style.
/// Replaces the previous gradient badges used across older screens.
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 46,
    this.radius = 14,
    this.iconSize = 22,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }
}

/// A neutral (grey-chip) icon badge — the Dashboard "recent row" style.
class AppNeutralBadge extends StatelessWidget {
  const AppNeutralBadge({
    super.key,
    required this.icon,
    this.size = 40,
    this.radius = 12,
    this.iconSize = 20,
  });

  final IconData icon;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: kChipBg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: const Color(0xFF3A3A3C)),
    );
  }
}
