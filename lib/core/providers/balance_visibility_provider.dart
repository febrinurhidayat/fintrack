
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BalanceVisibilityNotifier extends Notifier<bool> {
  static const String _storageKey = 'balance_visibility';

  bool _userChanged = false;
  bool _disposed = false;

  @override
  bool build() {
    ref.onDispose(() {
      _disposed = true;
    });

    _restorePreference();

    // Default tersembunyi sampai preferensi berhasil dibaca.
    return false;
  }

  Future<void> _restorePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_disposed || _userChanged) return;

      state = prefs.getBool(_storageKey) ?? true;
    } catch (_) {
      // Jika gagal membaca, tetap sembunyikan nominal.
    }
  }

  void toggle() {
    _userChanged = true;
    state = !state;
    _savePreference(state);
  }

  void show() {
    _userChanged = true;
    state = true;
    _savePreference(true);
  }

  void hide() {
    _userChanged = true;
    state = false;
    _savePreference(false);
  }

  Future<void> _savePreference(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storageKey, value);
    } catch (_) {
      // Tidak mengganggu tampilan jika penyimpanan gagal.
    }
  }
}

final balanceVisibilityProvider =
    NotifierProvider<BalanceVisibilityNotifier, bool>(
  BalanceVisibilityNotifier.new,
);
