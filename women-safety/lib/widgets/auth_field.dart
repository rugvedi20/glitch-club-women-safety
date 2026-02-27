import 'package:flutter/material.dart';

/// A generic text field used throughout the authentication flows.
///
/// All validation logic is passed in via the [validator] callback.
class AuthField extends StatelessWidget {
  final String title;
  final String hintText;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;

  const AuthField({
    required this.title,
    required this.hintText,
    required this.controller,
    this.validator,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.black)),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          validator: validator,
          obscureText: isPassword,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          decoration: InputDecoration(
            hintText: hintText,
            fillColor: const Color(0xFFF6F6F6),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
