import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../config/supabase_config.dart';

class DigiLockerService {
  static const String _apiKey = 'key_live_2f653498e8674e74ba759412432638cb';
  static const String _apiSecret = 'secret_live_de1fcbec97174666a861dd6bf511be82';
  static const String _baseUrl = 'https://api.sandbox.co.in';

  String? _accessToken;
  DateTime? _tokenExpiry;

  /// Initialize DigiLocker session
  Future<Map<String, dynamic>> initSession({
    String redirectUrl = 'http://localhost:8080',
  }) async {
    // 1. Primary: Use Supabase Edge Function to avoid browser CORS issues
    try {
      final res = await SupabaseConfig.client.functions.invoke(
        'digilocker-kyc',
        body: {
          'action': 'init_session',
          'redirect_url': redirectUrl,
        },
      );
      if (res.data is Map && res.data['success'] == true) {
        return Map<String, dynamic>.from(res.data);
      }
    } catch (e) {
      debugPrint('DigiLocker Edge Function init fallback: $e');
    }

    // 2. Fallback: Direct Sandbox HTTP call (for mobile platforms)
    final token = await getAccessToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/kyc/digilocker/sessions/init'),
      headers: {
        'Authorization': token,
        'x-api-key': _apiKey,
        'x-api-version': '1.0',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        '@entity': 'in.co.sandbox.kyc.digilocker.session.request',
        'flow': 'signin',
        'redirect_url': redirectUrl,
        'doc_types': ['aadhaar'],
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final data = json['data'] as Map<String, dynamic>?;
      if (data != null && data['authorization_url'] != null) {
        return {
          'success': true,
          'authorization_url': data['authorization_url']?.toString(),
          'session_id': data['session_id']?.toString(),
        };
      }
    }

    try {
      final err = jsonDecode(response.body);
      return {
        'success': false,
        'message': err['message']?.toString() ??
            'Failed to initialize DigiLocker session',
      };
    } catch (_) {
      return {
        'success': false,
        'message':
            'Failed to initialize DigiLocker session (HTTP ${response.statusCode})',
      };
    }
  }

  /// Check session status (e.g. 'created', 'completed', 'failed', 'denied')
  Future<Map<String, dynamic>> checkStatus(String sessionId) async {
    // 1. Primary: Use Supabase Edge Function
    try {
      final res = await SupabaseConfig.client.functions.invoke(
        'digilocker-kyc',
        body: {
          'action': 'check_status',
          'session_id': sessionId,
        },
      );
      if (res.data is Map && res.data['success'] == true) {
        return Map<String, dynamic>.from(res.data);
      }
    } catch (e) {
      debugPrint('DigiLocker Edge Function status fallback: $e');
    }

    // 2. Fallback: Direct Sandbox HTTP call
    final token = await getAccessToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/kyc/digilocker/sessions/$sessionId/status'),
      headers: {
        'Authorization': token,
        'x-api-key': _apiKey,
        'x-api-version': '1.0',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final data = json['data'] as Map<String, dynamic>?;
      final status = data?['status']?.toString().toLowerCase() ?? 'unknown';
      return {
        'success': true,
        'status': status,
        'data': data,
      };
    }

    return {
      'success': false,
      'status': 'error',
      'message': 'Failed to check status (HTTP ${response.statusCode})',
    };
  }

  /// Fetch verified User Profile / Aadhaar details
  Future<Map<String, dynamic>> fetchUserProfile(String sessionId) async {
    // 1. Primary: Use Supabase Edge Function
    try {
      final res = await SupabaseConfig.client.functions.invoke(
        'digilocker-kyc',
        body: {
          'action': 'get_profile',
          'session_id': sessionId,
        },
      );
      if (res.data is Map && res.data['success'] == true) {
        return Map<String, dynamic>.from(res.data);
      }
    } catch (e) {
      debugPrint('DigiLocker Edge Function profile fallback: $e');
    }

    // 2. Fallback: Direct Sandbox HTTP call
    final token = await getAccessToken();
    final profileRes = await http.get(
      Uri.parse('$_baseUrl/kyc/digilocker/sessions/$sessionId/user/profile'),
      headers: {
        'Authorization': token,
        'x-api-key': _apiKey,
        'x-api-version': '1.0',
      },
    );

    if (profileRes.statusCode == 200) {
      final json = jsonDecode(profileRes.body);
      if (json['data'] is Map<String, dynamic>) {
        return {
          'success': true,
          'profile': Map<String, dynamic>.from(json['data']),
        };
      }
    }

    return {
      'success': false,
      'message': 'Could not fetch Aadhaar document from DigiLocker',
    };
  }

  /// Authenticate and retrieve JWT access token
  Future<String> getAccessToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/authenticate'),
      headers: {
        'x-api-key': _apiKey,
        'x-api-secret': _apiSecret,
        'x-api-version': '1.0',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final token = json['data']?['access_token']?.toString() ??
          json['access_token']?.toString();
      if (token != null) {
        _accessToken = token;
        _tokenExpiry = DateTime.now().add(const Duration(hours: 23));
        return token;
      }
    }

    throw Exception(
        'Failed to authenticate with Sandbox DigiLocker (HTTP ${response.statusCode})');
  }
}
