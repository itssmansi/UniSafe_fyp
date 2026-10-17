import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_background.dart';
import 'widgets/auth_slide_route.dart';
import 'widgets/rounded_input_field.dart';
import 'widgets/custom_form_button.dart';
import 'login_screen.dart';

class NewPasswordScreen extends StatefulWidget {
  final String email;

  const NewPasswordScreen({
    super.key,
    required this.email,
  });

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdatePassword() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });

      try {
        await SupabaseConfig.client.auth.updateUser(
          UserAttributes(password: _passwordController.text),
        );

        if (!mounted) return;
        setState(() => _isSubmitting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Password updated successfully! Please login with your new password.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        // Sign out recovery session cleanly so user logs in afresh
        await SupabaseConfig.client.auth.signOut();

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          createAuthSlideRoute(const CitizenLoginScreen()),
          (route) => false,
        );
      } on AuthException catch (e) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.message;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Could not update password: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B3B68), // Dark Forest Teal
      body: Stack(
        children: [
          // Full-screen continuous green doodle background
          const AuthBackground(),

          SafeArea(
            child: Column(
              children: [
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
                      title: 'NEW PASSWORD',
                      onBack: () => Navigator.of(context).pop(),
                      isCentered: true,
                    ),
                  ),
                ),
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
                          padding: const EdgeInsets.fromLTRB(0, 20, 0, 28),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Create New Password',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0B3B68),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Your new password must be at least 6 characters.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 18),

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
                                  const SizedBox(height: 10),
                                ],

                                RoundedInputField(
                                  controller: _passwordController,
                                  labelText: 'New Password',
                                  hintText: '••••••••',
                                  obscureText: true,
                                  suffixIcon: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Password is required';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),

                                RoundedInputField(
                                  controller: _confirmPasswordController,
                                  labelText: 'Confirm Password',
                                  hintText: '••••••••',
                                  obscureText: true,
                                  suffixIcon: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please confirm your password';
                                    }
                                    if (value != _passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 22),

                                CustomFormButton(
                                  innerText: 'Update Password',
                                  onPressed: _handleUpdatePassword,
                                  isLoading: _isSubmitting,
                                ),
                                const SizedBox(height: 18),

                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).pushNamedAndRemoveUntil(
                                      '/citizen-auth-login',
                                      (route) => false,
                                    );
                                  },
                                  child: const Text(
                                    'Cancel and back to login',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF0B3B68),
                                      fontWeight: FontWeight.w600,
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
