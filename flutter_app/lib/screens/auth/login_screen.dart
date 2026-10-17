import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../theme/unisafe_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final identifierController = TextEditingController();
  final passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool isLoading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    identifierController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final identifier =
          identifierController.text.trim();

      final password = passwordController.text;

      AuthResponse response;

      // --------------------------------------------------------
      // Detect Email or Phone
      // --------------------------------------------------------

      if (identifier.contains('@')) {
        response = await _authService.loginWithEmail(
          email: identifier,
          password: password,
        );
      } else {
        response = await _authService.loginWithPhone(
          phone: identifier,
          password: password,
        );
      }

      if (!mounted) return;

      if (response.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Login successful!',
            ),
          ),
        );

        // We will connect this to your actual
        // UniSafe home screen later.
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Login failed.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Something went wrong: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UniSafeColors.canvas,
      appBar: AppBar(
        title: const Text('Welcome back', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: UniSafeColors.canvas,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 50),

                Container(width: 76, height: 76, decoration: BoxDecoration(color: UniSafeColors.mint, borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.shield_outlined, color: UniSafeColors.navy, size: 38)),

                const SizedBox(height: 25),

                const Text(
                  'Welcome Back',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Login to your UniSafe account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 40),

                // ------------------------------------------------
                // Email / Phone
                // ------------------------------------------------

                TextFormField(
                  controller: identifierController,
                  keyboardType:
                      TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email or Phone',
                    hintText:
                        'Enter email or 10-digit phone',
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    final identifier =
                        value?.trim() ?? '';

                    if (identifier.isEmpty) {
                      return 'Please enter your email or phone';
                    }

                    if (identifier.contains('@')) {
                      final emailRegex = RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      );

                      if (!emailRegex
                          .hasMatch(identifier)) {
                        return 'Enter a valid email';
                      }
                    } else {
                      if (!RegExp(r'^\d{10}$')
                          .hasMatch(identifier)) {
                        return 'Enter a valid 10-digit phone number';
                      }
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // ------------------------------------------------
                // Password
                // ------------------------------------------------

                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                    prefixIcon:
                        const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          obscurePassword =
                              !obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty) {
                      return 'Please enter your password';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 28),

                // ------------------------------------------------
                // Login button
                // ------------------------------------------------

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        isLoading ? null : _login,
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
