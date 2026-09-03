import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_repository.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.userId,
    this.isNewUser = false,
  });

  final AuthStatus status;
  final String? userId;
  final bool isNewUser;

  static const unknown = AuthState(status: AuthStatus.unknown);
  static const unauthenticated = AuthState(status: AuthStatus.unauthenticated);
}

/// Holds the live session tokens. Kept separate from AuthController so the
/// Dio interceptor can read them without a provider cycle.
class TokenStore {
  String? accessToken;
  String? refreshToken;

  static const _kAccess = 'zc.access';
  static const _kRefresh = 'zc.refresh';
  static const _kUserId = 'zc.userId';

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString(_kAccess);
    refreshToken = prefs.getString(_kRefresh);
  }

  Future<void> save(TokenBundle bundle) async {
    accessToken = bundle.accessToken;
    refreshToken = bundle.refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccess, bundle.accessToken);
    await prefs.setString(_kRefresh, bundle.refreshToken);
    await prefs.setString(_kUserId, bundle.userId);
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
    await prefs.remove(_kUserId);
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

/// Session lifecycle: restore on boot (rotate the stored refresh token),
/// request/verify OTP, logout. Splash routes on [AuthState.status].
class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);
  TokenStore get _tokens => ref.read(tokenStoreProvider);

  @override
  AuthState build() => AuthState.unknown;

  /// Called once by the splash screen. Tries to turn a stored refresh token
  /// into a live session; otherwise falls back to unauthenticated.
  Future<void> restore() async {
    await _tokens.restore();
    final rt = _tokens.refreshToken;
    if (rt == null) {
      state = AuthState.unauthenticated;
      return;
    }
    try {
      final bundle = await _repo.refresh(rt);
      await _tokens.save(bundle);
      state = AuthState(
          status: AuthStatus.authenticated, userId: bundle.userId);
    } on AuthException {
      await _tokens.clear();
      state = AuthState.unauthenticated;
    }
  }

  /// Step 1 — returns the OTP session handle. Throws [AuthException] with
  /// the server's message on failure (screens surface it in a snackbar).
  Future<String> requestOtp(String phoneE164) => _repo.requestOtp(phoneE164);

  /// Step 2 — on success the app is authenticated.
  Future<void> verifyOtp(String session, String code) async {
    final bundle = await _repo.verifyOtp(session, code);
    await _tokens.save(bundle);
    state = AuthState(
      status: AuthStatus.authenticated,
      userId: bundle.userId,
      isNewUser: bundle.newUser,
    );
  }

  Future<void> logout() async {
    await _tokens.clear();
    state = AuthState.unauthenticated;
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
