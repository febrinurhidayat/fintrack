import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

class ProfileRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // Mengambil data profil pengguna yang sedang login.
  Future<Map<String, dynamic>> getProfile() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('Pengguna belum login.');
    }

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) {
      throw Exception('Data profil tidak ditemukan.');
    }

    return response;
  }

  // Memperbarui nama lengkap.
  Future<void> updateFullName({
    required String fullName,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('Pengguna belum login.');
    }

    final name = fullName.trim();

    if (name.isEmpty) {
      throw Exception('Nama lengkap tidak boleh kosong.');
    }

    await _client.from('profiles').update({
      'full_name': name,
    }).eq('id', user.id);

    // Sinkronkan nama pada metadata Supabase Auth.
    await _client.auth.updateUser(
      UserAttributes(
        data: {'full_name': name},
      ),
    );
  }

  // Mengunggah foto profil ke Supabase Storage.
  Future<String> uploadAvatar({
    required File imageFile,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('Pengguna belum login.');
    }

    if (!await imageFile.exists()) {
      throw Exception('File foto tidak ditemukan.');
    }

    final extension = imageFile.path.split('.').last.toLowerCase();

    final contentType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw Exception('Format foto harus JPG, PNG, atau WebP.'),
    };

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}.$extension';

    final filePath = '${user.id}/$fileName';

    await _client.storage.from('avatars').upload(
      filePath,
      imageFile,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: false,
      ),
    );

    final avatarUrl = _client.storage
        .from('avatars')
        .getPublicUrl(filePath);

    await _client.from('profiles').update({
      'avatar_url': avatarUrl,
    }).eq('id', user.id);

    return avatarUrl;
  }

  // Mengambil informasi akun dari Supabase Auth.
  User? get currentUser => _client.auth.currentUser;
}
