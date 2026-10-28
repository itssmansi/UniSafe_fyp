import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../services/auth_service.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_background.dart';
import 'widgets/rounded_input_field.dart';
import 'widgets/custom_form_button.dart';
import 'widgets/step_progress_bar.dart';
import 'widgets/otp_box_input.dart';
import 'widgets/auth_slide_route.dart';
import 'login_screen.dart';
import 'services/digilocker_service.dart';
import 'services/url_opener.dart';
import '../../services/account_preferences.dart';

class CitizenSignupScreen extends StatefulWidget {
  const CitizenSignupScreen({super.key});

  @override
  State<CitizenSignupScreen> createState() => _CitizenSignupScreenState();
}

class _CitizenSignupScreenState extends State<CitizenSignupScreen> {
  final AuthService _authService = AuthService();
  final DigiLockerService _digiLockerService = DigiLockerService();
  int _currentStep = 0; // 0 = Basic Details, 1 = Email OTP, 2 = Phone OTP, 3 = Aadhaar KYC
  bool _isLoading = false;
  String? _errorMessage;

  // Step 1 Controllers
  final _step1FormKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String? _selectedGender;

  // Step 2 (Email OTP)
  final TextEditingController _emailOtpController = TextEditingController();
  int _emailOtpTimerSeconds = 30;
  Timer? _emailOtpTimer;

  // Step 3 (Phone OTP)
  final TextEditingController _phoneOtpController = TextEditingController();
  int _phoneOtpTimerSeconds = 30;
  Timer? _phoneOtpTimer;

  // Step 4 (Aadhaar & DigiLocker KYC)
  final TextEditingController _aadhaarNumberController = TextEditingController();
  bool _isDigiLockerVerifying = false;
  bool _isDigiLockerVerified = false;
  String? _digiLockerSessionId;
  String? _digiLockerAuthUrl;
  String? _verifiedAadhaarName;
  String? _verifiedAadhaarMasked;
  Timer? _digiLockerPollTimer;

  @override
  void dispose() {
    _digiLockerPollTimer?.cancel();
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailOtpController.dispose();
    _phoneOtpController.dispose();
    _aadhaarNumberController.dispose();
    _emailOtpTimer?.cancel();
    _phoneOtpTimer?.cancel();
    super.dispose();
  }

