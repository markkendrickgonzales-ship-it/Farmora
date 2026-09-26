import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../services/supabase_client.dart';
import '../utils/app_route.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onEnter;

  const LoginScreen({super.key, required this.onEnter});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _showPw = false;
  bool _loading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMsg = 'Please enter email and password.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      await supabase.auth.signInWithPassword(email: email, password: password);
      // Success is handled by MainShell's onAuthStateChange listener, which
      // swaps the shell to the home screen.
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openRegister() {
    Navigator.of(context).push(
      SlideFadeRoute(const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [FarmoraColors.heroTop, FarmoraColors.heroBottom],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Farmora',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: FarmoraColors.onHero,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Professional smart-farming management system',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: FarmoraColors.onHeroSoft,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -18),
          child: Container(
            decoration: BoxDecoration(
              color: FarmoraColors.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: FarmoraColors.ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sign in to manage your flock.',
                  style: TextStyle(
                    fontSize: 13,
                    color: FarmoraColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Email address',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: FarmoraColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 6),
                CustomTextField(
                  placeholder: 'you@farmora.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                Text(
                  'Account password',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: FarmoraColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 6),
                CustomTextField(
                  placeholder: 'Enter password',
                  controller: _passwordCtrl,
                  isPassword: true,
                  obscureText: !_showPw,
                  onTogglePassword: () => setState(() => _showPw = !_showPw),
                ),
                if (_errorMsg != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMsg!,
                    style: TextStyle(
                      color: FarmoraColors.crit,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                PrimaryButton(
                  text: _loading ? 'Loading...' : 'Sign In',
                  disabled: _loading,
                  onClick: _loading ? () {} : _submit,
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : _openRegister,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'New to Farmora?',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: FarmoraColors.inkSoft,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Create an account',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: FarmoraColors.brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Protected by end-to-end encrypted transport and on-device biometric verification.',
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
        ),
      ],
    );
  }
}
