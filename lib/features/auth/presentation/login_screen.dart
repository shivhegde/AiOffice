import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_theme.dart';
import '../application/auth_providers.dart';
import '../data/auth_repository.dart';
import 'widgets/password_field.dart';

/// Mirrors the prototype's login card: brand mark, serif title, email +
/// password fields, "Forgot password?" link, primary sign-in button,
/// loading/error states as snackbars — per REQUIREMENTS.md §5.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_submitting) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showSnack('Enter your email and password.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(authRepositoryProvider).signIn(email: email, password: password);
    } catch (e) {
      if (mounted) _showSnack(AuthRepository.friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack('Enter your email address first, then tap "Forgot password?".');
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      if (mounted) _showSnack('Password reset email sent to $email.');
    } catch (e) {
      if (mounted) _showSnack(AuthRepository.friendlyErrorMessage(e));
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colors.ink900,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 50, offset: Offset(0, 20))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            'O',
                            style: AppFonts.serif(fontWeight: FontWeight.w700, color: colors.onAccent),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('OfficeAI', style: AppFonts.serif(fontWeight: FontWeight.w700, fontSize: 16.5)),
                            Text(
                              'REGISTRY & TASK CONSOLE',
                              style: TextStyle(fontSize: 10.5, letterSpacing: 0.8, color: colors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text('Sign in', style: AppFonts.serif(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      'Enter your registered work email to continue.',
                      style: TextStyle(fontSize: 12.8, color: colors.textMuted),
                    ),
                    const SizedBox(height: 22),
                    const _FieldLabel('Email address'),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                    ),
                    const SizedBox(height: 13),
                    const _FieldLabel('Password'),
                    PasswordField(controller: _passwordController, onSubmitted: (_) => _signIn()),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submitting ? null : _signIn,
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Sign in'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _forgotPassword,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          child: const Text('Forgot password?'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(text, style: const TextStyle(fontSize: 11.8)),
    );
  }
}
