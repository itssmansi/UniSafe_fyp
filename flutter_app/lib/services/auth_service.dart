import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class AuthService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // ============================================================
  // AUTH STATE
  // ============================================================

  User? get currentUser => _supabase.auth.currentUser;

  Session? get currentSession => _supabase.auth.currentSession;

  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  bool get isLoggedIn =>
      _supabase.auth.currentSession != null;

  // ============================================================
  // MOCK CITIZEN IDENTITY VERIFICATION
  // ============================================================

  Future<Map<String, dynamic>> verifyMockCitizen({
    required String name,
    required String aadhaar,
    required String address,
    required String gender,
    required String phone,
    required String email,
  }) async {
    final response = await _supabase.rpc(
      'verify_mock_citizen',
      params: {
        'p_aadhaar': aadhaar.trim(),
        'p_name': name.trim(),
        'p_address': address.trim(),
        'p_gender': gender.trim(),
        'p_phone': phone.trim(),
        'p_email': email.trim(),
      },
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception(
      'Invalid identity verification response.',
    );
  }

  // ============================================================
  // SIMULATED AADHAAR OTP
  // ============================================================

  Future<Map<String, dynamic>> sendAadhaarOtp({
    required String aadhaar,
  }) async {
    final response = await _supabase.functions.invoke(
      'send-aadhar-otp',
      body: {
        'aadhaar': aadhaar.trim(),
      },
    );

    if (response.data is Map) {
      return Map<String, dynamic>.from(
        response.data,
      );
    }

    throw Exception(
      'Invalid Aadhaar OTP response.',
    );
  }

  // ============================================================
  // VERIFY SIMULATED AADHAAR OTP
  // ============================================================

  Future<Map<String, dynamic>> verifyAadhaarOtp({
    required String aadhaar,
    required String otp,
  }) async {
    final response = await _supabase.functions.invoke(
      'verify-aadhaar-otp',
      body: {
        'aadhaar': aadhaar.trim(),
        'otp': otp.trim(),
      },
    );

    if (response.data is Map) {
      return Map<String, dynamic>.from(
        response.data,
      );
    }

    throw Exception(
      'Invalid Aadhaar OTP verification response.',
    );
  }

  // ============================================================
  // REAL SUPABASE EMAIL OTP
  // ============================================================

  Future<void> sendEmailVerificationOtp({
    required String email,
  }) async {
    await _supabase.auth.signInWithOtp(
      email: email.trim().toLowerCase(),
      shouldCreateUser: true,
    );
  }

  // ============================================================
  // VERIFY REAL SUPABASE EMAIL OTP
  // ============================================================

  Future<bool> verifyEmailVerificationOtp({
    required String email,
    required String otp,
  }) async {
    final response = await _supabase.auth.verifyOTP(
      email: email.trim().toLowerCase(),
      token: otp.trim(),
      type: OtpType.email,
    );

    return response.user != null;
  }

  // ============================================================
  // PINGRAM PHONE OTP
  // ============================================================

  Future<Map<String, dynamic>> sendOtp({
    required String phone,
  }) async {
    final response = await _supabase.functions.invoke(
      'send-otp',
      body: {
        'phone': phone.trim(),
      },
    );

    if (response.data is Map) {
      return Map<String, dynamic>.from(
        response.data,
      );
    }

    throw Exception(
      'Invalid phone OTP response from server.',
    );
  }

  // ============================================================
  // VERIFY PINGRAM PHONE OTP
  // ============================================================

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
    required String name,
    required String aadhaar,
    required String address,
    required String gender,
    required String email,
    required String username,
    required String password,
  }) async {
    final response = await _supabase.functions.invoke(
      'verify-otp',
      body: {
        'phone': phone.trim(),
        'otp': otp.trim(),
        'name': name.trim(),
        'aadhaar': aadhaar.trim(),
        'address': address.trim(),
        'gender': gender.trim(),
        'email': email.trim(),
        'username': username.trim(),
        'password': password,
      },
    );

    if (response.data is Map) {
      return Map<String, dynamic>.from(
        response.data,
      );
    }

    throw Exception(
      'Invalid phone OTP verification response.',
    );
  }

  // ============================================================
  // LOGIN WITH EMAIL
  // ============================================================

  Future<AuthResponse> loginWithEmail({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ============================================================
  // LOGIN WITH PHONE
  // ============================================================

  Future<AuthResponse> loginWithPhone({
    required String phone,
    required String password,
  }) async {
    String formattedPhone = phone.trim();

    if (RegExp(r'^\d{10}$').hasMatch(formattedPhone)) {
      formattedPhone = '+91$formattedPhone';
    }

    return await _supabase.auth.signInWithPassword(
      phone: formattedPhone,
      password: password,
    );
  }

  // ============================================================
  // AUTHORITY LOGIN
  // ============================================================

  Future<Map<String, dynamic>> loginAuthority({
    required String name,
    required String department,
    required String designation,
    required String password,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'authority-login',
        body: {
          'name': name.trim(),
          'department': department.trim().toUpperCase(),
          'designation': designation.trim(),
          'password': password,
        },
      );

      if (response.data is! Map) {
        throw Exception(
          'Invalid authority login response.',
        );
      }

      final result =
          Map<String, dynamic>.from(response.data);

      if (result['success'] == true) {
        final refreshToken =
            result['refresh_token']?.toString();

        if (refreshToken == null ||
            refreshToken.isEmpty) {
          throw Exception(
            'Authority login succeeded but no refresh token was returned.',
          );
        }

        await _supabase.auth.setSession(
          refreshToken,
        );
      }

      return result;
    } catch (e) {
      throw Exception(
        'Authority login failed: $e',
      );
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }
}