import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../theme/unisafe_theme.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_background.dart';
import 'widgets/auth_slide_route.dart';
import 'widgets/rounded_input_field.dart';
import 'widgets/custom_form_button.dart';
import 'reset_password_otp_screen.dart';

class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleForgetPassword() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });

      try {
        await SupabaseConfig.client.auth.resetPasswordForEmail(email);

        if (!mounted) return;
        setState(() => _isSubmitting = false);

        Navigator.push(
          context,
          createAuthSlideRoute(
            ResetPasswordOtpScreen(email: email),
          ),
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
          _errorMessage = 'Could not send reset code: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UniSafeColors.canvas,
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
                    child: const AuthHeader(
                      title: 'RESET PASSWORD',
                      isCentered: true,
                      showBackButton: false,
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
                          padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
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
                                  controller: _emailController,
                                  labelText: 'Email Address',
                                  hintText: 'wadewarren@gmail.com',
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Email is required!';
                                    }
                                    if (!value.contains('@') || !value.contains('.')) {
                                      return 'Please enter a valid email address';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 22),
                                CustomFormButton(
                                  innerText: 'Send Verification Code',
                                  onPressed: _handleForgetPassword,
                                  isLoading: _isSubmitting,
                                ),
                                const SizedBox(height: 18),
                                GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: const Text(
                                    'Back to login',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: UniSafeColors.blue,
                                      fontWeight: FontWeight.w700,
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
