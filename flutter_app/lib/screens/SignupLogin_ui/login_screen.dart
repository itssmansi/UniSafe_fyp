import 'dart:async';
import 'package:flutter/material.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_background.dart';
import 'widgets/rounded_input_field.dart';
import 'widgets/custom_form_button.dart';
import 'widgets/auth_slide_route.dart';
import 'forget_password_screen.dart';
import 'signup_screen.dart';

class CitizenLoginScreen extends StatefulWidget {
  const CitizenLoginScreen({super.key});

  @override
  State<CitizenLoginScreen> createState() => _CitizenLoginScreenState();
}

class _CitizenLoginScreenState extends State<CitizenLoginScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _fillDemoCredentials() {
    setState(() {
      _identifierController.text = 'citizen@unisafe.org';
      _passwordController.text = 'safety123';
      _errorMessage = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Demo credentials filled (citizen@unisafe.org / safety123)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF133838),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_loginFormKey.currentState!.validate()) {
      return;
    }

    final String identifier = _identifierController.text.trim();
    final String password = _passwordController.text;

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final bool isAuthorized = (identifier.isNotEmpty && password.length >= 6);

    if (isAuthorized) {
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Login successful! Redirecting to dashboard...',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Login not successful: Incorrect email, phone or password.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF133838), // Deep Forest Teal Header Canvas
      body: Stack(
        children: [
          // Full-screen continuous green doodle background
          const AuthBackground(),

          SafeArea(
            child: Column(
              children: [
                // Teal Top Area (~48% of screen height) with centered LOGIN
            Expanded(
              child: AnimatedBuilder(
                animation: ModalRoute.of(context)?.animation ?? const AlwaysStoppedAnimation(1.0),
                builder: (context, child) {
                  final anim = ModalRoute.of(context)?.animation;
                  final double opacity = anim != null
                      ? Curves.easeOutCubic.transform(anim.value)
                      : 1.0;
                  return Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: child,
                  );
                },
                child: AuthHeader(
                  title: 'LOGIN',
                  isCentered: true,
                  onBack: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pushReplacementNamed('/home');
                    }
                  },
                ),
              ),
            ),

            // White Card Form Area: wraps exact content needed
            AnimatedBuilder(
                animation: Listenable.merge([
                  ModalRoute.of(context)?.animation ?? const AlwaysStoppedAnimation(1.0),
                  ModalRoute.of(context)?.secondaryAnimation ?? const AlwaysStoppedAnimation(0.0),
                ]),
                builder: (context, child) {
                  final anim = ModalRoute.of(context)?.animation;
                  final double t = anim != null
                      ? Curves.easeOutCubic.transform(anim.value)
                      : 1.0;
                  final double enterDy = (1.0 - t) * 160.0;
                  final double enterOpacity = anim != null
                      ? Curves.easeOut.transform(anim.value)
                      : 1.0;

                  final secAnim = ModalRoute.of(context)?.secondaryAnimation;
                  final double secT = secAnim != null
                      ? Curves.easeOutCubic.transform(secAnim.value)
                      : 0.0;
                  final double secDy = -secT * 50.0;
                  final double secOpacity = (1.0 - secT * 1.5).clamp(0.0, 1.0);

                  return Transform.translate(
                    offset: Offset(0, enterDy + secDy),
                    child: Opacity(
                      opacity: (enterOpacity * secOpacity).clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
                      child: Form(
                        key: _loginFormKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Error message if any
                            if (_errorMessage != null) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFFECACA)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(
                                            color: Color(0xFFDC2626),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],

                            // Email / Phone Number Field
                            RoundedInputField(
                              controller: _identifierController,
                              labelText: 'Email / Phone Number',
                              hintText: 'wadewarren@gmail.com',
                              keyboardType: TextInputType.emailAddress,
                              validator: (textValue) {
                                if (textValue == null || textValue.trim().isEmpty) {
                                  return 'Email or phone number is required!';
                                }
                                final trimmed = textValue.trim();
                                final cleanPhone = trimmed.replaceAll(' ', '').replaceFirst('+91', '');
                                final isPhone = RegExp(r'^[0-9]{10}$').hasMatch(cleanPhone);
                                final isEmail = trimmed.contains('@') && trimmed.contains('.');
                                if (!isEmail && !isPhone) {
                                  return 'Please enter a valid email or 10-digit mobile number';
                                }
                                return null;
                              },
                            ),

                            // Password Field
                            RoundedInputField(
                              controller: _passwordController,
                              labelText: 'Password',
                              hintText: '••••••••',
                              obscureText: true,
                              suffixIcon: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleLogin(),
                              validator: (textValue) {
                                if (textValue == null || textValue.isEmpty) {
                                  return 'Password is required!';
                                }
                                if (textValue.length < 6) {
                                  return 'Password must be at least 6 characters!';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 4),

                            // Remember Me & Forgot Password Row
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Remember Me Checkbox
                                  InkWell(
                                    onTap: () {
                                      setState(() => _rememberMe = !_rememberMe);
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: Checkbox(
                                            value: _rememberMe,
                                            onChanged: (val) {
                                              setState(() => _rememberMe = val ?? false);
                                            },
                                            activeColor: const Color(0xFF133838),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                            side: const BorderSide(
                                              color: Color(0xFFCBD5E1),
                                              width: 1.4,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Remember Me',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Forgot Password Link
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        createAuthSlideRoute(
                                          const ForgetPasswordScreen(),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: Color(0xFF133838),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),

                            // Login Button
                            CustomFormButton(
                              innerText: 'Login',
                              onPressed: _handleLogin,
                              isLoading: _isLoading,
                            ),
                            const SizedBox(height: 18),

                            // Don't have an account ? Sign-up
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Don't have an account ? ",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      createAuthSlideRoute(
                                        const CitizenSignupScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Sign-up',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF133838),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),

                            // Discrete Autofill Demo Credential Chip
                            GestureDetector(
                              onTap: _fillDemoCredentials,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.vpn_key_outlined, size: 14, color: Color(0xFF64748B)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Demo: citizen@unisafe.org • Tap to fill',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

