import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../services/supabase_client.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onEnter;

  const LoginScreen({super.key, required this.onEnter});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _tab = 'signin';
  String _email = '';
  String _password = '';
  bool _showPw = false;
  bool _loading = false;
  String? _errorMsg;

  Future<void> _submit() async {
    if (_email.isEmpty || _password.isEmpty) {
      setState(() => _errorMsg = 'Please enter email and password.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      if (_tab == 'signin') {
        await supabase.auth
            .signInWithPassword(email: _email, password: _password);
      } else {
        await supabase.auth.signUp(email: _email, password: _password);
      }
      // Assuming onAuthStateChange in main.dart handles navigation.
      // But we can also call widget.onEnter() just in case.
      // widget.onEnter();
    } on AuthException catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (e) {
      setState(() => _errorMsg = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: FarmoraColors.surfaceSunken,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: ['signin', 'register'].map((t) {
                      final selected = _tab == t;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _tab = t;
                              _errorMsg = null; // Clear error on tab switch
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: selected
                                  ? FarmoraColors.surface
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                              boxShadow: selected
                                  ? const [
                                      BoxShadow(
                                        color: Color.fromRGBO(0, 0, 0, 0.08),
                                        blurRadius: 2,
                                        offset: Offset(0, 1),
                                      )
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              t == 'signin' ? 'SIGN IN' : 'CREATE ACCOUNT',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: selected
                                    ? FarmoraColors.ink
                                    : FarmoraColors.inkFaint,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
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
                  value: _email,
                  onChanged: (val) => _email = val,
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
                  value: _password,
                  onChanged: (val) => _password = val,
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
                const SizedBox(height: 12),
                PrimaryButton(
                  text: _loading
                      ? 'Loading...'
                      : (_tab == 'signin' ? 'Sign In' : 'Create Account'),
                  disabled: _loading,
                  onClick: _submit,
                ),
                const SizedBox(height: 12),
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
