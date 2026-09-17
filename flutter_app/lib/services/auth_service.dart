import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class AuthService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Current logged-in user
  User? get currentUser => _supabase.auth.currentUser;

  // Current session
  Session? get currentSession => _supabase.auth.currentSession;

  // Listen for authentication changes
  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  // Send OTP to phone
  Future<void> sendOtp(String phone) async {
    await _supabase.auth.signInWithOtp(
      phone: phone,
    );
  }

  // Verify OTP
  Future<AuthResponse> verifyOtp({
    required String phone,
    required String token,
  }) async {
    return await _supabase.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
  }

  // Email/password signup
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  // Email/password login
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Logout
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}