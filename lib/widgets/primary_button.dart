import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onClick;
  final bool disabled;
  final bool danger;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onClick,
    this.disabled = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = disabled
        ? const Color(0xFFC7CDC1)
        : danger
            ? FarmoraColors.crit
            : FarmoraColors.brand;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: disabled ? null : onClick,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          disabledBackgroundColor: const Color(0xFFC7CDC1),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: FarmoraColors.onBrand,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
