import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The Farmora brand mark, rendered from a PNG under `assets/images/`.
///
/// A single widget backs every branded spot so the logo stays consistent:
///   * [asset] `logo_login.png` on the login hero,
///   * `logo_app.png` on the dashboard header and the register screen.
///
/// The source logos are rectangular with their own solid background, so the
/// image is fit with [BoxFit.contain] inside a square box and can optionally
/// get rounded corners ([radius]). If the asset can't be decoded it falls back
/// to a visible brand badge instead of an invisible gap.
class FarmoraLogo extends StatelessWidget {
  final String asset;
  final double size;

  /// Optional rounded-corner clip radius; null keeps square corners.
  final double? radius;

  /// Optional round background behind the mark; null renders the image alone.
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
    // Cap decode memory: sources are ~600-900px but are shown at <= ~90 logical
    // px, so decoding a few hundred px keeps the mobile image cache healthy.
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

  /// Visible stand-in shown when the PNG fails to load/decode (a missing
  /// asset or a stale bundle). Kept as a branded badge so the slot is never
  /// blank; the real reason is logged to the console by the errorBuilder.
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
