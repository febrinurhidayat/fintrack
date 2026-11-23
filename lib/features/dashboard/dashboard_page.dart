import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../rekening/pages/rekening_page.dart';
import '../rekening/providers/rekening_provider.dart';
import '../transactions/models/transaction_model.dart';
import '../transactions/pages/transaction_form_page.dart';
import '../transactions/pages/transactions_page.dart';
import '../transactions/providers/transaction_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/providers/balance_visibility_provider.dart';
import '../profile/providers/profile_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  Future<void> _openAccounts(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountsPage()),
    );

    if (!mounted) return;
    _refreshData();
  }

  Future<void> _openTransactions(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransactionsPage()),
    );

    if (!mounted) return;
    _refreshData();
  }

  Future<void> _addTransaction(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TransactionFormPage()),
    );

    if (!mounted) return;

    if (result == true) {
      _refreshData();
    }
  }

  Future<void> _refreshData() async {
    ref.invalidate(accountsProvider);
    ref.invalidate(activeAccountsProvider);
    ref.invalidate(totalBalanceProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(incomeCategoriesProvider);
    ref.invalidate(expenseCategoriesProvider);
    ref.invalidate(profileProvider);

    await Future.wait([
      ref.read(accountsProvider.future),
      ref.read(transactionsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final totalBalanceAsync = ref.watch(totalBalanceProvider);
    final accountsAsync = ref.watch(activeAccountsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final profileAsync = ref.watch(profileProvider);
    final isBalanceVisible = ref.watch(balanceVisibilityProvider);

    final profile = profileAsync.when(
      data: (data) => data,
      loading: () => null,
      error: (_, _) => null,
    );

    final avatarUrl = profile?['avatar_url'] as String?;
    final fullName = profile?['full_name'] as String? ?? '';

    final transactions =
        transactionsAsync.asData?.value ?? <TransactionModel>[];

    final now = DateTime.now();

    final monthlyTransactions = transactions.where((transaction) {
      return transaction.isActive &&
          transaction.transactionDate.year == now.year &&
          transaction.transactionDate.month == now.month;
    }).toList();

    final totalIncome = monthlyTransactions
        .where((transaction) => transaction.isIncome)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);

    final totalExpense = monthlyTransactions
        .where((transaction) => transaction.isExpense)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? const Icon(
                      Icons.person_rounded,
                      color: AppTheme.primary,
                      size: 25,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fullName.isNotEmpty ? fullName : 'Pengguna',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Personal Finance',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Total saldo
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Colors.white70,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Total Saldo',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      totalBalanceAsync.when(
                        data: (balance) => Row(
                          children: [
                            Expanded(
                              child: Text(
                                isBalanceVisible
                                    ? CurrencyFormatter.format(balance)
                                    : 'Rp ******',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: isBalanceVisible
                                  ? 'Sembunyikan saldo'
                                  : 'Tampilkan saldo',
                              onPressed: () {
                                ref
                                    .read(balanceVisibilityProvider.notifier)
                                    .toggle();
                              },
                              icon: Icon(
                                isBalanceVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                        loading: () => const SizedBox(
                          height: 34,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        error: (_, _) => const Text(
                          'Gagal memuat saldo',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Seluruh rekening aktif',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 26),

                // Daftar akun
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Akun Saya',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openAccounts(context),
                      child: const Text('Lihat Semua'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                accountsAsync.when(
                  data: (accounts) {
                    if (accounts.isEmpty) {
                      return _EmptyAccounts(
                        onAdd: () => _openAccounts(context),
                      );
                    }

                    final displayedAccounts = accounts.take(3).toList();

                    return Column(
                      children: [
                        ...displayedAccounts.map(
                          (account) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    _accountIcon(account.accountType),
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        account.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _accountTypeLabel(account.accountType),
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isBalanceVisible
                                      ? CurrencyFormatter.format(
                                          account.currentBalance,
                                        )
                                      : 'Rp ***',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (accounts.length > 3)
                          Align(
                            alignment: Alignment.center,
                            child: TextButton(
                              onPressed: () => _openAccounts(context),
                              child: const Text('Lihat akun lainnya'),
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, _) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Gagal memuat akun: $error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Ringkasan keuangan
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ringkasan Keuangan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('MMMM yyyy', 'id_ID').format(now),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Pemasukan',
                        amount: totalIncome,
                        icon: Icons.trending_up_rounded,
                        color: Colors.green,
                        isLoading: transactionsAsync.isLoading,
                        isVisible: isBalanceVisible,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Pengeluaran',
                        amount: totalExpense,
                        icon: Icons.trending_down_rounded,
                        color: Colors.red,
                        isLoading: transactionsAsync.isLoading,
                        isVisible: isBalanceVisible,
                      ),
                    ),
                  ],
                ),

                if (transactionsAsync.hasError) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Gagal memuat ringkasan transaksi: '
                    '${transactionsAsync.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],

                const SizedBox(height: 26),

                // Aktivitas terbaru
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Aktivitas Terbaru',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openTransactions(context),
                      child: const Text('Lihat Semua'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                transactionsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, _) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 34,
                        ),
                        const SizedBox(height: 8),
                        const Text('Gagal memuat aktivitas transaksi'),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref.invalidate(transactionsProvider),
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return _EmptyTransactions(
                        onAdd: () => _addTransaction(context),
                      );
                    }

                    final recentTransactions = items.take(5).toList();

                    final currentAccounts = accountsAsync.asData?.value ?? [];

                    final accountNames = {
                      for (final account in currentAccounts)
                        account.id: account.name,
                    };

                    return Column(
                      children: [
                        ...recentTransactions.map(
                          (transaction) => _RecentTransactionTile(
                            transaction: transaction,
                            accountName:
                                accountNames[transaction.accountId] ??
                                'Akun tidak ditemukan',
                            isBalanceVisible: isBalanceVisible,
                          ),
                        ),
                        if (items.length > 5)
                          Align(
                            alignment: Alignment.center,
                            child: TextButton(
                              onPressed: () => _openTransactions(context),
                              child: const Text('Lihat transaksi lainnya'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _accountIcon(String type) {
    switch (type) {
      case 'bank':
        return Icons.account_balance_rounded;
      case 'ewallet':
        return Icons.phone_android_rounded;
      case 'cash':
        return Icons.payments_outlined;
      default:
        return Icons.wallet_outlined;
    }
  }

  static String _accountTypeLabel(String type) {
    switch (type) {
      case 'bank':
        return 'Rekening Bank';
      case 'ewallet':
        return 'E-Wallet';
      case 'cash':
        return 'Uang Tunai';
      default:
        return 'Lainnya';
    }
  }
}

class _EmptyAccounts extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyAccounts({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 42,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Belum ada akun',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          const Text(
            'Tambahkan rekening bank, e-wallet, atau uang tunai.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Tambah Akun'),
          ),
        ],
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyTransactions({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 42,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Belum ada transaksi',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          const Text(
            'Transaksi kamu akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Catat Transaksi'),
          ),
        ],
      ),
    );
  }
}

class _RecentTransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final String accountName;
  final bool isBalanceVisible;

  const _RecentTransactionTile({
    required this.transaction,
    required this.accountName,
    required this.isBalanceVisible,
  });

  @override
  Widget build(BuildContext context) {
    final isCancelled = transaction.isCancelled;
    final isIncome = transaction.isIncome;

    final color = isCancelled
        ? Colors.grey
        : isIncome
        ? Colors.green
        : Colors.red;

    final title = transaction.description?.trim().isNotEmpty == true
        ? transaction.description!.trim()
        : isIncome
        ? 'Pemasukan'
        : 'Pengeluaran';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCancelled ? Border.all(color: Colors.grey.shade300) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCancelled
                  ? Icons.block_rounded
                  : isIncome
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isCancelled ? Colors.grey : null,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$accountName • '
                  '${DateFormat('dd MMM yyyy', 'id_ID').format(transaction.transactionDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (isCancelled) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Dibatalkan',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isBalanceVisible
                ? '${isIncome ? '+' : '-'}'
                      '${CurrencyFormatter.format(transaction.amount)}'
                : '${isIncome ? '+' : '-'} Rp ***',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              decoration: isCancelled ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final num amount;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final bool isVisible;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    this.isLoading = false,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          if (isLoading)
            const SizedBox(
              height: 22,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Text(
              isVisible ? CurrencyFormatter.format(amount) : 'Rp ***',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
