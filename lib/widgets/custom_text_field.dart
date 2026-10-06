import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomTextField extends StatefulWidget {
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
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  TextEditingController? _internal;

  TextEditingController get _controller =>
      widget.controller ??
      (_internal ??= TextEditingController(text: widget.value));

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internal = TextEditingController(text: widget.value ?? '');
    }
  }

  @override
  void didUpdateWidget(covariant CustomTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller == null &&
        widget.value != null &&
        widget.value != _controller.text) {
      final text = widget.value!;
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  void dispose() {
    _internal?.dispose();
    super.dispose();
  }

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
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 15, color: FarmoraColors.inkFaint),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextFormField(
              controller: _controller,
              onChanged: widget.onChanged,
              obscureText: widget.isPassword && widget.obscureText,
              keyboardType: widget.keyboardType,
              style: TextStyle(fontSize: 13.5, color: FarmoraColors.ink),
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintStyle: TextStyle(color: FarmoraColors.inkFaint),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          if (widget.isPassword && widget.onTogglePassword != null)
            GestureDetector(
              onTap: widget.onTogglePassword,
              child: Icon(
                widget.obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 16,
                color: FarmoraColors.inkFaint,
              ),
            ),
        ],
      ),
    );
  }
}
