import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  String get _userId {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('Pengguna belum login.');
    }

    return user.id;
  }

  // Mengambil seluruh kategori milik pengguna.
  Future<List<CategoryModel>> getCategories({required String type}) async {
    final response = await _client
        .from('categories')
        .select()
        .eq('user_id', _userId)
        .eq('type', type)
        .order('name', ascending: true);

    return (response as List)
        .map((item) => CategoryModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  // Mengambil daftar transaksi.
  Future<List<TransactionModel>> getTransactions({int limit = 100}) async {
    final response = await _client
        .from('transactions')
        .select()
        .eq('user_id', _userId)
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map(
          (item) => TransactionModel.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  // Menambahkan transaksi.
  Future<void> createTransaction({
    required String accountId,
    required String type,
    required double amount,
    String? categoryId,
    String? description,
    required DateTime transactionDate,
  }) async {
    await _client.from('transactions').insert({
      'user_id': _userId,
      'account_id': accountId,
      'category_id': categoryId,
      'type': type,
      'amount': amount,
      'description': description?.trim().isEmpty == true
          ? null
          : description?.trim(),
      'transaction_date':
          '${transactionDate.year.toString().padLeft(4, '0')}-'
          '${transactionDate.month.toString().padLeft(2, '0')}-'
          '${transactionDate.day.toString().padLeft(2, '0')}',
    });
  }

  // Mengubah transaksi.
  Future<void> updateTransaction({
    required String id,
    required String accountId,
    required String type,
    required double amount,
    String? categoryId,
    String? description,
    required DateTime transactionDate,
  }) async {
    await _client
        .from('transactions')
        .update({
          'account_id': accountId,
          'category_id': categoryId,
          'type': type,
          'amount': amount,
          'description': description?.trim().isEmpty == true
              ? null
              : description?.trim(),
          'transaction_date':
              '${transactionDate.year.toString().padLeft(4, '0')}-'
              '${transactionDate.month.toString().padLeft(2, '0')}-'
              '${transactionDate.day.toString().padLeft(2, '0')}',
        })
        .eq('id', id)
        .eq('user_id', _userId);
  }

  //cancel transaksi
  Future<void> cancelTransaction({
    required String id,
    required String reason,
  }) async {
    await _client.rpc(
      'cancel_transaction',
      params: {'p_transaction_id': id, 'p_reason': reason.trim()},
    );
  }
}
