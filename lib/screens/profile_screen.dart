import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/farmora_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/primary_button.dart';
import '../services/farm_service.dart';
import '../services/supabase_client.dart';
import '../utils/app_route.dart';
import 'edit_profile_screen.dart';

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

  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final p = await FarmService.fetchMyProfile();
      if (mounted) setState(() => _profile = p);
    } catch (e) {
      if (mounted) {
        setState(() {}); // keep _profile null; header shows fallback
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.of(context).push<bool>(
      SlideFadeRoute<bool>(
        EditProfileScreen(profile: _profile),
      ),
    );
    // Refresh from Supabase if the edit screen reported a save.
    if (updated == true) await _loadProfile();
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Sign out of your Farmora account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: FarmoraColors.crit),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true) widget.onSignOut();
  }

  Future<void> _copyEmail() async {
    final email = _profile?.email;
    if (email == null || email.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: email));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email copied to clipboard')),
      );
    }
  }

  String _orDash(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Not set' : v;

  Future<void> _changePassword() async {
    final email = _profile?.email;
    if (email == null || email.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change password'),
        content: Text(
            'A password reset link will be sent to your verified email:\n$email'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await supabase.auth.resetPasswordForEmail(email);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Reset link sent to $email')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Could not send reset link: $e')),
                  );
                }
              }
            },
            child: const Text('Send link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
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
                alignment: Alignment.center,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        p?.initials ?? '?',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: FarmoraColors.brand,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p?.displayName ?? (_loading ? 'Loading…' : 'Farmora user'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800, color: FarmoraColors.ink),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      p?.role ?? '—',
                      style: const TextStyle(fontSize: 12, color: FarmoraColors.inkSoft),
                    ),
                    const SizedBox(height: 6),
                    StatusBadge(
                      level: (p?.emailConfirmed ?? false) ? 'good' : 'warn',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (p?.emailConfirmed ?? false)
                                ? Icons.check_circle_outline
                                : Icons.pending_outlined,
                            size: 11,
                          ),
                          const SizedBox(width: 4),
                          Text((p?.emailConfirmed ?? false)
                              ? 'VERIFIED · ${p?.userId.substring(0, 4).toUpperCase() ?? ''}'
                              : 'EMAIL NOT VERIFIED'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: p == null ? null : _openEditProfile,
                tooltip: 'Edit profile',
                icon: const Icon(Icons.edit_outlined, size: 20, color: FarmoraColors.brand),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SettingsSection(
                title: 'PERSONAL INFORMATION',
                children: [
                  _ReadonlyRow(label: 'Full name', value: _orDash(p?.fullName)),
                  const Divider(height: 1, color: FarmoraColors.line),
                  _ReadonlyRow(
                    label: 'Email address',
                    value: _orDash(p?.email),
                    trailing: (p?.email.isNotEmpty ?? false)
                        ? InkWell(
                            onTap: _copyEmail,
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.copy_all_outlined,
                                  size: 15, color: FarmoraColors.inkFaint),
                            ),
                          )
                        : null,
                  ),
                  const Divider(height: 1, color: FarmoraColors.line),
                  _ReadonlyRow(label: 'Phone number', value: _orDash(p?.phone)),
                  const Divider(height: 1, color: FarmoraColors.line),
                  _ReadonlyRow(label: 'Operating location', value: _orDash(p?.location)),
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
                    onTap: _changePassword,
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
                text: 'Edit profile',
                onClick: p == null ? null : _openEditProfile,
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                text: 'Sign out account',
                danger: true,
                onClick: _confirmSignOut,
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
  final Widget? trailing;

  const _ReadonlyRow({required this.label, required this.value, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: FarmoraColors.inkFaint)),
          Flexible(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: FarmoraColors.ink, fontWeight: FontWeight.w500),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
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
