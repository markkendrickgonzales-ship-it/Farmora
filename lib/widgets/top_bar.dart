import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TopBar extends StatelessWidget {
  final VoidCallback onBell;
  final VoidCallback? onSearch;
  final VoidCallback? onAdvisory;

  const TopBar({
    super.key,
    required this.onBell,
    this.onSearch,
    this.onAdvisory,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onSearch != null) ...[
          _iconBtn(Icons.search, onSearch!),
          const SizedBox(width: 8),
        ],
        if (onAdvisory != null) ...[
          _iconBtn(Icons.lightbulb_outline, onAdvisory!),
          const SizedBox(width: 8),
        ],
        Stack(
          children: [
            _iconBtn(Icons.notifications_none_rounded, onBell),
            Positioned(
              top: 6,
              right: 7,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: FarmoraColors.crit,
                  shape: BoxShape.circle,
                  border: Border.all(color: FarmoraColors.surface, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: FarmoraColors.surfaceSunken,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18, color: FarmoraColors.ink),
        onPressed: onTap,
      ),
    );
  }
}
