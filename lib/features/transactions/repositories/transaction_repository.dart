
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  static const int _pageSize = 1000;

  String get _userId {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('Pengguna belum login.');
    }

    return user.id;
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // Mengambil kategori pengguna.
  Future<List<CategoryModel>> getCategories({
    required String type,
  }) async {
    final response = await _client
        .from('categories')
        .select()
        .eq('user_id', _userId)
        .eq('type', type)
        .order('name', ascending: true);

    return (response as List)
        .map(
          (item) => CategoryModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // Mengambil daftar transaksi terbaru.
  Future<List<TransactionModel>> getTransactions({
    int limit = 100,
  }) async {
    final response = await _client
        .from('transactions')
        .select()
        .eq('user_id', _userId)
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map(
          (item) => TransactionModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // Mengambil seluruh transaksi aktif berdasarkan periode laporan.
  // Menggunakan pagination agar tidak terbatasi 100 atau 1000 data.
  Future<List<TransactionModel>> getTransactionsByPeriod({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final start = _formatDate(startDate);
    final end = _formatDate(endDate);

    final List<TransactionModel> transactions = [];

    var offset = 0;

    while (true) {
      final response = await _client
          .from('transactions')
          .select()
          .eq('user_id', _userId)
          .eq('status', 'active')
          .gte('transaction_date', start)
          .lt('transaction_date', end)
          .order('transaction_date', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + _pageSize - 1);

      final rows = response as List;

      transactions.addAll(
        rows.map(
          (item) => TransactionModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        ),
      );

      if (rows.length < _pageSize) {
        break;
      }

      offset += _pageSize;
    }

    return transactions;
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
      'transaction_date': _formatDate(transactionDate),
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
          'transaction_date': _formatDate(transactionDate),
        })
        .eq('id', id)
        .eq('user_id', _userId)
        .eq('status', 'active');
  }

  // Membatalkan transaksi.
  Future<void> cancelTransaction({
    required String id,
    required String reason,
  }) async {
    await _client.rpc(
      'cancel_transaction',
      params: {
        'p_transaction_id': id,
        'p_reason': reason.trim(),
      },
    );
  }
}
