import 'package:flutter/material.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_background.dart';
import 'widgets/rounded_input_field.dart';
import 'widgets/custom_form_button.dart';

class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleForgetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Password recovery link sent! Check your email.'),
          backgroundColor: const Color(0xFF133838),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF133838), // Dark Forest Teal
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
                      title: 'RESET PASSWORD',
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
                          padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
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
                                  innerText: 'Send Recovery Link',
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
                                      color: Color(0xFF133838),
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
