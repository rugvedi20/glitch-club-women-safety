import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class AgreeTermsTextCard extends StatelessWidget {
  const AgreeTermsTextCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: RichText(
        text: TextSpan(
          text: 'By signing up you agree to our ',
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w400, color: Colors.grey),
          children: [
            TextSpan(
                text: 'Terms',
                recognizer: TapGestureRecognizer()..onTap = () {},
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey)),
            const TextSpan(
                text: ' and ',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey)),
            TextSpan(
                text: 'Conditions of Use',
                recognizer: TapGestureRecognizer()..onTap = () {},
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey)),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class TextWithDivider extends StatelessWidget {
  const TextWithDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.grey,
          ),
        ),
        SizedBox(width: 20),
        Text(
          'Or Sign In with',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.grey,
          ),
        ),
        SizedBox(width: 20),
        Expanded(
          child: Divider(color: Colors.grey),
        ),
      ],
    );
  }
}