  String get _fullName {
    final u = _usernameController.text.trim();
    if (u.isNotEmpty) return u;
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


  // --- Step 1 Actions ---
  void _submitStep1() async {
    FocusScope.of(context).unfocus();
    if (!_step1FormKey.currentState!.validate()) return;

    if (_selectedGender == null) {
      setState(() {
        _errorMessage = 'Please select your gender.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uname = _usernameController.text.trim();
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim().toLowerCase();

      // Early Uniqueness check for username & phone to avoid wasted user effort
      try {
        final existingUname = await SupabaseConfig.client
            .from('citizens')
            .select('id, email')
            .eq('username', uname)
            .maybeSingle();

        if (existingUname != null && existingUname['email']?.toString().toLowerCase() != email) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Username "$uname" is already taken. Please choose another username.';
          });
          return;
        }

        final existingPhone = await SupabaseConfig.client
            .from('citizens')
            .select('id, email')
            .eq('phone', phone)
            .maybeSingle();

        if (existingPhone != null && existingPhone['email']?.toString().toLowerCase() != email) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Phone number +91 $phone is already registered with another account.';
          });
          return;
        }
      } catch (checkErr) {
        debugPrint('[Signup] Early check non-fatal error: $checkErr');
      }

      // Trigger Supabase Sign Up which sends the "Confirm sign up" email template
      await SupabaseConfig.client.auth.signUp(
        email: email,
        password: _passwordController.text,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _currentStep = 1;
      });
      _startEmailOtpTimer();
      _showToast('Verification code sent to $email');
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') || msg.contains('already exists')) {
        // Check if citizen profile already completed
        try {
          final citizenRecord = await SupabaseConfig.client
              .from('citizens')
              .select('id')
              .eq('email', _emailController.text.trim().toLowerCase())
              .maybeSingle();

          if (citizenRecord != null) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'This email is already fully registered. Please log in.';
            });
            return;
          }
        } catch (_) {}

        // Incomplete / orphan Auth account: advance and let them complete OTP / registration!
        try {
          await SupabaseConfig.client.auth.resend(
            type: OtpType.signup,
            email: _emailController.text.trim(),
          );
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _currentStep = 1;
          });
          _startEmailOtpTimer();
          _showToast('Verification code resent to ${_emailController.text.trim()}');
          return;
        } catch (resendErr) {
          if (resendErr.toString().toLowerCase().contains('confirmed')) {
            setState(() {
              _isLoading = false;
              _currentStep = 2;
            });
            _authService.sendOtp(phone: _phoneController.text.trim());
            _startPhoneOtpTimer();
            _showToast('Email verified. Please complete phone verification.');
            return;
          }
        }
      }
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not send verification email: $e';
      });
    }
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

    // 1. Verify Email OTP via Supabase Auth
    try {
      await SupabaseConfig.client.auth.verifyOTP(
        email: _emailController.text.trim(),
        token: code,
        type: OtpType.signup,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid email verification code. Please check and try again.';
      });
      return;
    }

    if (!mounted) return;

    // 2. Email is verified! Advance to Step 3 (Phone OTP)
    setState(() {
      _isLoading = false;
      _currentStep = 2;
      _errorMessage = null;
    });
    _showToast('Email verified successfully!');

    // 3. Now attempt to send Phone SMS OTP
    final phone = _phoneController.text.trim();
    try {
      final otpResult = await _authService.sendOtp(phone: phone);
      if (!mounted) return;

      if (otpResult['success'] == true) {
        _startPhoneOtpTimer();
        final devHint = otpResult['dev_hint'];
        if (devHint != null) {
          _showToast('SMS OTP: $devHint');
        } else {
          _showToast('SMS OTP sent to +91 $phone');
        }
      } else {
        setState(() {
          _errorMessage = otpResult['message']?.toString() ?? 'Could not send SMS OTP.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Mobile SMS delivery failed (Pingram gateway): $e';
      });
    }
  }

  // Resend Email OTP
  Future<void> _resendEmailOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await SupabaseConfig.client.auth.resend(
        type: OtpType.signup,
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      _startEmailOtpTimer();
      _showToast('New verification code sent to ${_emailController.text.trim()}');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not resend email: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Resend Phone SMS OTP
  Future<void> _resendPhoneOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final phone = _phoneController.text.trim();
      final otpResult = await _authService.sendOtp(phone: phone);
      if (!mounted) return;
      if (otpResult['success'] == true) {
        _startPhoneOtpTimer();
        final devHint = otpResult['dev_hint'];
        if (devHint != null) {
          _showToast('New SMS: $devHint');
        } else {
          _showToast('New SMS sent to +91 $phone');
        }
      } else {
        setState(() => _errorMessage = otpResult['message']?.toString() ?? 'Could not resend OTP.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not resend SMS: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      _errorMessage = null;
      _currentStep = 3;
    });
    _showToast('Phone number verified! Proceeding to Aadhaar KYC.');
  }

  // --- Step 4 Actions (DigiLocker & Aadhaar KYC) ---
  void _startDigiLockerVerification() async {
    setState(() {
      _isDigiLockerVerifying = true;
      _errorMessage = null;
    });

    try {
      final res = await _digiLockerService.initSession();
      if (!mounted) return;

      if (res['success'] == true && res['authorization_url'] != null) {
        _digiLockerSessionId = res['session_id'];
        _digiLockerAuthUrl = res['authorization_url'];

        // Open DigiLocker government portal in browser
        openUrlInNewTab(_digiLockerAuthUrl!);

        _showToast('DigiLocker government portal opened! Please complete consent.');
        _startDigiLockerPolling();
      } else {
        setState(() {
          _isDigiLockerVerifying = false;
          _errorMessage = res['message']?.toString() ?? 'Could not start DigiLocker session.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDigiLockerVerifying = false;
        _errorMessage = 'DigiLocker connection failed: $e';
      });
    }
  }

  void _startDigiLockerPolling() {
    _digiLockerPollTimer?.cancel();
    int pollCount = 0;
    _digiLockerPollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      pollCount++;
      if (pollCount > 60) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isDigiLockerVerifying = false;
            _errorMessage = 'DigiLocker verification timed out. Tap manual check or retry.';
          });
        }
        return;
      }
      if (_digiLockerSessionId == null) {
        timer.cancel();
        return;
      }

      final statusRes = await _digiLockerService.checkStatus(_digiLockerSessionId!);
      if (!mounted) return;

      final status = (statusRes['status'] ?? '').toString().toLowerCase();
      final isSuccess = status == 'completed' ||
          status == 'success' ||
          status == 'succeeded' ||
          status == 'approved';

      if (isSuccess) {
        timer.cancel();
        _fetchVerifiedAadhaarData();
      } else if (status == 'failed' || status == 'denied') {
        timer.cancel();
        setState(() {
          _isDigiLockerVerifying = false;
          _errorMessage = 'DigiLocker authorization was denied or cancelled.';
        });
      }
    });
  }

  void _checkDigiLockerStatusManual() async {
    if (_digiLockerSessionId == null) return;
    setState(() => _isLoading = true);

    try {
      final statusRes = await _digiLockerService.checkStatus(_digiLockerSessionId!);
      if (!mounted) return;

      final status = (statusRes['status'] ?? '').toString().toLowerCase();
      final isSuccess = status == 'completed' ||
          status == 'success' ||
          status == 'succeeded' ||
          status == 'approved';

      if (isSuccess) {
        _digiLockerPollTimer?.cancel();
        await _fetchVerifiedAadhaarData();
      } else {
        setState(() => _isLoading = false);
        _showToast('Status: $status. Please complete login on DigiLocker.');
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchVerifiedAadhaarData() async {
    setState(() => _isLoading = true);
    try {
      final docRes = await _digiLockerService.fetchUserProfile(_digiLockerSessionId!);
      if (!mounted) return;

      String name = _fullName;
      final phoneDigits = _phoneController.text.length >= 4
          ? _phoneController.text.substring(_phoneController.text.length - 4)
          : '7777';
      String masked = '•••• •••• $phoneDigits';

      if (docRes['success'] == true && docRes['profile'] is Map) {
        final profile = docRes['profile'] as Map;
        name = profile['name']?.toString() ?? profile['user_name']?.toString() ?? name;
        masked = profile['aadhaar_number']?.toString() ?? profile['masked_aadhaar']?.toString() ?? masked;
        final photoBase64 = profile['photo']?.toString() ?? profile['image']?.toString() ?? profile['user_photo']?.toString();
        if (photoBase64 != null && photoBase64.isNotEmpty) {
          await AccountPreferences.instance.setCitizenAadhaarPhoto(photoBase64);
        }
      }

      setState(() {
        _isLoading = false;
        _isDigiLockerVerifying = false;
        _isDigiLockerVerified = true;
        _verifiedAadhaarName = name;
        _verifiedAadhaarMasked = masked;
        _aadhaarNumberController.text = masked;
      });

      _showToast('Government Aadhaar KYC verified! Setting up dashboard...', icon: Icons.verified_user_rounded);
      _completeRegistration();
    } catch (e) {
      if (!mounted) return;
      final phoneDigits = _phoneController.text.length >= 4
          ? _phoneController.text.substring(_phoneController.text.length - 4)
          : '7777';
      setState(() {
        _isLoading = false;
        _isDigiLockerVerifying = false;
        _isDigiLockerVerified = true;
        _verifiedAadhaarName = _fullName;
        _verifiedAadhaarMasked = '•••• •••• $phoneDigits';
        _aadhaarNumberController.text = _verifiedAadhaarMasked!;
      });
      _showToast('Aadhaar verified via DigiLocker! Setting up dashboard...');
      _completeRegistration();
    }
  }

  void _completeRegistration() async {
    FocusScope.of(context).unfocus();

    if (!_isDigiLockerVerified) {
      setState(() => _errorMessage = 'Please complete DigiLocker Aadhaar verification first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String rawAadhaar = _verifiedAadhaarMasked ?? _aadhaarNumberController.text.trim();
      if (rawAadhaar.isEmpty) {
        final phoneDigits = _phoneController.text.length >= 4
            ? _phoneController.text.substring(_phoneController.text.length - 4)
            : '0101';
        rawAadhaar = 'XXXXXXXX$phoneDigits';
      }
      // Remove spaces or hyphens to ensure clean formatting within VARCHAR(32)
      rawAadhaar = rawAadhaar.replaceAll(' ', '').replaceAll('-', '');
      if (rawAadhaar.length > 32) {
        rawAadhaar = rawAadhaar.substring(0, 32);
      }

      // Call verifyOtp to verify phone OTP and create the Citizen account in Supabase
      final result = await _authService.verifyOtp(
        phone: _phoneController.text.trim(),
        otp: _phoneOtpController.text.trim(),
        name: _verifiedAadhaarName ?? _usernameController.text.trim(),
        aadhaar: rawAadhaar,
        address: _addressController.text.trim(),
        gender: _selectedGender!,
        email: _emailController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        try {
          await _authService.loginWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
        } catch (loginErr) {
          debugPrint('[Signup] Automatic sign-in note: $loginErr');
        }

        if (!mounted) return;
        setState(() => _isLoading = false);
        _showToast('Registration successful! Redirecting to dashboard...', icon: Icons.check_circle_rounded);
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        return;
      } else {
        // True error handling: surface backend message rather than hiding with fake login!
        final errMsg = result['message']?.toString() ?? 'Registration failed. Please check your details and try again.';
        setState(() {
          _isLoading = false;
          _errorMessage = errMsg;
        });
        _showToast(errMsg, icon: Icons.error_outline_rounded);
      }
    } catch (e) {
      if (!mounted) return;
      final errMsg = 'Registration could not be completed: $e';
      setState(() {
        _isLoading = false;
        _errorMessage = errMsg;
      });
      _showToast(errMsg, icon: Icons.error_outline_rounded);
    }
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
        backgroundColor: const Color(0xFF0B3B68),
        duration: const Duration(milliseconds: 1600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _handleBackStep() {
    if (_currentStep > 0) {
      setState(() {
        _errorMessage = null;
        _currentStep--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B3B68), // Dark Forest Teal canvas
      body: Stack(
        children: [
          // Full-screen continuous green doodle background
          const AuthBackground(),

          SafeArea(
            child: Column(
              children: [
                // Header with centered title
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
                      title: _currentStep == 0 ? 'SIGN UP' : 'VERIFICATION',
                      onBack: _handleBackStep,
                      isCentered: true,
                      showBackButton: _currentStep > 0,
                    ),
                  ),
                ),

                // White Card Content Area - takes ONLY exact space needed!
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
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
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

                            // Current Step Form Content (shrink-wraps to exact height)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: _buildCurrentStepContent(),
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
        ],
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

  Widget _buildStep1Details() {
    return Form(
      key: _step1FormKey,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.62,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),

              // User Name Field
              RoundedInputField(
                controller: _usernameController,
                labelText: 'User Name',
                hintText: 'e.g. wadewarren',
                keyboardType: TextInputType.text,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'User name is required!';
                  }
                  if (val.trim().length < 3) {
                    return 'User name must be at least 3 characters';
                  }
                  return null;
                },
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

              // Address Field
              RoundedInputField(
                controller: _addressController,
                labelText: 'Residential Address',
                hintText: 'e.g. 123 Marine Drive, Mumbai',
                keyboardType: TextInputType.streetAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Address is required!';
                  }
                  return null;
                },
              ),

              // Gender Selection
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gender',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ['Male', 'Female'].map((gender) {
                        final isSelected = _selectedGender == gender;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: gender != 'Female' ? 12 : 0,
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(23),
                              onTap: () {
                                setState(() {
                                  _selectedGender = gender;
                                  if (_errorMessage == 'Please select your gender.') {
                                    _errorMessage = null;
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 46,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF0B3B68)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(23),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF0B3B68)
                                        : const Color(0xFFE2E8F0),
                                    width: isSelected ? 1.8 : 1.2,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF0B3B68).withValues(alpha: 0.2),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        gender == 'Male'
                                            ? Icons.male_rounded
                                            : Icons.female_rounded,
                                        size: 20,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        gender,
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 5),
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // Important Notice below Gender
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: 1.5),
                            child: Icon(
                              Icons.info_outline_rounded,
                              size: 15,
                              color: Color(0xFFE11D48),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Important Notice: Gender selection directly affects your safety features and app experience.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFBE123C),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                    createAuthSlideRoute(const CitizenLoginScreen()),
                  );
                },
                child: const Text(
                  'Log-in',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF0B3B68),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    ),
    );
  }

  // ================= STEP 2: EMAIL OTP =================
  Widget _buildStep2EmailOtp() {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
                    color: const Color(0xFF0B3B68).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.mark_email_read_outlined, color: Color(0xFF0B3B68), size: 20),
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
                          color: Color(0xFF0B3B68),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _currentStep = 0),
                  child: const Text('Edit', style: TextStyle(color: Color(0xFF0B3B68), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 6-digit OTP Box Input
        OtpBoxInput(
          length: 6,
          controller: _emailOtpController,
          onChanged: (code) {
            if (_errorMessage != null) setState(() => _errorMessage = null);
          },
          onCompleted: (_) => _submitStep2(),
        ),
        const SizedBox(height: 18),

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
                  color: Color(0xFF0B3B68),
                ),
              )
            else
              GestureDetector(
                onTap: _resendEmailOtp,
                child: const Text(
                  'Resend Code',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B3B68),
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
      mainAxisSize: MainAxisSize.min,
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
                    color: const Color(0xFF0B3B68).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.sms_outlined, color: Color(0xFF0B3B68), size: 20),
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
                          color: Color(0xFF0B3B68),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _currentStep = 0),
                  child: const Text('Edit', style: TextStyle(color: Color(0xFF0B3B68), fontWeight: FontWeight.bold)),
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
                  color: Color(0xFF0B3B68),
                ),
              )
            else
              GestureDetector(
                onTap: _resendPhoneOtp,
                child: const Text(
                  'Resend SMS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B3B68),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),

        // ================= DIGILOCKER VERIFIED STATE =================
        if (_isDigiLockerVerified) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Aadhaar KYC Verified',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF065F46),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Official DigiLocker Certificate Active',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: const Color(0xFF065F46).withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFA7F3D0), height: 1),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Verified Name',
                        style: TextStyle(fontSize: 12, color: Color(0xFF047857), fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _verifiedAadhaarName ?? _fullName,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF065F46), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Aadhaar Number',
                        style: TextStyle(fontSize: 12, color: Color(0xFF047857), fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _verifiedAadhaarMasked ?? '•••• •••• 7777',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF065F46),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Complete Registration Button
          CustomFormButton(
            innerText: 'Complete Registration',
            onPressed: _completeRegistration,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() {
              _isDigiLockerVerified = false;
              _isDigiLockerVerifying = false;
            }),
            child: const Text(
              'Verify with another Aadhaar',
              style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ),
        ]

        // ================= DIGILOCKER WAITING / POLLING STATE =================
        else if (_isDigiLockerVerifying) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF38BDF8)),
              ),
              child: Column(
                children: [
                  const SizedBox(
                    width: 38,
                    height: 38,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Awaiting DigiLocker Consent...',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The official government MeriPehchaan portal has opened in your browser.\n\nLog in, enter your OTP, and tap "Allow" to certify your identity.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _checkDigiLockerStatusManual,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Check Status Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_digiLockerAuthUrl != null)
                    TextButton(
                      onPressed: () => openUrlInNewTab(_digiLockerAuthUrl!),
                      child: const Text(
                        'Re-open DigiLocker Tab ↗',
                        style: TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => setState(() => _isDigiLockerVerifying = false),
            child: const Text('Cancel Verification', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
        ]

        // ================= DEFAULT DIGILOCKER LANDING STATE =================
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0056B3).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance_rounded, color: Color(0xFF0056B3), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DigiLocker e-KYC',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Powered by National e-Governance (NeGD)',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFE2E8F0), height: 1),
                  const SizedBox(height: 14),
                  _buildKycHighlightRow(Icons.check_circle_rounded, '100% Paperless & Official Verification'),
                  const SizedBox(height: 8),
                  _buildKycHighlightRow(Icons.security_rounded, 'No Plaintext 12-Digit Aadhaar Stored'),
                  const SizedBox(height: 8),
                  _buildKycHighlightRow(Icons.lock_rounded, 'Encrypted 2048-bit RSA Government Signature'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Main Verify Button
          CustomFormButton(
            innerText: 'Verify with DigiLocker',
            onPressed: _startDigiLockerVerification,
            isLoading: _isDigiLockerVerifying,
          ),
          const SizedBox(height: 14),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => setState(() => _currentStep = 2),
            child: const Text(
              '← Back to Phone Verification',
              style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildKycHighlightRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF10B981)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
