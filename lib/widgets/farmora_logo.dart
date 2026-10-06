import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FarmoraLogo extends StatelessWidget {
  final String asset;
  final double size;

  final double? radius;

  final Color? background;

  const FarmoraLogo({
    super.key,
    this.asset = 'assets/images/logo_app.png',
    this.size = 40,
    this.radius,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final cacheWidth = (size * 3).round().clamp(64, 512);
    Widget logo = Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: cacheWidth,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('FarmoraLogo FAILED to load "$asset": $error');
        return _fallback;
      },
    );
    if (radius != null) {
      logo = ClipRRect(
        borderRadius: BorderRadius.circular(radius!),
        child: logo,
      );
    }
    if (background != null) {
      logo = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Padding(
          padding: EdgeInsets.all(size * 0.12),
          child: logo,
        ),
      );
    }
    return logo;
  }

  Widget get _fallback => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: FarmoraColors.brand,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.eco, color: Colors.white, size: size * 0.62),
      );
}
