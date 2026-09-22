import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'otp_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // ------------------------------------------------------------
  // Controllers
  // ------------------------------------------------------------

  final nameController = TextEditingController();
  final aadhaarController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  // ------------------------------------------------------------
  // Services / state
  // ------------------------------------------------------------

  final AuthService _authService = AuthService();

  String? selectedGender;

  bool isLoading = false;
  bool obscurePassword = true;

  // ------------------------------------------------------------
  // Dispose
  // ------------------------------------------------------------

  @override
  void dispose() {
    nameController.dispose();
    aadhaarController.dispose();
    addressController.dispose();
    phoneController.dispose();
    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  // ------------------------------------------------------------
  // Verify identity + send OTP
  // ------------------------------------------------------------

  Future<void> _verifyIdentity() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your gender.'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // --------------------------------------------------------
      // STEP 1: Mock identity verification
      // --------------------------------------------------------

      final identityResult =
          await _authService.verifyMockCitizen(
        name: nameController.text.trim(),
        aadhaar: aadhaarController.text.trim(),
        address: addressController.text.trim(),
        gender: selectedGender!,
        phone: phoneController.text.trim(),
        email: emailController.text.trim(),
      );

      if (!mounted) return;

      final identityVerified =
          identityResult['verified'] == true;

      if (!identityVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              identityResult['message']?.toString() ??
                  'Identity verification failed.',
            ),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      // --------------------------------------------------------
      // STEP 2: Send OTP through Pingram
      // --------------------------------------------------------

      final otpResult = await _authService.sendOtp(
        phone: phoneController.text.trim(),
      );

      if (!mounted) return;

      final otpSent = otpResult['success'] == true;

      if (!otpSent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              otpResult['message']?.toString() ??
                  'Could not send OTP.',
            ),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      // --------------------------------------------------------
      // STEP 3: Move to OTP screen
      // --------------------------------------------------------

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpScreen(
            phone: phoneController.text.trim(),
            name: nameController.text.trim(),
            aadhaar: aadhaarController.text.trim(),
            address: addressController.text.trim(),
            gender: selectedGender!,
            email: emailController.text.trim(),
            username: usernameController.text.trim(),
            password: passwordController.text,
          ),
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

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                const Text(
                  'Join the UniSafe Family',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Enter your details to verify your identity and create your account.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 28),

                // ------------------------------------------------
                // Name
                // ------------------------------------------------

                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ------------------------------------------------
                // Aadhaar
                // ------------------------------------------------

                TextFormField(
                  controller: aadhaarController,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  decoration: const InputDecoration(
                    labelText: 'Aadhaar Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                    counterText: '',
                  ),
                  validator: (value) {
                    final aadhaar = value?.trim() ?? '';

                    if (aadhaar.isEmpty) {
                      return 'Please enter Aadhaar number';
                    }

                    if (!RegExp(r'^\d{12}$').hasMatch(aadhaar)) {
                      return 'Aadhaar must contain 12 digits';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ------------------------------------------------
                // Address
                // ------------------------------------------------

                TextFormField(
                  controller: addressController,
                  maxLines: 3,
                  textCapitalization:
                      TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your address';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ------------------------------------------------
                // Gender
                // ------------------------------------------------

                DropdownButtonFormField<String>(
                  value: selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.people),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Male',
                      child: Text('Male'),
                    ),
                    DropdownMenuItem(
                      value: 'Female',
                      child: Text('Female'),
                    ),
                    DropdownMenuItem(
                      value: 'Other',
                      child: Text('Other'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedGender = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your gender';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ------------------------------------------------
                // Phone
                // ------------------------------------------------

                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                    counterText: '',
                  ),
                  validator: (value) {
                    final phone = value?.trim() ?? '';

                    if (phone.isEmpty) {
                      return 'Please enter your phone number';
                    }

                    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
                      return 'Phone number must contain 10 digits';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ------------------------------------------------
                // Email
                // ------------------------------------------------

                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';

                    if (email.isEmpty) {
                      return 'Please enter your email';
                    }

                    final emailRegex = RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    );

                    if (!emailRegex.hasMatch(email)) {
                      return 'Please enter a valid email';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ------------------------------------------------
                // Username
                // ------------------------------------------------

                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_circle),
                  ),
                  validator: (value) {
                    final username = value?.trim() ?? '';

                    if (username.isEmpty) {
                      return 'Please enter a username';
                    }

                    if (username.length < 3) {
                      return 'Username must be at least 3 characters';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ------------------------------------------------
                // Password
                // ------------------------------------------------

                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Create Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
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
                    final password = value ?? '';

                    if (password.isEmpty) {
                      return 'Please enter a password';
                    }

                    if (password.length < 6) {
                      return 'Password must be at least 6 characters';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 28),

                // ------------------------------------------------
                // Verify Identity Button
                // ------------------------------------------------

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        isLoading ? null : _verifyIdentity,
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
                            'Verify Identity',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Your identity will be verified before an OTP is sent to your registered phone number.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
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