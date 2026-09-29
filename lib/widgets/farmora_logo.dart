import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The Farmora brand mark, rendered from `assets/images/logo.png`.
///
/// Used at three scales across the app: the dashboard header, the login hero
/// and the register header. Keeps aspect ratio, and if the asset can't be
/// decoded it falls back to a visible brand badge (rather than an invisible gap)
/// so a packaging problem is obvious instead of silently blank.
class FarmoraLogo extends StatelessWidget {
  final double size;

  /// Optional round background behind the mark; transparent when null, which
  /// suits logos that already carry their own background.
  final Color? background;

  const FarmoraLogo({super.key, this.size = 40, this.background});

  @override
  Widget build(BuildContext context) {
    // Cap decode memory: the source is 1254x1254 but is shown at <= ~76 logical
    // px, so decoding a few hundred px keeps the mobile image cache healthy.
    final cacheWidth = (size * 3).round().clamp(64, 512);
    final logo = Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: cacheWidth,
      errorBuilder: (context, error, stackTrace) => _fallback,
    );
    if (background == null) return logo;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Padding(
        padding: EdgeInsets.all(size * 0.12),
        child: logo,
      ),
    );
  }

  /// Visible stand-in shown when the PNG fails to load/decode.
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
