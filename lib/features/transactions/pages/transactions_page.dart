import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../accounts/models/account_model.dart';
import '../../accounts/providers/account_provider.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import 'transaction_form_page.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy', 'id_ID').format(date);
  }

  Future<void> _openTransactionForm(
    BuildContext context,
    WidgetRef ref, {
    TransactionModel? transaction,
  }) async {
    if (transaction?.isCancelled == true) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionFormPage(transaction: transaction),
      ),
    );

    if (result == true) {
      ref.invalidate(transactionsProvider);
      ref.invalidate(accountsProvider);
    }
  }

  Future<void> _cancelTransaction(
    BuildContext context,
    WidgetRef ref,
    TransactionModel transaction,
  ) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _CancelTransactionDialog(),
    );

    if (reason == null || reason.trim().isEmpty) return;

    try {
      await ref
          .read(transactionRepositoryProvider)
          .cancelTransaction(id: transaction.id, reason: reason.trim());

      ref.invalidate(transactionsProvider);
      ref.invalidate(accountsProvider);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaksi berhasil dibatalkan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membatalkan transaksi: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final incomeCategoriesAsync = ref.watch(incomeCategoriesProvider);
    final expenseCategoriesAsync = ref.watch(expenseCategoriesProvider);

    final accounts = accountsAsync.asData?.value ?? <AccountModel>[];

    final categories = [
      ...(incomeCategoriesAsync.asData?.value ?? <CategoryModel>[]),
      ...(expenseCategoriesAsync.asData?.value ?? <CategoryModel>[]),
    ];

    final accountNames = {
      for (final account in accounts) account.id: account.name,
    };

    final categoryNames = {
      for (final category in categories) category.id: category.name,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Transaksi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: () {
              ref.invalidate(transactionsProvider);
              ref.invalidate(accountsProvider);
              ref.invalidate(incomeCategoriesProvider);
              ref.invalidate(expenseCategoriesProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                const Text(
                  'Gagal memuat transaksi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    ref.invalidate(transactionsProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (transactions) {
          final activeTransactions = transactions
              .where((transaction) => transaction.isActive)
              .toList();

          final totalIncome = activeTransactions
              .where((transaction) => transaction.isIncome)
              .fold<double>(
                0,
                (total, transaction) => total + transaction.amount,
              );

          final totalExpense = activeTransactions
              .where((transaction) => transaction.isExpense)
              .fold<double>(
                0,
                (total, transaction) => total + transaction.amount,
              );

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(transactionsProvider);
              ref.invalidate(accountsProvider);

              await Future.wait([
                ref.read(transactionsProvider.future),
                ref.read(accountsProvider.future),
              ]);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Pemasukan',
                        amount: totalIncome,
                        color: Colors.green,
                        icon: Icons.arrow_downward_rounded,
                        formatCurrency: _formatCurrency,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Pengeluaran',
                        amount: totalExpense,
                        color: Colors.red,
                        icon: Icons.arrow_upward_rounded,
                        formatCurrency: _formatCurrency,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Riwayat Transaksi',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (transactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Belum ada transaksi',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tambahkan pemasukan atau pengeluaran pertama Anda.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ...transactions.map((transaction) {
                  final isIncome = transaction.isIncome;
                  final isCancelled = transaction.isCancelled;

                  final color = isCancelled
                      ? Colors.grey
                      : isIncome
                      ? Colors.green
                      : Colors.red;

                  final accountName =
                      accountNames[transaction.accountId] ??
                      'Akun tidak ditemukan';

                  final categoryName = transaction.categoryId == null
                      ? 'Tanpa kategori'
                      : categoryNames[transaction.categoryId] ??
                            'Kategori tidak ditemukan';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isCancelled
                            ? Colors.grey.withValues(alpha: 0.4)
                            : Theme.of(context).dividerColor,
                      ),
                    ),
                    child: InkWell(
                      onTap: isCancelled
                          ? null
                          : () {
                              _openTransactionForm(
                                context,
                                ref,
                                transaction: transaction,
                              );
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.12),
                              child: Icon(
                                isCancelled
                                    ? Icons.block_outlined
                                    : isIncome
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    transaction.description?.isNotEmpty == true
                                        ? transaction.description!
                                        : categoryName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isCancelled ? Colors.grey : null,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '$categoryName • $accountName',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _formatDate(transaction.transactionDate),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (isCancelled) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Dibatalkan',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    if (transaction.cancellationReason !=
                                            null &&
                                        transaction
                                            .cancellationReason!
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 5),
                                      Text(
                                        'Alasan: ${transaction.cancellationReason}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${isIncome ? '+' : '-'}${_formatCurrency(transaction.amount)}',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    decoration: isCancelled
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (isCancelled)
                                  const Icon(
                                    Icons.lock_outline,
                                    size: 16,
                                    color: Colors.grey,
                                  )
                                else
                                  IconButton(
                                    tooltip: 'Batalkan transaksi',
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      _cancelTransaction(
                                        context,
                                        ref,
                                        transaction,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.block_outlined,
                                      size: 19,
                                      color: Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _openTransactionForm(context, ref);
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah Transaksi'),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;
  final String Function(double) formatCurrency;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatCurrency(amount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelTransactionDialog extends StatefulWidget {
  const _CancelTransactionDialog();

  @override
  State<_CancelTransactionDialog> createState() =>
      _CancelTransactionDialogState();
}

class _CancelTransactionDialogState extends State<_CancelTransactionDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reasonController.text.trim();

    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alasan pembatalan wajib diisi.')),
      );
      return;
    }

    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Batalkan Transaksi',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transaksi tidak akan dihapus, tetapi tidak lagi memengaruhi saldo akun.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Alasan pembatalan',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: 'Contoh: Salah memasukkan nominal transaksi',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kembali'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _submit,
          child: const Text('Batalkan Transaksi'),
        ),
      ],
    );
  }
}
