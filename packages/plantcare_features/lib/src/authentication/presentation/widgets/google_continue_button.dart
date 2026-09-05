import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Uses Google's official G artwork and prescribed light button branding.
class GoogleContinueButton extends StatelessWidget {
  const GoogleContinueButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return OutlinedButton(
      key: const ValueKey('continue-with-google'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff1f1f1f),
        side: const BorderSide(color: Color(0xff747775)),
        minimumSize: const Size(0, 48),
        padding: EdgeInsets.symmetric(
          horizontal: isIos ? 16 : 12,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(
          fontFamily: 'GoogleSans',
          package: 'plantcare_features',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/auth/google_g.png',
            package: 'plantcare_features',
            width: 20,
            height: 20,
            excludeFromSemantics: true,
          ),
          SizedBox(width: isIos ? 12 : 10),
          const Flexible(child: Text('Continue with Google')),
        ],
      ),
    );
  }
}
