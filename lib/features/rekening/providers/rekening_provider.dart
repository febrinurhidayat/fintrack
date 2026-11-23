
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/rekening_model.dart';
import '../repositories/rekening_repository.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository();
});

final accountsProvider = FutureProvider<List<AccountModel>>((ref) {
  return ref.watch(accountRepositoryProvider).getAccounts();
});

final activeAccountsProvider = Provider<AsyncValue<List<AccountModel>>>(
  (ref) {
    return ref.watch(accountsProvider).whenData(
      (accounts) => accounts.where((account) => account.isActive).toList(),
    );
  },
);

final totalBalanceProvider = Provider<AsyncValue<double>>((ref) {
  return ref.watch(activeAccountsProvider).whenData(
    (accounts) => accounts.fold<double>(
      0,
      (total, account) => total + account.currentBalance,
    ),
  );
});
