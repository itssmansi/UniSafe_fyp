import 'package:flutter/material.dart';

import '../../theme/unisafe_theme.dart';
import 'authority_login_screen.dart';
import 'login_screen.dart';
import '../SignupLogin_ui/signup_screen.dart';

class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [UniSafeColors.ink, UniSafeColors.navy, Color(0xFF176BBA)])),
            child: SizedBox.expand(),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Icon(Icons.shield_outlined, color: Colors.white, size: 54),
                    const SizedBox(height: 20),
                    const Text('UniSafe', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1.2)),
                    const SizedBox(height: 8),
                    const Text('A safer city starts with an informed community.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFD9EDFF), fontSize: 15, height: 1.45)),
                    const SizedBox(height: 36),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const Text('Continue as a citizen', style: TextStyle(color: UniSafeColors.ink, fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        const Text('Report, track, and help improve your neighbourhood.', style: TextStyle(color: UniSafeColors.mutedInk, fontSize: 13, height: 1.4)),
                        const SizedBox(height: 22),
                        _AuthAction(label: 'Log in', icon: Icons.login_rounded, primary: true, onTap: () => Navigator.push(context, UniSafePageRoute(builder: (_) => const LoginScreen()))),
                        const SizedBox(height: 12),
                        _AuthAction(label: 'Create an account', icon: Icons.person_add_alt_1_outlined, onTap: () => Navigator.push(context, UniSafePageRoute(builder: (_) => const CitizenSignupScreen()))),
                        const SizedBox(height: 18),
                        const Divider(color: UniSafeColors.line),
                        TextButton.icon(onPressed: () => Navigator.push(context, UniSafePageRoute(builder: (_) => const AuthorityLoginScreen())), icon: const Icon(Icons.admin_panel_settings_outlined, size: 18), label: const Text('Authority access')),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      );
}

class _AuthAction extends StatelessWidget {
  const _AuthAction({required this.label, required this.icon, required this.onTap, this.primary = false});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 54,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 19),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(elevation: 0, backgroundColor: primary ? UniSafeColors.navy : Colors.white, foregroundColor: primary ? Colors.white : UniSafeColors.navy, side: primary ? BorderSide.none : const BorderSide(color: UniSafeColors.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        ),
      );
}
