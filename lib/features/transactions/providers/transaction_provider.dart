
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';

final transactionRepositoryProvider =
    Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

// Daftar transaksi.
final transactionsProvider =
    FutureProvider<List<TransactionModel>>((ref) {
  return ref.watch(transactionRepositoryProvider).getTransactions();
});

// Kategori pemasukan.
final incomeCategoriesProvider =
    FutureProvider<List<CategoryModel>>((ref) {
  return ref
      .watch(transactionRepositoryProvider)
      .getCategories(type: 'income');
});

// Kategori pengeluaran.
final expenseCategoriesProvider =
    FutureProvider<List<CategoryModel>>((ref) {
  return ref
      .watch(transactionRepositoryProvider)
      .getCategories(type: 'expense');
});
