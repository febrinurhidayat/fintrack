
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

  Future<List<TransferModel>> getTransfers() async {
    return _fetchAccountTransfers();
  }

  // Transfer sebelum tanggal mulai laporan.
  Future<List<TransferModel>> getAccountTransfersBefore({
    required String accountId,
    required DateTime beforeDate,
  }) async {
    return _fetchAccountTransfers(
      accountId: accountId,
      beforeDate: _formatDate(beforeDate),
    );
  }

  // Transfer selama periode laporan.
  Future<List<TransferModel>> getAccountTransfersByPeriod({
    required String accountId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final endExclusive = DateTime(
      endDate.year,
      endDate.month,
      endDate.day + 1,
    );

    return _fetchAccountTransfers(
      accountId: accountId,
      startDate: _formatDate(startDate),
      endDate: _formatDate(endExclusive),
    );
  }

  Future<List<TransferModel>> _fetchAccountTransfers({
    String? accountId,
    String? beforeDate,
    String? startDate,
    String? endDate,
  }) async {
    final List<TransferModel> transfers = [];

    var offset = 0;

    while (true) {
      var query = _client
          .from('transfers')
          .select()
          .eq('user_id', _userId);

      if (accountId != null) {
        query = query.or(
          'from_account_id.eq.$accountId,'
          'to_account_id.eq.$accountId',
        );
      }

      if (beforeDate != null) {
        query = query.lt('transfer_date', beforeDate);
      }

      if (startDate != null) {
        query = query
            .gte('transfer_date', startDate)
            .lt('transfer_date', endDate!);
      }

      final response = await query
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

      if (rows.length < _pageSize) break;

      offset += _pageSize;
    }

    return transfers;
  }

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
