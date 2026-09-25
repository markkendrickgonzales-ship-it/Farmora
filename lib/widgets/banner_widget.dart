import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BannerWidget extends StatelessWidget {
  final String level;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  const BannerWidget({
    super.key,
    this.level = 'info',
    required this.message,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    Color fg;
    Color bg;
    IconData iconData;

    switch (level) {
      case 'crit':
        fg = FarmoraColors.crit;
        bg = FarmoraColors.critSoft;
        iconData = Icons.warning_amber_rounded;
        break;
      case 'warn':
        fg = FarmoraColors.warn;
        bg = FarmoraColors.warnSoft;
        iconData = Icons.warning_amber_rounded;
        break;
      case 'info':
      default:
        fg = FarmoraColors.info;
        bg = FarmoraColors.infoSoft;
        iconData = Icons.info_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withAlpha(38)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, size: 16, color: fg),
          const SizedBox(width: 9),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12.5,
                  color: FarmoraColors.ink,
                  height: 1.45,
                ),
                children: [
                  TextSpan(text: message),
                  if (action != null)
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: onAction,
                        child: Text(
                          '  $action',
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
