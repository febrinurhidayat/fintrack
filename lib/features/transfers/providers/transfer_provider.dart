import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transfer_model.dart';
import '../repositories/transfer_repository.dart';

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  return TransferRepository();
});

// Mengambil seluruh riwayat transfer.
final transfersProvider = FutureProvider<List<TransferModel>>((ref) {
  return ref.watch(transferRepositoryProvider).getTransfers();
});
