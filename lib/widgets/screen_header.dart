import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? right;

  /// Optional brand/widget shown before the back button (e.g. the Farmora
  /// logo on the register screen). Does not affect the back-button rules.
  final Widget? leading;

  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.right,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final showBack = onBack != null || Navigator.of(context).canPop();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: FarmoraColors.surface,
        border: Border(bottom: BorderSide(color: FarmoraColors.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 10),
                ],
                if (showBack) ...[
                  IconButton(
                    onPressed: () {
                      if (onBack != null) {
                        onBack!();
                      } else if (Navigator.of(context).canPop()) {
                        Navigator.pop(context);
                      }
                    },
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    icon: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: FarmoraColors.surfaceSunken,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: FarmoraColors.line),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: FarmoraColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: FarmoraColors.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: FarmoraColors.inkSoft,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (right != null) right!,
        ],
      ),
    );
  }
}
