import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../accounts/providers/account_provider.dart';
import '../providers/statement_provider.dart';

class StatementSection extends ConsumerStatefulWidget {
  const StatementSection({super.key});

  @override
  ConsumerState<StatementSection> createState() => _StatementSectionState();
}

class _StatementSectionState extends ConsumerState<StatementSection> {
  String? _selectedAccountId;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);

  DateTime _endDate = DateTime.now();

  Future<void> _selectStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Pilih tanggal awal',
    );

    if (selected != null) {
      setState(() {
        _startDate = selected;
        if (_endDate.isBefore(_startDate)) {
          _endDate = selected;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
      helpText: 'Pilih tanggal akhir',
    );

    if (selected != null) {
      setState(() => _endDate = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(activeAccountsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'E-Statement',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Lihat mutasi dan saldo rekening berdasarkan periode.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),
        accountsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stackTrace) =>
              _errorCard('Gagal memuat rekening: $error'),
          data: (accounts) {
            if (accounts.isEmpty) {
              return _emptyCard('Belum ada rekening aktif.');
            }

            final selectedId =
                accounts.any((account) => account.id == _selectedAccountId)
                ? _selectedAccountId!
                : accounts.first.id;

            final filter = StatementFilter(
              accountId: selectedId,
              startDate: _startDate,
              endDate: _endDate,
            );

            final statementAsync = ref.watch(accountStatementProvider(filter));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterCard(accounts, selectedId),
                const SizedBox(height: 16),
                statementAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, stackTrace) => _errorCard(
                    'Gagal memuat E-Statement: $error',
                    onRetry: () {
                      ref.invalidate(accountStatementProvider(filter));
                    },
                  ),
                  data: (statement) => _buildStatement(statement),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildFilterCard(List<dynamic> accounts, String selectedId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Rekening',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: selectedId,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            items: accounts.map((account) {
              return DropdownMenuItem<String>(
                value: account.id as String,
                child: Text(
                  account.name as String,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedAccountId = value);
              }
            },
          ),
          const SizedBox(height: 18),
          const Text(
            'Periode Mutasi',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _dateButton(
                  label: 'Dari',
                  date: _startDate,
                  onTap: _selectStartDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dateButton(
                  label: 'Sampai',
                  date: _endDate,
                  onTap: _selectEndDate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateButton({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    DateFormat('dd MMM yyyy', 'id_ID').format(date),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatement(AccountStatement statement) {
    final entries = <_StatementEntry>[];

    for (final transaction in statement.transactions) {
      entries.add(
        _StatementEntry(
          date: transaction.transactionDate,
          title: transaction.description?.trim().isNotEmpty == true
              ? transaction.description!.trim()
              : transaction.isIncome
              ? 'Pemasukan'
              : 'Pengeluaran',
          subtitle: transaction.isIncome ? 'Pemasukan' : 'Pengeluaran',
          amount: transaction.amount,
          isIncoming: transaction.isIncome,
          icon: transaction.isIncome
              ? Icons.arrow_downward_rounded
              : Icons.arrow_upward_rounded,
        ),
      );
    }

    for (final transfer in statement.transfers) {
      final isIncoming = transfer.toAccountId == statement.account.id;

      entries.add(
        _StatementEntry(
          date: transfer.transferDate,
          title: transfer.description?.trim().isNotEmpty == true
              ? transfer.description!.trim()
              : isIncoming
              ? 'Transfer masuk'
              : 'Transfer keluar',
          subtitle: isIncoming ? 'Transfer masuk' : 'Transfer keluar',
          amount: transfer.amount,
          isIncoming: isIncoming,
          icon: Icons.swap_horiz_rounded,
          isTransfer: true,
        ),
      );
    }

    entries.sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBalanceCard(
          title: 'Saldo Akhir',
          amount: statement.closingBalance,
          highlighted: true,
        ),
        const SizedBox(height: 12),
        _buildBalanceCard(
          title: 'Saldo Awal',
          amount: statement.openingBalance,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Pemasukan',
                statement.totalIncome,
                Colors.green,
                Icons.trending_up_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                'Pengeluaran',
                statement.totalExpense,
                Colors.red,
                Icons.trending_down_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Transfer Masuk',
                statement.transferIn,
                Colors.blue,
                Icons.south_west_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                'Transfer Keluar',
                statement.transferOut,
                Colors.orange,
                Icons.north_east_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Riwayat Mutasi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${entries.length} aktivitas',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          _emptyCard('Tidak ada mutasi pada periode ini.')
        else
          ...entries.map(_buildEntryTile),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Periode ${DateFormat('dd MMM yyyy', 'id_ID').format(statement.startDate)}'
                  ' - ${DateFormat('dd MMM yyyy', 'id_ID').format(statement.endDate)}',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard({
    required String title,
    required double amount,
    bool highlighted = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: highlighted ? AppTheme.primary : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: highlighted ? null : Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: highlighted ? Colors.white70 : AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(
              color: highlighted ? Colors.white : AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 9),
          Text(
            title,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 5),
          Text(
            CurrencyFormatter.format(amount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryTile(_StatementEntry entry) {
    final color = entry.isTransfer
        ? Colors.blue
        : entry.isIncoming
        ? Colors.green
        : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(entry.icon, color: color, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.subtitle} • ${DateFormat('dd MMM yyyy', 'id_ID').format(entry.date)}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${entry.isIncoming ? '+' : '-'}${CurrencyFormatter.format(entry.amount)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
    );
  }

  Widget _errorCard(String message, {VoidCallback? onRetry}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

class _StatementEntry {
  final DateTime date;
  final String title;
  final String subtitle;
  final double amount;
  final bool isIncoming;
  final IconData icon;
  final bool isTransfer;

  const _StatementEntry({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isIncoming,
    required this.icon,
    this.isTransfer = false,
  });
}
