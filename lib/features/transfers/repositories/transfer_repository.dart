import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../models/transfer_model.dart';

class TransferRepository {
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

  // Mengambil riwayat transfer pengguna.
  Future<List<TransferModel>> getTransfers() async {
    final List<TransferModel> transfers = [];

    var offset = 0;

    while (true) {
      final response = await _client
          .from('transfers')
          .select()
          .eq('user_id', _userId)
          .order('transfer_date', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + _pageSize - 1);

      final rows = response as List;

      transfers.addAll(
        rows.map(
          (item) => TransferModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        ),
      );

      if (rows.length < _pageSize) {
        break;
      }

      offset += _pageSize;
    }

    return transfers;
  }

  // Membuat transfer antar akun.
  Future<String> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    String? description,
    required DateTime transferDate,
  }) async {
    if (fromAccountId == toAccountId) {
      throw Exception(
        'Rekening sumber dan tujuan tidak boleh sama.',
      );
    }

    if (amount <= 0) {
      throw Exception('Nominal transfer harus lebih dari 0.');
    }

    final response = await _client.rpc(
      'create_transfer',
      params: {
        'p_from_account_id': fromAccountId,
        'p_to_account_id': toAccountId,
        'p_amount': amount,
        'p_description': description?.trim().isEmpty == true
            ? null
            : description?.trim(),
        'p_transfer_date': _formatDate(transferDate),
      },
    );

    return response.toString();
  }
}
