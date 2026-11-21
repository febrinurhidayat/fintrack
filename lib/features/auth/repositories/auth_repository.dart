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
      data: {'full_name': fullName.trim()},
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
  Future<void> resendSignupOtp({required String email}) async {
    await _client.auth.resend(type: OtpType.signup, email: email.trim());
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
  Future<void> sendPasswordResetOtp({required String email}) async {
    await _client.auth.resetPasswordForEmail(email.trim());
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
  Future<UserResponse> updatePassword({required String newPassword}) async {
    return await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  // MENGUBAH PASSWORD DARI HALAMAN AKUN
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _client.auth.currentUser;
    final email = user?.email;

    if (user == null || email == null) {
      throw Exception('Sesi pengguna tidak ditemukan.');
    }

    if (currentPassword.isEmpty || newPassword.isEmpty) {
      throw Exception('Password tidak boleh kosong.');
    }

    if (newPassword.length < 6) {
      throw Exception('Password baru minimal 6 karakter.');
    }

    // Verifikasi password lama.
    await _client.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );

    // Simpan password baru setelah verifikasi berhasil.
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  // MEMINTA PERUBAHAN EMAIL
  Future<void> changeEmail({required String newEmail}) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('Sesi pengguna tidak ditemukan.');
    }

    final email = newEmail.trim().toLowerCase();

    if (email.isEmpty) {
      throw Exception('Email baru tidak boleh kosong.');
    }

    if (email == user.email?.toLowerCase()) {
      throw Exception('Email baru sama dengan email saat ini.');
    }

    await _client.auth.updateUser(UserAttributes(email: email));
  }

  // LOGOUT
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // CURRENT USER
  User? get currentUser => _client.auth.currentUser;

  // AUTH SESSION STREAM
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
