/// Shared "Apple-inspired" surface design tokens.
/// Prefer these for new work; values follow [AppColors] (light/dark).
import 'package:flutter/material.dart';
import 'package:orderix/themes/app_colors.dart';

// ── Palette (brightness-aware) ────────────────────────────────
Color get kBg => AppColors.bg;
Color get kCard => AppColors.card;
Color get kBorder => AppColors.borderSoft;
Color get kChipBg => AppColors.chipBg;
Color get kTextPrimary => AppColors.textPrimary;
Color get kTextSec => AppColors.textSec;

const Color kOrange = AppColors.orange;
const Color kGreen = AppColors.green;
const Color kBlue = AppColors.blue;
const Color kPurple = AppColors.purple;
const Color kRed = AppColors.red;
const Color kTeal = AppColors.teal;

List<BoxShadow> get kCardShadow => AppColors.cardShadow;

BoxDecoration get kCardDeco => BoxDecoration(
      color: kCard,
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      border: Border.fromBorderSide(BorderSide(color: kBorder, width: 1)),
      boxShadow: kCardShadow,
    );

BoxDecoration cardDeco({double radius = 18}) => BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: kBorder, width: 1),
      boxShadow: kCardShadow,
    );

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
      child: Icon(icon, size: iconSize, color: kTextPrimary),
    );
  }
}
