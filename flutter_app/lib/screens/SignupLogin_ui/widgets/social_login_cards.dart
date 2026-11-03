import 'dart:convert';
import 'package:flutter/material.dart';

const String _kGoogleLogoBase64 =
    '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';

class SocialLoginCards extends StatelessWidget {
  final VoidCallback? onGooglePressed;
  final VoidCallback? onFacebookPressed;

  const SocialLoginCards({
    super.key,
    this.onGooglePressed,
    this.onFacebookPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Text(
            'Or login with',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),

          // Side-by-side Google and Facebook cards
          Row(
            children: [
              // Google Button Card
              Expanded(
                child: InkWell(
                  onTap: onGooglePressed,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.memory(
                          base64Decode(_kGoogleLogoBase64),
                          width: 20,
                          height: 20,
                          filterQuality: FilterQuality.high,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Google',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Facebook Button Card
              Expanded(
                child: InkWell(
                  onTap: onFacebookPressed,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.facebook,
                          color: Color(0xFF1877F2),
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Facebook',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
