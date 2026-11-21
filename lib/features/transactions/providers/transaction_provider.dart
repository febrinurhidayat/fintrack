
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';

final transactionRepositoryProvider =
    Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

// Daftar transaksi terbaru.
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

// Transaksi aktif berdasarkan bulan laporan.
final reportTransactionsProvider =
    FutureProvider.family<List<TransactionModel>, DateTime>(
  (ref, selectedMonth) {
    final startDate = DateTime(
      selectedMonth.year,
      selectedMonth.month,
      1,
    );

    final endDate = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      1,
    );

    return ref
        .watch(transactionRepositoryProvider)
        .getTransactionsByPeriod(
          startDate: startDate,
          endDate: endDate,
        );
  },
);
