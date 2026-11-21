import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/models/account_model.dart';
import '../../accounts/providers/account_provider.dart';

import '../../transactions/models/transaction_model.dart';
import '../../transactions/providers/transaction_provider.dart';

import '../../transfers/models/transfer_model.dart';
import '../../transfers/providers/transfer_provider.dart';

class StatementFilter {
  final String accountId;
  final DateTime startDate;
  final DateTime endDate;

  const StatementFilter({
    required this.accountId,
    required this.startDate,
    required this.endDate,
  });

  @override
  bool operator ==(Object other) {
    return other is StatementFilter &&
        other.accountId == accountId &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(accountId, startDate, endDate);
}

class AccountStatement {
  final AccountModel account;
  final DateTime startDate;
  final DateTime endDate;
  final double openingBalance;
  final double totalIncome;
  final double totalExpense;
  final double transferIn;
  final double transferOut;
  final double closingBalance;
  final List<TransactionModel> transactions;
  final List<TransferModel> transfers;

  const AccountStatement({
    required this.account,
    required this.startDate,
    required this.endDate,
    required this.openingBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.transferIn,
    required this.transferOut,
    required this.closingBalance,
    required this.transactions,
    required this.transfers,
  });
}

final accountStatementProvider =
    FutureProvider.family<AccountStatement, StatementFilter>(
  (ref, filter) async {
    final accounts = await ref.watch(accountsProvider.future);

    final account = accounts.firstWhere(
      (item) => item.id == filter.accountId,
      orElse: () => throw Exception('Rekening tidak ditemukan.'),
    );

    final transactionRepository =
        ref.read(transactionRepositoryProvider);

    final transferRepository =
        ref.read(transferRepositoryProvider);

    final startDate = DateTime(
      filter.startDate.year,
      filter.startDate.month,
      filter.startDate.day,
    );

    final endDate = DateTime(
      filter.endDate.year,
      filter.endDate.month,
      filter.endDate.day,
    );

    if (endDate.isBefore(startDate)) {
      throw Exception('Tanggal akhir tidak boleh sebelum tanggal awal.');
    }

    final results = await Future.wait([
      transactionRepository.getAccountTransactionsBefore(
        accountId: account.id,
        beforeDate: startDate,
      ),
      transactionRepository.getAccountTransactionsByPeriod(
        accountId: account.id,
        startDate: startDate,
        endDate: endDate,
      ),
      transferRepository.getAccountTransfersBefore(
        accountId: account.id,
        beforeDate: startDate,
      ),
      transferRepository.getAccountTransfersByPeriod(
        accountId: account.id,
        startDate: startDate,
        endDate: endDate,
      ),
    ]);

    final previousTransactions =
        results[0] as List<TransactionModel>;
    final periodTransactions =
        results[1] as List<TransactionModel>;
    final previousTransfers =
        results[2] as List<TransferModel>;
    final periodTransfers =
        results[3] as List<TransferModel>;

    // Hitung saldo sebelum periode dimulai.
    final previousIncome = previousTransactions
        .where((item) => item.isIncome)
        .fold<double>(0, (sum, item) => sum + item.amount);

    final previousExpense = previousTransactions
        .where((item) => item.isExpense)
        .fold<double>(0, (sum, item) => sum + item.amount);

    final previousTransferIn = previousTransfers
        .where((item) => item.toAccountId == account.id)
        .fold<double>(0, (sum, item) => sum + item.amount);

    final previousTransferOut = previousTransfers
        .where((item) => item.fromAccountId == account.id)
        .fold<double>(0, (sum, item) => sum + item.amount);

    final openingBalance = account.initialBalance +
        previousIncome -
        previousExpense +
        previousTransferIn -
        previousTransferOut;

    // Hitung transaksi pada periode yang dipilih.
    final totalIncome = periodTransactions
        .where((item) => item.isIncome)
        .fold<double>(0, (sum, item) => sum + item.amount);

    final totalExpense = periodTransactions
        .where((item) => item.isExpense)
        .fold<double>(0, (sum, item) => sum + item.amount);

    final transferIn = periodTransfers
        .where((item) => item.toAccountId == account.id)
        .fold<double>(0, (sum, item) => sum + item.amount);

    final transferOut = periodTransfers
        .where((item) => item.fromAccountId == account.id)
        .fold<double>(0, (sum, item) => sum + item.amount);

    final closingBalance = openingBalance +
        totalIncome -
        totalExpense +
        transferIn -
        transferOut;

    return AccountStatement(
      account: account,
      startDate: startDate,
      endDate: endDate,
      openingBalance: openingBalance,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      transferIn: transferIn,
      transferOut: transferOut,
      closingBalance: closingBalance,
      transactions: periodTransactions,
      transfers: periodTransfers,
    );
  },
);