import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/screen_header.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/farmora_logo.dart';
import '../services/supabase_client.dart';

/// Dedicated sign-up screen, pushed as a full-screen route from the Login
/// screen (breadcrumb-free; reached via "Create account"). Wired directly to
/// Supabase Auth via [supabase]. Back returns to Login.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showPw = false;
  bool _showConfirm = false;
  bool _loading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _errorMsg = 'Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMsg = 'Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMsg = 'Passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final res = await Supabase.instance.client
          .auth
          .signUp(email: email, password: password);

      if (!mounted) return;

      if (res.session != null) {
        // Email confirmation is disabled: the user is signed in immediately.
        // Pop back to the shell, whose auth listener has already routed home.
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        // Confirmation required — return to Login with guidance.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Account created. Check $email to confirm, then sign in.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop();
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: FarmoraColors.inkSoft,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmoraColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(
              title: 'Create account',
              subtitle: 'Join Farmora in a few seconds',
              leading: FarmoraLogo(size: 34),
              // No onBack: ScreenHeader falls back to Navigator.pop, which is
              // correct because this screen is a real pushed route.
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _label('Email address'),
                  CustomTextField(
                    placeholder: 'you@farmora.com',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _label('Password'),
                  CustomTextField(
                    placeholder: 'At least 6 characters',
                    controller: _passwordCtrl,
                    isPassword: true,
                    obscureText: !_showPw,
                    onTogglePassword: () => setState(() => _showPw = !_showPw),
                  ),
                  const SizedBox(height: 16),
                  _label('Confirm password'),
                  CustomTextField(
                    placeholder: 'Re-enter your password',
                    controller: _confirmCtrl,
                    isPassword: true,
                    obscureText: !_showConfirm,
                    onTogglePassword: () =>
                        setState(() => _showConfirm = !_showConfirm),
                  ),
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _errorMsg!,
                      style: TextStyle(
                        color: FarmoraColors.crit,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  PrimaryButton(
                    text: _loading ? 'Creating account…' : 'Create account',
                    disabled: _loading,
                    onClick: _loading ? () {} : _submit,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style:
                            TextStyle(fontSize: 12.5, color: FarmoraColors.inkSoft),
                      ),
                      TextButton(
                        onPressed:
                            _loading ? null : () => Navigator.of(context).pop(),
                        child: Text(
                          'Sign in',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: FarmoraColors.brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your credentials are protected by end-to-end encrypted transport.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: FarmoraColors.inkFaint,
                      height: 1.5,
                    ),
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
