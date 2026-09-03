import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config.dart';

/// Server response for /otp/verify and /refresh (E2.3 contract).
class TokenBundle {
  const TokenBundle({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.expiresInSec,
    required this.newUser,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final int expiresInSec;
  final bool newUser;

  factory TokenBundle.fromJson(Map<String, dynamic> j) => TokenBundle(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
        userId: j['userId'] as String,
        expiresInSec: (j['expiresIn'] as num).toInt(),
        newUser: j['newUser'] as bool? ?? false,
      );
}

/// Auth failure carrying the server's error message (E2.3 sends
/// {"error": "..."} with 400/401).
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Talks to the E2.3 auth endpoints. Dev flavor uses the backend's
/// DevPhoneAuthProvider — any 10-digit number, fixed code 123456.
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  /// Step 1: request OTP. Returns the session handle for step 2.
  Future<String> requestOtp(String phone) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/auth/otp/request',
        data: {'phone': phone},
      );
      return res.data!['session'] as String;
    } on DioException catch (e) {
      throw AuthException(_serverMessage(e));
    }
  }

  /// Step 2: verify the code, returns tokens + user identity.
  Future<TokenBundle> verifyOtp(String session, String code) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/auth/otp/verify',
        data: {'session': session, 'code': code},
      );
      return TokenBundle.fromJson(res.data!);
    } on DioException catch (e) {
      throw AuthException(_serverMessage(e));
    }
  }

  /// Rotate the refresh token for a fresh access token.
  Future<TokenBundle> refresh(String refreshToken) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      return TokenBundle.fromJson(res.data!);
    } on DioException catch (e) {
      throw AuthException(_serverMessage(e));
    }
  }

  static String _serverMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach the server. Is the backend running?';
    }
    return 'Something went wrong. Please try again.';
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider)),
);
