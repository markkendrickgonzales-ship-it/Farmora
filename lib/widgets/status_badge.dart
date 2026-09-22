import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String level;
  final Widget child;

  const StatusBadge({
    super.key,
    required this.level,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    Color fg;
    Color bg;

    switch (level) {
      case 'good':
        fg = FarmoraColors.good;
        bg = FarmoraColors.goodSoft;
        break;
      case 'warn':
        fg = FarmoraColors.warn;
        bg = FarmoraColors.warnSoft;
        break;
      case 'crit':
        fg = FarmoraColors.crit;
        bg = FarmoraColors.critSoft;
        break;
      case 'info':
      default:
        fg = FarmoraColors.info;
        bg = FarmoraColors.infoSoft;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
          letterSpacing: 0.2,
        ),
        child: IconTheme(
          data: IconThemeData(size: 11, color: fg),
          child: child,
        ),
      ),
    );
  }
}
