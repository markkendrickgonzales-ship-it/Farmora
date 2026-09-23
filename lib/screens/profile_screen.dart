import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/farmora_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/primary_button.dart';

class ProfileScreen extends StatefulWidget {
  final ValueChanged<String> go;
  final VoidCallback onSignOut;

  const ProfileScreen({
    super.key,
    required this.go,
    required this.onSignOut,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _push = true;
  bool _contrast = false;
  bool _biometric = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
          decoration: const BoxDecoration(
            color: FarmoraColors.surface,
            border: Border(bottom: BorderSide(color: FarmoraColors.line)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: FarmoraColors.brandSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, size: 26, color: FarmoraColors.brand),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Silas Thorne',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: FarmoraColors.ink),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Senior farm manager',
                    style: TextStyle(fontSize: 12, color: FarmoraColors.inkSoft),
                  ),
                  SizedBox(height: 6),
                  StatusBadge(
                    level: 'good',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 11),
                        SizedBox(width: 4),
                        Text('VERIFIED · ID FM-1044'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _SettingsSection(
                title: 'PERSONAL INFORMATION',
                children: [
                  _ReadonlyRow(label: 'Full name', value: 'Silas Thorne'),
                  Divider(height: 1, color: FarmoraColors.line),
                  _ReadonlyRow(label: 'Email address', value: 'silas.thorne@farmora.io'),
                  Divider(height: 1, color: FarmoraColors.line),
                  _ReadonlyRow(label: 'Phone number', value: '+1 (208) 555-0148'),
                  Divider(height: 1, color: FarmoraColors.line),
                  _ReadonlyRow(label: 'Operating location', value: 'Barn Complex 01, Sector B'),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: 'APPLICATION CONFIGURATION',
                children: [
                  _ToggleRow(
                    icon: Icons.notifications_none_outlined,
                    label: 'Push notifications',
                    value: _push,
                    onChanged: (val) => setState(() => _push = val),
                  ),
                  const Divider(height: 1, color: FarmoraColors.line),
                  _ToggleRow(
                    icon: Icons.remove_red_eye_outlined,
                    label: 'High contrast mode',
                    value: _contrast,
                    onChanged: (val) => setState(() => _contrast = val),
                  ),
                  const Divider(height: 1, color: FarmoraColors.line),
                  const _ClickRow(icon: Icons.language_outlined, label: 'Language', value: 'English (US)'),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: 'SECURITY',
                children: [
                  _ClickRow(
                    icon: Icons.phone_android_outlined,
                    label: 'Connected devices',
                    value: '3 active',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Connected devices: Mobile App, Web Console, Field Tablet')),
                      );
                    },
                  ),
                  const Divider(height: 1, color: FarmoraColors.line),
                  _ClickRow(
                    icon: Icons.security_outlined,
                    label: 'Change password',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password reset link sent to silas.thorne@farmora.io')),
                      );
                    },
                  ),
                  const Divider(height: 1, color: FarmoraColors.line),
                  _ToggleRow(
                    icon: Icons.fingerprint,
                    label: 'Biometric login',
                    value: _biometric,
                    onChanged: (val) => setState(() => _biometric = val),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: 'SUPPORT',
                children: [
                  _ClickRow(
                    icon: Icons.help_outline,
                    label: 'Help & knowledge base',
                    onTap: () => widget.go('feedback'),
                  ),
                  const Divider(height: 1, color: FarmoraColors.line),
                  _ClickRow(
                    icon: Icons.info_outline,
                    label: 'About Farmora',
                    value: 'v2.4.0',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Farmora Precision Agriculture OS v2.4.0')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                text: 'Sign out account',
                danger: true,
                onClick: widget.onSignOut,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: FarmoraColors.inkFaint,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        FarmoraCard(
          padding: const EdgeInsets.all(4),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ReadonlyRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReadonlyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: FarmoraColors.inkFaint)),
          Text(value, style: const TextStyle(fontSize: 13, color: FarmoraColors.ink, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: FarmoraColors.inkSoft),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontSize: 13, color: FarmoraColors.ink)),
            ],
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: FarmoraColors.brand,
          ),
        ],
      ),
    );
  }
}

class _ClickRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  const _ClickRow({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: FarmoraColors.inkSoft),
                const SizedBox(width: 10),
                Text(label, style: const TextStyle(fontSize: 13, color: FarmoraColors.ink)),
              ],
            ),
            Row(
              children: [
                if (value != null) ...[
                  Text(value!, style: const TextStyle(fontSize: 12, color: FarmoraColors.inkFaint)),
                  const SizedBox(width: 4),
                ],
                const Icon(Icons.chevron_right, size: 14, color: FarmoraColors.inkFaint),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
