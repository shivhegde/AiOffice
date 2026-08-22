import 'package:flutter/material.dart';

/// Prototype's `.pw-wrap` — a password field with a text "Show"/"Hide"
/// toggle rather than an icon, matching the login screen's copy.
class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.controller, this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        suffixIcon: TextButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          child: Text(_obscure ? 'Show' : 'Hide', style: const TextStyle(fontSize: 11.5)),
        ),
      ),
    );
  }
}
