import 'package:fintrack/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../rekening/models/rekening_model.dart';
import '../../rekening/providers/rekening_provider.dart';
import '../../../core/providers/balance_visibility_provider.dart';
import '../models/transfer_model.dart';
import '../providers/transfer_provider.dart';
import 'transfer_form_page.dart';

class TransfersPage extends ConsumerWidget {
  const TransfersPage({super.key});

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy', 'id_ID').format(date);
  }

  String _accountName(String accountId, Map<String, AccountModel> accountMap) {
    return accountMap[accountId]?.name ?? 'Rekening tidak ditemukan';
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(transfersProvider);
    ref.invalidate(accountsProvider);

    await Future.wait([
      ref.read(transfersProvider.future),
      ref.read(accountsProvider.future),
    ]);
  }

  void _openTransferForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TransferFormPage()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfersAsync = ref.watch(transfersProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final isBalanceVisible = ref.watch(balanceVisibilityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transfer'),
        actions: [
          IconButton(
            onPressed: () => _refresh(ref),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Perbarui',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTransferForm(context),
        backgroundColor: const Color(0xff16a34a),
        foregroundColor: Colors.white,
        child: const Icon(Icons.swap_horiz_rounded),
      ),
      body: transfersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Gagal memuat riwayat transfer.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(transfersProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (transfers) {
          return accountsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat data rekening: $error',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (accounts) {
              final accountMap = {
                for (final account in accounts) account.id: account,
              };

              if (transfers.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () => _refresh(ref),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Icon(
                        Icons.swap_horiz_rounded,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Belum ada riwayat transfer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Transfer antar rekening akan muncul di sini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final sortedTransfers = [...transfers]
                ..sort((a, b) {
                  final dateComparison = b.transferDate.compareTo(
                    a.transferDate,
                  );

                  if (dateComparison != 0) {
                    return dateComparison;
                  }

                  return (b.createdAt ?? b.transferDate).compareTo(
                    a.createdAt ?? a.transferDate,
                  );
                });

              final totalTransfers = sortedTransfers.length;

              return RefreshIndicator(
                onRefresh: () => _refresh(ref),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    _buildSummaryCard(totalTransfers),
                    const SizedBox(height: 24),

                    const Text(
                      'Semua Transfer',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...sortedTransfers.map((transfer) {
                      return _buildTransferCard(
                        context,
                        transfer,
                        accountMap,
                        isBalanceVisible,
                      );
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(int totalTransfers) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade700,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 30),
          const SizedBox(height: 12),
          const Text(
            'Total Aktivitas Transfer',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '$totalTransfers Transfer',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferCard(
    BuildContext context,
    TransferModel transfer,
    Map<String, AccountModel> accountMap,
    bool isBalanceVisible,
  ) {
    final theme = Theme.of(context);

    final fromAccount = _accountName(transfer.fromAccountId, accountMap);

    final toAccount = _accountName(transfer.toAccountId, accountMap);

    final amount = isBalanceVisible
        ? CurrencyFormatter.format(transfer.amount)
        : 'Rp ***';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transfer Antar Rekening',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatDate(transfer.transferDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  amount,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 10),
                const SizedBox(
                  width: 55,
                  child: Text('Dari', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(
                  child: Text(
                    fromAccount,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(
                  Icons.account_balance_outlined,
                  size: 18,
                  color: Colors.green,
                ),
                const SizedBox(width: 10),
                const SizedBox(
                  width: 55,
                  child: Text('Ke', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(
                  child: Text(
                    toAccount,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),

            if (transfer.description != null &&
                transfer.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_rounded, size: 18, color: Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      transfer.description!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
