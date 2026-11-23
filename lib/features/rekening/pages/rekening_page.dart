import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '../models/rekening_model.dart';
import '../providers/rekening_provider.dart';
import '../../../core/providers/balance_visibility_provider.dart';
import 'rekening_form_page.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  String _accountTypeName(String type) {
    switch (type) {
      case 'bank':
        return 'Bank';
      case 'ewallet':
        return 'E-Wallet';
      case 'cash':
        return 'Uang Tunai';
      default:
        return 'Lainnya';
    }
  }

  IconData _accountIcon(String type) {
    switch (type) {
      case 'bank':
        return Icons.account_balance_outlined;
      case 'ewallet':
        return Icons.wallet_outlined;
      case 'cash':
        return Icons.payments_outlined;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }

  Color _accountColor(String type) {
    switch (type) {
      case 'bank':
        return const Color(0xFF2563EB);
      case 'ewallet':
        return const Color(0xFF059669);
      case 'cash':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF7C3AED);
    }
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    AccountModel? account,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AccountFormPage(account: account)),
    );

    ref.invalidate(accountsProvider);
  }

  Future<void> _copyAccountNumber(
    BuildContext context,
    String accountNumber,
  ) async {
    if (accountNumber.trim().isEmpty) return;

    await Clipboard.setData(ClipboardData(text: accountNumber));

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Nomor berhasil disalin.'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
  }

  Future<void> _changeAccountStatus(
    BuildContext context,
    WidgetRef ref,
    AccountModel account,
    bool isActive,
  ) async {
    try {
      final repository = ref.read(accountRepositoryProvider);

      if (isActive) {
        await repository.activateAccount(account.id);
      } else {
        await repository.deactivateAccount(account.id);
      }

      ref.invalidate(accountsProvider);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isActive
                ? 'Rekening ${account.name} berhasil diaktifkan.'
                : 'Rekening ${account.name} berhasil dinonaktifkan.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah status Rekening: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final totalAsync = ref.watch(totalBalanceProvider);
    final isBalanceVisible = ref.watch(balanceVisibilityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rekening Keuangan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context, ref),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountsProvider);
          await ref.read(accountsProvider.future);
        },
        child: accountsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 100),
              const Icon(
                Icons.cloud_off_outlined,
                size: 56,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Gagal memuat Rekening',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 20),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => ref.invalidate(accountsProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                ),
              ),
            ],
          ),
          data: (accounts) {
            final activeCount = accounts
                .where((account) => account.isActive)
                .length;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                _buildBalanceCard(totalAsync, isBalanceVisible),

                const SizedBox(height: 28),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Daftar Rekening',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$activeCount/${accounts.length} rekening aktif',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                if (accounts.isEmpty)
                  _buildEmptyState(context, ref)
                else
                  ...accounts.map(
                    (account) => _buildAccountCard(
                      context,
                      ref,
                      account,
                      isBalanceVisible,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBalanceCard(
    AsyncValue<double> totalAsync,
    bool isBalanceVisible,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
                'Total Saldo Aktif',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),
          totalAsync.when(
            loading: () => const SizedBox(
              height: 36,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
            error: (_, _) => const Text(
              'Tidak tersedia',
              style: TextStyle(color: Colors.white),
            ),
            data: (total) => Text(
              isBalanceVisible ? _formatCurrency(total) : 'Rp ******',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Akumulasi saldo seluruh Rekening aktif',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    WidgetRef ref,
    AccountModel account,
    bool isBalanceVisible,
  ) {
    final color = _accountColor(account.accountType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant
              .withValues(alpha: 0.6),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openForm(context, ref, account: account),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_accountIcon(account.accountType), color: color),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      [
                        _accountTypeName(account.accountType),
                        if (account.bankName != null &&
                            account.bankName!.isNotEmpty)
                          account.bankName!,
                      ].join(' • '),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),

                    // Nomor rekening / E-Wallet
                    // Tekan dan tahan untuk menyalin.
                    if ((account.accountType == 'bank' ||
                            account.accountType == 'ewallet') &&
                        account.accountNumber != null &&
                        account.accountNumber!.trim().isNotEmpty) ...[
                      const SizedBox(height: 7),

                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPress: () {
                          _copyAccountNumber(context, account.accountNumber!);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 3,
                            horizontal: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.numbers_outlined,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  account.accountNumber!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.copy_outlined,
                                size: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    Text(
                      isBalanceVisible
                          ? _formatCurrency(account.currentBalance)
                          : 'Rp ***',
                      style: TextStyle(
                        color: account.isActive
                            ? color
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      account.isActive ? 'Aktif' : 'Nonaktif',
                      style: TextStyle(
                        color: account.isActive
                            ? const Color(0xFF059669)
                            : Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch.adaptive(
                    value: account.isActive,
                    activeTrackColor: const Color(0xFF059669),
                    onChanged: (value) {
                      _changeAccountStatus(context, ref, account, value);
                    },
                  ),
                  Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 54,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum Ada Rekening',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambahkan rekening bank, e-wallet, atau uang tunai untuk mulai mencatat keuangan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _openForm(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Rekening Pertama'),
          ),
        ],
      ),
    );
  }
}
