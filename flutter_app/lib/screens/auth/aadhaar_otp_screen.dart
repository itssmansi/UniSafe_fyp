import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'otp_screen.dart';

class AadhaarOtpScreen extends StatefulWidget {
  final String name;
  final String aadhaar;
  final String address;
  final String gender;
  final String phone;
  final String email;
  final String username;
  final String password;
  final String demoOtp;

  const AadhaarOtpScreen({
    super.key,
    required this.name,
    required this.aadhaar,
    required this.address,
    required this.gender,
    required this.phone,
    required this.email,
    required this.username,
    required this.password,
    required this.demoOtp,
  });

  @override
  State<AadhaarOtpScreen> createState() => _AadhaarOtpScreenState();
}

class _AadhaarOtpScreenState extends State<AadhaarOtpScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController _otpController =
      TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // VERIFY AADHAAR OTP
  // ------------------------------------------------------------

  Future<void> _verifyAadhaarOtp() async {
    if (_isLoading) return;

    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      _showMessage(
        'Please enter the 6-digit Aadhaar OTP.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // --------------------------------------------------------
      // STEP 1: VERIFY AADHAAR OTP
      // --------------------------------------------------------

      final result = await _authService.verifyAadhaarOtp(
        aadhaar: widget.aadhaar,
        otp: otp,
      );

      final aadhaarVerified =
          result['success'] == true ||
          result['verified'] == true;

      if (!aadhaarVerified) {
        throw Exception(
          result['message']?.toString() ??
              'Aadhaar OTP verification failed.',
        );
      }

      // --------------------------------------------------------
      // STEP 2: SEND PHONE OTP THROUGH PINGRAM
      // --------------------------------------------------------

      final phoneOtpResult = await _authService.sendOtp(
        phone: widget.phone,
      );

      if (phoneOtpResult['success'] == false) {
        throw Exception(
          phoneOtpResult['message']?.toString() ??
              'Failed to send phone OTP.',
        );
      }

      if (!mounted) return;

      // --------------------------------------------------------
      // STEP 3: OPEN PHONE OTP SCREEN
      // --------------------------------------------------------

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            phone: widget.phone,
            name: widget.name,
            aadhaar: widget.aadhaar,
            address: widget.address,
            gender: widget.gender,
            email: widget.email,
            username: widget.username,
            password: widget.password,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // SHOW MESSAGE
  // ------------------------------------------------------------

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 26,
            vertical: 28,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.verified_user,
                size: 70,
                color: Color(0xFF252329),
              ),

              const SizedBox(height: 20),

              const Text(
                'Verify Aadhaar OTP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF252329),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'An OTP has been generated for Aadhaar '
                '${widget.aadhaar}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 35),

              // ------------------------------------------------
              // DEMO OTP
              // ------------------------------------------------

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 28,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.black54,
                  ),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    const Text(
                      'OTP',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      widget.demoOtp,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight:
                            FontWeight.bold,
                        letterSpacing: 8,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'For FYP demonstration only',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 38),

              const Text(
                'Enter the 6-digit OTP to continue.',
                style: TextStyle(
                  fontSize: 17,
                  color: Color(0xFF353139),
                ),
              ),

              const SizedBox(height: 10),

              // ------------------------------------------------
              // OTP FIELD
              // ------------------------------------------------

              TextField(
                controller: _otpController,
                keyboardType:
                    TextInputType.number,
                maxLength: 6,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Aadhaar OTP',
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  counterText: '',
                ),
              ),

              const SizedBox(height: 28),

              // ------------------------------------------------
              // VERIFY BUTTON
              // ------------------------------------------------

              SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : _verifyAadhaarOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFF9F0FC),
                    foregroundColor:
                        const Color(0xFF6C4E8E),
                    elevation: 2,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Verify Aadhaar OTP',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'After Aadhaar verification, '
                'a phone OTP will be sent to '
                '${widget.phone}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}