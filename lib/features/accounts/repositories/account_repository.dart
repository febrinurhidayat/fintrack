import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../models/account_model.dart';

class AccountRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  String get _userId {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('Pengguna belum login.');
    }

    return user.id;
  }

  Future<List<AccountModel>> getAccounts() async {
    final response = await _client
        .from('account_balances')
        .select()
        .eq('user_id', _userId)
        .order('name', ascending: true);

    return (response as List)
        .map((item) => AccountModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> createAccount({
    required String name,
    required String accountType,
    String? bankName,
    String? accountNumber,
    required double initialBalance,
  }) async {
    await _client.from('accounts').insert({
      'user_id': _userId,
      'name': name.trim(),
      'account_type': accountType,
      'bank_name': bankName?.trim().isEmpty == true ? null : bankName?.trim(),
      'account_number': accountNumber?.trim().isEmpty == true
          ? null
          : accountNumber?.trim(),
      'initial_balance': initialBalance,
      'currency': 'IDR',
      'is_active': true,
    });
  }

  Future<void> updateAccount({
    required String id,
    required String name,
    required String accountType,
    String? bankName,
    String? accountNumber,
    required double initialBalance,
  }) async {
    await _client
        .from('accounts')
        .update({
          'name': name.trim(),
          'account_type': accountType,
          'bank_name': bankName?.trim().isEmpty == true
              ? null
              : bankName?.trim(),
          'account_number': accountNumber?.trim().isEmpty == true
              ? null
              : accountNumber?.trim(),
          'initial_balance': initialBalance,
        })
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<void> deactivateAccount(String id) async {
    await _client
        .from('accounts')
        .update({'is_active': false})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<void> activateAccount(String id) async {
    await _client
        .from('accounts')
        .update({'is_active': true})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<void> deleteAccount(String id) async {
    await _client.rpc('delete_account_safely', params: {'p_account_id': id});
  }
}
