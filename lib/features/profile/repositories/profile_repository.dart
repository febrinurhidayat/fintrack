import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

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
  Future<void> updateFullName({required String fullName}) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('Pengguna belum login.');
    }

    final name = fullName.trim();

    if (name.isEmpty) {
      throw Exception('Nama lengkap tidak boleh kosong.');
    }

    await _client
        .from('profiles')
        .update({'full_name': name})
        .eq('id', user.id);

    // Sinkronkan nama pada metadata Supabase Auth.
    await _client.auth.updateUser(UserAttributes(data: {'full_name': name}));
  }

  // Mengunggah foto profil dan menghapus foto lama.
  Future<String> uploadAvatar({required File imageFile}) async {
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

    // Ambil URL foto lama.
    final profile = await _client
        .from('profiles')
        .select('avatar_url')
        .eq('id', user.id)
        .maybeSingle();

    final oldAvatarUrl = profile?['avatar_url'] as String?;

    // Siapkan nama file baru.
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';

    final newFilePath = '${user.id}/$fileName';

    // Upload foto baru terlebih dahulu.
    await _client.storage
        .from('avatars')
        .upload(
          newFilePath,
          imageFile,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    final avatarUrl = _client.storage.from('avatars').getPublicUrl(newFilePath);

    try {
      // Perbarui URL foto profil di database.
      await _client
          .from('profiles')
          .update({'avatar_url': avatarUrl})
          .eq('id', user.id);
    } catch (e) {
      // Jika update database gagal, hapus foto baru.
      try {
        await _client.storage.from('avatars').remove([newFilePath]);
      } catch (_) {}

      rethrow;
    }

    // Hapus foto lama setelah foto baru berhasil disimpan.
    if (oldAvatarUrl != null && oldAvatarUrl.isNotEmpty) {
      try {
        const marker = '/storage/v1/object/public/avatars/';
        final markerIndex = oldAvatarUrl.indexOf(marker);

        if (markerIndex != -1) {
          final oldFilePath = Uri.decodeComponent(
            oldAvatarUrl.substring(markerIndex + marker.length),
          );

          // Pastikan foto lama milik pengguna yang sedang login.
          if (oldFilePath.startsWith('${user.id}/') &&
              oldFilePath != newFilePath) {
            await _client.storage.from('avatars').remove([oldFilePath]);
          }
        }
      } catch (e) {
        // Foto baru tetap digunakan jika penghapusan foto lama gagal.
        debugPrint('Gagal menghapus foto profil lama: $e');
      }
    }

    return avatarUrl;
  }

  // Mengambil informasi akun dari Supabase Auth.
  User? get currentUser => _client.auth.currentUser;
}
