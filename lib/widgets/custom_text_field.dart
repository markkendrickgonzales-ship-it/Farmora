import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A themed text input that is always backed by a live [TextEditingController].
///
/// Earlier this widget was a `StatelessWidget` that used `TextFormField`'s
/// `initialValue` whenever no controller was supplied. That made typed input
/// fragile: `initialValue` only seeds the field once, so on parent rebuilds a
/// bare value could fail to render/update and form resets wouldn't clear it.
/// Now the widget either drives the caller's controller or owns a stable
/// internal one, so typed text always renders and updates live.
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

  /// The controller every edit goes through: the caller's when provided,
  /// otherwise our own stable instance.
  TextEditingController get _controller =>
      widget.controller ?? (_internal ??= TextEditingController(text: widget.value));

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
    // Uncontrolled mode: mirror programmatic changes to `value` (e.g. a form
    // reset setting the bound string back to '') without clobbering text the
    // user is actively editing, which only differs when the parent changed it.
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
