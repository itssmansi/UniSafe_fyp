import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/auth_header.dart';
import 'widgets/rounded_input_field.dart';
import 'widgets/custom_form_button.dart';
import 'widgets/step_progress_bar.dart';
import 'widgets/otp_box_input.dart';
import 'login_screen.dart';

class CitizenSignupScreen extends StatefulWidget {
  const CitizenSignupScreen({super.key});

  @override
  State<CitizenSignupScreen> createState() => _CitizenSignupScreenState();
}

class _CitizenSignupScreenState extends State<CitizenSignupScreen> {
  int _currentStep = 0; // 0 = Basic Details, 1 = Email OTP, 2 = Phone OTP, 3 = Aadhaar KYC
  bool _isLoading = false;
  String? _errorMessage;

  // Step 1 Controllers
  final _step1FormKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Step 2 (Email OTP)
  final TextEditingController _emailOtpController = TextEditingController();
  int _emailOtpTimerSeconds = 30;
  Timer? _emailOtpTimer;
  static const String _kDemoEmailOtp = '482910';

  // Step 3 (Phone OTP)
  final TextEditingController _phoneOtpController = TextEditingController();
  int _phoneOtpTimerSeconds = 30;
  Timer? _phoneOtpTimer;
  static const String _kDemoPhoneOtp = '739201';

