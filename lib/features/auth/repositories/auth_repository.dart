
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

class AuthRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // REGISTER
  // Mengirim OTP verifikasi ke email.
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
      },
    );
  }

  // VERIFIKASI EMAIL REGISTER
  Future<AuthResponse> verifySignupOtp({
    required String email,
    required String token,
  }) async {
    return await _client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );
  }

  // KIRIM ULANG OTP REGISTER
  Future<void> resendSignupOtp({
    required String email,
  }) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
    );
  }

  // LOGIN
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  // MEMINTA OTP RESET PASSWORD
  Future<void> sendPasswordResetOtp({
    required String email,
  }) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
    );
  }

  // VERIFIKASI OTP RESET PASSWORD
  Future<AuthResponse> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    return await _client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.recovery,
    );
  }

  // UPDATE PASSWORD SETELAH OTP VALID
  Future<UserResponse> updatePassword({
    required String newPassword,
  }) async {
    return await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // LOGOUT
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // CURRENT USER
  User? get currentUser => _client.auth.currentUser;

  // AUTH SESSION STREAM
  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;
}
