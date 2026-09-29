import 'package:flutter/material.dart';

/// The Farmora brand mark, rendered from `assets/images/logo.png`.
///
/// Used at three scales across the app: the dashboard header, the login hero
/// and the register header. Keeps aspect ratio and degrades to an empty box
/// (rather than a red error tile) if the asset is ever missing.
class FarmoraLogo extends StatelessWidget {
  final double size;

  /// Optional round background behind the mark; transparent when null, which
  /// suits logos that already carry their own background.
  final Color? background;

  const FarmoraLogo({super.key, this.size = 40, this.background});

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          SizedBox(width: size, height: size),
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
}
