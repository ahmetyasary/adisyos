import 'package:flutter/material.dart';
import 'package:orderix/themes/app_colors.dart';

/// Full-color app mark (works on light and dark backgrounds).
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 48,
    this.borderRadius,
  });

  final double size;
  final BorderRadius? borderRadius;

  static const asset = 'assets/images/app_logo.png';

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size * 0.22);
    return ClipRRect(
      borderRadius: radius,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// Wordmark — source art is dark-on-clear; inverted for dark mode.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.height = 28,
    this.maxWidth,
  });

  final double height;
  final double? maxWidth;

  static const asset = 'assets/images/orderix_logo_text.png';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget image = Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Text(
        'Orderix',
        style: TextStyle(
          fontSize: height * 0.7,
          fontWeight: FontWeight.w700,
          color: dark ? Colors.white : AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
      ),
    );

    if (dark) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcATop),
        child: image,
      );
    }

    if (maxWidth != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: image,
      );
    }
    return image;
  }
}
