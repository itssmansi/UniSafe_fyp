import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_background.dart';
import 'widgets/auth_slide_route.dart';
import 'widgets/otp_box_input.dart';
import 'widgets/custom_form_button.dart';
import 'new_password_screen.dart';

class ResetPasswordOtpScreen extends StatefulWidget {
  final String email;

  const ResetPasswordOtpScreen({
    super.key,
    required this.email,
  });

  @override
  State<ResetPasswordOtpScreen> createState() => _ResetPasswordOtpScreenState();
}

class _ResetPasswordOtpScreenState extends State<ResetPasswordOtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  String _otpCode = '';
  String? _errorMessage;
  bool _isSubmitting = false;
  bool _isResending = false;

  int _resendSeconds = 30;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendSeconds = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyOtp() async {
    if (_otpCode.length < 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits of the code.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await SupabaseConfig.client.auth.verifyOTP(
        email: widget.email,
        token: _otpCode,
        type: OtpType.recovery,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      Navigator.push(
        context,
        createAuthSlideRoute(
          NewPasswordScreen(email: widget.email),
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
        _errorMessage = 'Invalid or expired verification code: $e';
      });
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendSeconds > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      await SupabaseConfig.client.auth.resetPasswordForEmail(widget.email);

      if (!mounted) return;
      setState(() {
        _isResending = false;
      });

      _startResendTimer();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A new 6-digit recovery code was sent to ${widget.email}'),
          backgroundColor: const Color(0xFF133838),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _errorMessage = 'Failed to resend code: $e';
      });
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
                      title: 'VERIFY CODE',
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
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Enter Verification Code',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF133838),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'We sent a 6-digit code to\n${widget.email}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Color(0xFF64748B),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // 6-digit OTP Input
                              OtpBoxInput(
                                length: 6,
                                controller: _otpController,
                                onChanged: (code) {
                                  setState(() {
                                    _otpCode = code;
                                    _errorMessage = null;
                                  });
                                },
                                onCompleted: (code) {
                                  _handleVerifyOtp();
                                },
                              ),

                              if (_errorMessage != null) ...[
                                const SizedBox(height: 14),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 24),
                              CustomFormButton(
                                innerText: 'Verify Code',
                                onPressed: _handleVerifyOtp,
                                isLoading: _isSubmitting,
                              ),
                              const SizedBox(height: 20),

                              // Resend Code
                              GestureDetector(
                                onTap: _resendSeconds == 0 ? _handleResendOtp : null,
                                child: Text(
                                  _resendSeconds > 0
                                      ? 'Resend code in ${_resendSeconds}s'
                                      : 'Didn\'t receive code? Resend Code',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _resendSeconds > 0
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF133838),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
