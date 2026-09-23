import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomTextField extends StatelessWidget {
  final String placeholder;
  final IconData? icon;
  final String? value;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onTogglePassword;
  final TextInputType? keyboardType;

  const CustomTextField({
    super.key,
    required this.placeholder,
    this.icon,
    this.value,
    this.controller,
    this.onChanged,
    this.isPassword = false,
    this.obscureText = false,
    this.onTogglePassword,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FarmoraColors.surfaceSunken,
        border: Border.all(color: FarmoraColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: FarmoraColors.inkFaint),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextFormField(
              controller: controller,
              initialValue: controller == null ? value : null,
              onChanged: onChanged,
              obscureText: isPassword && obscureText,
              keyboardType: keyboardType,
              style: const TextStyle(fontSize: 13.5, color: FarmoraColors.ink),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: const TextStyle(color: FarmoraColors.inkFaint),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          if (isPassword && onTogglePassword != null)
            GestureDetector(
              onTap: onTogglePassword,
              child: Icon(
                obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 16,
                color: FarmoraColors.inkFaint,
              ),
            ),
        ],
      ),
    );
  }
}
