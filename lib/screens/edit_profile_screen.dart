import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/screen_header.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/farmora_card.dart';
import '../services/farm_service.dart';

/// Editing flow for the signed-in user's profile. Saves through
/// [FarmService.updateMyProfile] and pops with `true` so the caller can
/// refresh.
class EditProfileScreen extends StatefulWidget {
  final UserProfile? profile;

  const EditProfileScreen({super.key, this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _role;
  late final TextEditingController _phone;
  late final TextEditingController _location;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p?.fullName ?? '');
    _role = TextEditingController(text: p?.role ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
    _location = TextEditingController(text: p?.location ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _phone.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FarmService.updateMyProfile(
        fullName: _name.text.trim(),
        role: _role.text.trim(),
        phone: _phone.text.trim(),
        location: _location.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save changes: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancel() {
    if (_saving) return;
    Navigator.pop(context, false);
  }

  Widget _field(String label, TextEditingController controller,
      {String? hint, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: FarmoraColors.inkSoft,
            ),
          ),
          const SizedBox(height: 6),
          CustomTextField(
            placeholder: hint ?? label,
            controller: controller,
            keyboardType: keyboardType,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmoraColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Edit profile',
              subtitle: 'Update your personal information',
              onBack: _cancel,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FarmoraCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _field('Full name', _name, hint: 'e.g. Jordan Rivera'),
                        _field('Role / title', _role,
                            hint: 'e.g. Senior farm manager'),
                        _field(
                          'Phone number',
                          _phone,
                          hint: 'e.g. +1 (208) 555-0148',
                          keyboardType: TextInputType.phone,
                        ),
                        _field(
                          'Operating location',
                          _location,
                          hint: 'e.g. Barn Complex 01, Sector B',
                        ),
                      ],
                    ),
                  ),
                  if (widget.profile?.email != null) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Signed in as ${widget.profile!.email}',
                        style: TextStyle(
                            fontSize: 11.5, color: FarmoraColors.inkFaint),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: FarmoraColors.crit, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 24),
                  PrimaryButton(
                    text: _saving ? 'Saving…' : 'Save changes',
                    disabled: _saving,
                    onClick: _save,
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    text: 'Cancel',
                    disabled: _saving,
                    onClick: _cancel,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