  // Step 4 (Aadhaar KYC)
  final TextEditingController _aadhaarNumberController = TextEditingController();
  final TextEditingController _aadhaarOtpController = TextEditingController();
  bool _isAadhaarOtpSent = false;
  int _aadhaarOtpTimerSeconds = 30;
  Timer? _aadhaarOtpTimer;
  static const String _kDemoAadhaarNumber = '5482 9102 3847';
  static const String _kDemoAadhaarOtp = '992814';

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _emailOtpController.dispose();
    _phoneOtpController.dispose();
    _aadhaarNumberController.dispose();
    _aadhaarOtpController.dispose();
    _emailOtpTimer?.cancel();
    _phoneOtpTimer?.cancel();
    _aadhaarOtpTimer?.cancel();
    super.dispose();
  }

  String get _fullName {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    if (first.isEmpty && last.isEmpty) return 'Citizen';
    return '$first $last'.trim();
  }

  // Timer helpers
  void _startEmailOtpTimer() {
    _emailOtpTimer?.cancel();
    setState(() => _emailOtpTimerSeconds = 30);
    _emailOtpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_emailOtpTimerSeconds <= 1) {
        timer.cancel();
        setState(() => _emailOtpTimerSeconds = 0);
      } else {
        setState(() => _emailOtpTimerSeconds--);
      }
    });
  }

  void _startPhoneOtpTimer() {
    _phoneOtpTimer?.cancel();
    setState(() => _phoneOtpTimerSeconds = 30);
    _phoneOtpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_phoneOtpTimerSeconds <= 1) {
        timer.cancel();
        setState(() => _phoneOtpTimerSeconds = 0);
      } else {
        setState(() => _phoneOtpTimerSeconds--);
      }
    });
  }

  void _startAadhaarOtpTimer() {
    _aadhaarOtpTimer?.cancel();
    setState(() => _aadhaarOtpTimerSeconds = 30);
    _aadhaarOtpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_aadhaarOtpTimerSeconds <= 1) {
        timer.cancel();
        setState(() => _aadhaarOtpTimerSeconds = 0);
      } else {
        setState(() => _aadhaarOtpTimerSeconds--);
      }
    });
  }

  // --- Step 1 Actions ---
  void _fillStep1Demo() {
    setState(() {
      _firstNameController.text = 'Wade';
      _lastNameController.text = 'Warren';
      _emailController.text = 'wadewarren@gmail.com';
      _passwordController.text = 'SafetyPass@2026';
      _phoneController.text = '9876543210';
      _errorMessage = null;
    });
    _showToast('Demo details filled', icon: Icons.check_circle_outline);
  }

  void _submitStep1() async {
    FocusScope.of(context).unfocus();
    if (!_step1FormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _currentStep = 1;
    });
    _startEmailOtpTimer();
    _showToast('OTP code sent to ${_emailController.text}');
  }

  // --- Step 2 Actions (Email OTP) ---
  void _submitStep2() async {
    FocusScope.of(context).unfocus();
    final code = _emailOtpController.text.trim();
    if (code.length < 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit email OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _currentStep = 2;
    });
    _startPhoneOtpTimer();
    _showToast('Email verified! SMS OTP sent to +91 ${_phoneController.text}');
  }

  // --- Step 3 Actions (Phone OTP) ---
  void _submitStep3() async {
    FocusScope.of(context).unfocus();
    final code = _phoneOtpController.text.trim();
    if (code.length < 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit mobile SMS OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _currentStep = 3;
    });
    _showToast('Phone number verified! Proceeding to Aadhaar KYC.');
  }

  // --- Step 4 Actions (Aadhaar KYC) ---
  void _sendAadhaarOtp() async {
    FocusScope.of(context).unfocus();
    final rawNumber = _aadhaarNumberController.text.replaceAll(' ', '').trim();
    if (rawNumber.length != 12) {
      setState(() => _errorMessage = 'Please enter a valid 12-digit Aadhaar number.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _isAadhaarOtpSent = true;
    });
    _startAadhaarOtpTimer();
    _showToast('UIDAI verification code sent to Aadhaar-linked mobile');
  }

  void _completeRegistration() async {
    FocusScope.of(context).unfocus();
    final code = _aadhaarOtpController.text.trim();
    if (code.length < 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit UIDAI verification OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    setState(() => _isLoading = false);
    _showSuccessCelebrationModal();
  }

  void _showToast(String message, {IconData icon = Icons.info_outline}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF133838),
        duration: const Duration(milliseconds: 1600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessCelebrationModal() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF10B981),
                    size: 42,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Registration Successful!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF133838),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Welcome, $_fullName! Your email, phone, and Aadhaar identity have been verified.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF133838)),
                    const SizedBox(width: 8),
                    Text(
                      'Citizen ID: US-${DateTime.now().year % 100}-9421 • Verified',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF133838),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CitizenLoginScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF133838),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Proceed to Log-in',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleBackStep() {
    if (_currentStep > 0) {
      setState(() {
        _errorMessage = null;
        if (_currentStep == 3 && _isAadhaarOtpSent) {
          _isAadhaarOtpSent = false;
        } else {
          _currentStep--;
        }
      });
    } else {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CitizenLoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFF133838), // Dark Forest Teal canvas
        body: Column(
          children: [
            // Slim Dark Header matching sketch
            AuthHeader(
              title: _currentStep == 0 ? 'SIGN UP' : 'VERIFICATION',
              onBack: _handleBackStep,
            ),
            const SizedBox(height: 45),

            // White Card Content Area
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        // Step progress tracker
                        StepProgressBar(currentStep: _currentStep),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),

                        // Error Message Banner (if any)
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
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

                        // Current Step Form Content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 28),
                            child: _buildCurrentStepContent(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Details();
      case 1:
        return _buildStep2EmailOtp();
      case 2:
        return _buildStep3PhoneOtp();
      case 3:
        return _buildStep4AadhaarKyc();
      default:
        return const SizedBox.shrink();
    }
  }

  // ================= STEP 1: BASIC INFORMATION =================
  Widget _buildStep1Details() {
    return Form(
      key: _step1FormKey,
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Side-by-Side First Name & Last Name (matching left phone mockup)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: RoundedInputField(
                    controller: _firstNameController,
                    labelText: 'First Name',
                    hintText: 'Wade',
                    isHalfWidth: true,
                    keyboardType: TextInputType.name,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: RoundedInputField(
                    controller: _lastNameController,
                    labelText: 'Last Name',
                    hintText: 'Warren',
                    isHalfWidth: true,
                    keyboardType: TextInputType.name,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),

          // Email Field
          RoundedInputField(
            controller: _emailController,
            labelText: 'Email',
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

          // Password Field
          RoundedInputField(
            controller: _passwordController,
            labelText: 'Password',
            hintText: '••••••••',
            obscureText: true,
            suffixIcon: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required!';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters!';
              }
              return null;
            },
          ),

          // Mobile Number Field
          RoundedInputField(
            controller: _phoneController,
            labelText: 'Mobile Number',
            hintText: '10-digit number',
            prefixText: '+91 ',
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Mobile number is required!';
              }
              if (value.trim().length != 10) {
                return 'Please enter a valid 10-digit mobile number';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Register / Continue Button
          CustomFormButton(
            innerText: 'Register',
            onPressed: _submitStep1,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 16),

          // Already have an account ? Log-in
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Already have an account ? ',
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
                    MaterialPageRoute(
                      builder: (context) => const CitizenLoginScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Log-in',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF133838),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Demo Autofill Chip
          GestureDetector(
            onTap: _fillStep1Demo,
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
                  Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFF64748B)),
                  SizedBox(width: 6),
                  Text(
                    'Demo: Wade Warren • Tap to fill',
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
    );
  }

  // ================= STEP 2: EMAIL OTP =================
  Widget _buildStep2EmailOtp() {
    return Column(
      children: [
        const SizedBox(height: 12),
        // Subtitle Card with recipient info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF133838).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.mark_email_read_outlined, color: Color(0xFF133838), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Code sent to email address:',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _emailController.text.trim(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF133838),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _currentStep = 0),
                  child: const Text('Edit', style: TextStyle(color: Color(0xFF133838), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 6-digit OTP Box Input
        OtpBoxInput(
          controller: _emailOtpController,
          onChanged: (code) {
            if (_errorMessage != null) setState(() => _errorMessage = null);
          },
          onCompleted: (_) => _submitStep2(),
        ),
        const SizedBox(height: 18),

        // Demo Code Chip
        GestureDetector(
          onTap: () {
            setState(() {
              _emailOtpController.text = _kDemoEmailOtp;
              _errorMessage = null;
            });
            _showToast('Demo code auto-filled: $_kDemoEmailOtp');
          },
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
                  'Demo code: $_kDemoEmailOtp • Tap to fill',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Resend Timer Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Didn't receive the code? ",
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
            if (_emailOtpTimerSeconds > 0)
              Text(
                'Resend in 00:${_emailOtpTimerSeconds.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF133838),
                ),
              )
            else
              GestureDetector(
                onTap: () {
                  _startEmailOtpTimer();
                  _showToast('New code sent to ${_emailController.text}');
                },
                child: const Text(
                  'Resend Code',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF133838),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 28),

        // Verify Email Button
        CustomFormButton(
          innerText: 'Verify Email',
          onPressed: _submitStep2,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 16),

        // Back to step 1
        TextButton(
          onPressed: () => setState(() => _currentStep = 0),
          child: const Text(
            '← Back to Basic Details',
            style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // ================= STEP 3: PHONE OTP =================
  Widget _buildStep3PhoneOtp() {
    return Column(
      children: [
        const SizedBox(height: 12),
        // Subtitle Card with recipient info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF133838).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.sms_outlined, color: Color(0xFF133838), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SMS code sent to mobile:',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '+91 ${_phoneController.text.trim()}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF133838),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _currentStep = 0),
                  child: const Text('Edit', style: TextStyle(color: Color(0xFF133838), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 6-digit OTP Box Input
        OtpBoxInput(
          controller: _phoneOtpController,
          onChanged: (code) {
            if (_errorMessage != null) setState(() => _errorMessage = null);
          },
          onCompleted: (_) => _submitStep3(),
        ),
        const SizedBox(height: 18),

        // Demo Code Chip
        GestureDetector(
          onTap: () {
            setState(() {
              _phoneOtpController.text = _kDemoPhoneOtp;
              _errorMessage = null;
            });
            _showToast('Demo SMS code auto-filled: $_kDemoPhoneOtp');
          },
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
                  'Demo code: $_kDemoPhoneOtp • Tap to fill',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Resend Timer Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Didn't receive SMS? ",
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
            if (_phoneOtpTimerSeconds > 0)
              Text(
                'Resend in 00:${_phoneOtpTimerSeconds.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF133838),
                ),
              )
            else
              GestureDetector(
                onTap: () {
                  _startPhoneOtpTimer();
                  _showToast('New SMS sent to +91 ${_phoneController.text}');
                },
                child: const Text(
                  'Resend SMS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF133838),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 28),

        // Verify Phone Button
        CustomFormButton(
          innerText: 'Verify Phone Number',
          onPressed: _submitStep3,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 16),

        // Back to step 2
        TextButton(
          onPressed: () => setState(() => _currentStep = 1),
          child: const Text(
            '← Back to Email Verification',
            style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // ================= STEP 4: AADHAAR VERIFICATION =================
  Widget _buildStep4AadhaarKyc() {
    return Column(
      children: [
        const SizedBox(height: 12),
        // Official Security Badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF133838),
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Government of India (UIDAI) Verification',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF133838),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Aadhaar verification confirms your identity as a certified campus & community safety responder. Data is encrypted.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        if (!_isAadhaarOtpSent) ...[
          // Sub-step 4A: Enter Aadhaar Number
          RoundedInputField(
            controller: _aadhaarNumberController,
            labelText: 'Aadhaar Number',
            hintText: 'XXXX XXXX XXXX (12 digits)',
            keyboardType: TextInputType.number,
            maxLength: 14,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _AadhaarNumberFormatter(),
            ],
            validator: (value) {
              final raw = (value ?? '').replaceAll(' ', '');
              if (raw.length != 12) {
                return 'Please enter a 12-digit Aadhaar number';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),

          // Demo Aadhaar Chip
          GestureDetector(
            onTap: () {
              setState(() {
                _aadhaarNumberController.text = _kDemoAadhaarNumber;
                _errorMessage = null;
              });
              _showToast('Demo Aadhaar auto-filled: $_kDemoAadhaarNumber');
            },
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
                  Icon(Icons.credit_card_outlined, size: 14, color: Color(0xFF64748B)),
                  SizedBox(width: 6),
                  Text(
                    'Demo Aadhaar: $_kDemoAadhaarNumber • Tap to fill',
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
          const SizedBox(height: 28),

          // Send OTP Button
          CustomFormButton(
            innerText: 'Send Aadhaar OTP',
            onPressed: _sendAadhaarOtp,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: () => setState(() => _currentStep = 2),
            child: const Text(
              '← Back to Phone Verification',
              style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            ),
          ),
        ] else ...[
          // Sub-step 4B: Enter Aadhaar OTP
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.fingerprint_rounded, color: Color(0xFF133838), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Aadhaar: •••• •••• ${_aadhaarNumberController.text.trim().split(' ').last}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF133838),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isAadhaarOtpSent = false),
                    child: const Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF133838),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Enter the 6-digit OTP sent by UIDAI to your registered mobile number:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
          ),
          const SizedBox(height: 20),

          // 6-digit OTP Box Input
          OtpBoxInput(
            controller: _aadhaarOtpController,
            onChanged: (code) {
              if (_errorMessage != null) setState(() => _errorMessage = null);
            },
            onCompleted: (_) => _completeRegistration(),
          ),
          const SizedBox(height: 18),

          // Demo Aadhaar OTP Chip
          GestureDetector(
            onTap: () {
              setState(() {
                _aadhaarOtpController.text = _kDemoAadhaarOtp;
                _errorMessage = null;
              });
              _showToast('Demo Aadhaar OTP auto-filled: $_kDemoAadhaarOtp');
            },
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
                    'Demo OTP: $_kDemoAadhaarOtp • Tap to fill',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Resend Timer Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Didn't receive UIDAI code? ",
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
              if (_aadhaarOtpTimerSeconds > 0)
                Text(
                  'Resend in 00:${_aadhaarOtpTimerSeconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF133838),
                  ),
                )
              else
                GestureDetector(
                  onTap: () {
                    _startAadhaarOtpTimer();
                    _showToast('New UIDAI OTP requested');
                  },
                  child: const Text(
                    'Resend OTP',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF133838),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),

          // Complete Registration Button
          CustomFormButton(
            innerText: 'Verify & Complete Registration',
            onPressed: _completeRegistration,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: () => setState(() => _isAadhaarOtpSent = false),
            child: const Text(
              '← Back to Aadhaar Number',
              style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }
}

/// Custom formatter for Aadhaar: formats raw 12 digits into 'XXXX XXXX XXXX'
class _AadhaarNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
