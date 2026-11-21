import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../transactions/models/transaction_model.dart';
import '../../transactions/providers/transaction_provider.dart';

// Pastikan provider kategori (incomeCategoriesProvider & expenseCategoriesProvider) ter-import di sini

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  DateTime _selectedMonth = DateTime.now();

  Future<void> _selectMonth() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Pilih tanggal pada bulan laporan',
    );

    if (selected != null) {
      setState(() {
        _selectedMonth = DateTime(selected.year, selected.month);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(reportTransactionsProvider(_selectedMonth));

    final incomeCategoriesAsync = ref.watch(incomeCategoriesProvider);
    final expenseCategoriesAsync = ref.watch(expenseCategoriesProvider);

    final categoryNames = <String, String>{
      for (final category in incomeCategoriesAsync.asData?.value ?? [])
        category.id: category.name,
      for (final category in expenseCategoriesAsync.asData?.value ?? [])
        category.id: category.name,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Laporan Keuangan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 44),
                const SizedBox(height: 12),
                const Text('Gagal memuat laporan'),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
                TextButton(
                  onPressed: () {
                    ref.invalidate(reportTransactionsProvider(_selectedMonth));
                  },
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (transactions) {
          return _buildReport(transactions, categoryNames);
        },
      ),
    );
  }

  Widget _buildReport(
    List<TransactionModel> transactions,
    Map<String, String> categoryNames,
  ) {
    final incomeTransactions = transactions
        .where((item) => item.isIncome)
        .toList();

    final expenseTransactions = transactions
        .where((item) => item.isExpense)
        .toList();

    final totalIncome = incomeTransactions.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    final totalExpense = expenseTransactions.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    final difference = totalIncome - totalExpense;

    // 1. Hitung total pemasukan per kategori
    final incomeCategoryTotals = <String, double>{};
    for (final transaction in incomeTransactions) {
      final category = transaction.categoryId ?? 'uncategorized';
      incomeCategoryTotals[category] =
          (incomeCategoryTotals[category] ?? 0) + transaction.amount;
    }
    final sortedIncomeCategories = incomeCategoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Hitung total pengeluaran per kategori
    final expenseCategoryTotals = <String, double>{};
    for (final transaction in expenseTransactions) {
      final category = transaction.categoryId ?? 'uncategorized';
      expenseCategoryTotals[category] =
          (expenseCategoryTotals[category] ?? 0) + transaction.amount;
    }
    final sortedExpenseCategories = expenseCategoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(reportTransactionsProvider(_selectedMonth));

        await ref.read(reportTransactionsProvider(_selectedMonth).future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMonthSelector(),
            const SizedBox(height: 20),

            _buildBalanceCard(difference),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Pemasukan',
                    amount: totalIncome,
                    icon: Icons.trending_up_rounded,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Pengeluaran',
                    amount: totalExpense,
                    icon: Icons.trending_down_rounded,
                    color: Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            _sectionTitle('Perbandingan Keuangan'),
            const SizedBox(height: 14),
            _buildComparisonChart(totalIncome, totalExpense),

            const SizedBox(height: 28),

            // 2. Section Pemasukan per Kategori
            _sectionTitle('Pemasukan per Kategori'),
            const SizedBox(height: 14),

            if (sortedIncomeCategories.isEmpty)
              _emptyMessage('Belum ada pemasukan pada bulan ini.')
            else
              _buildCategoryList(
                sortedIncomeCategories,
                totalIncome,
                categoryNames,
                Colors.green,
              ),

            const SizedBox(height: 28),

            // Section Pengeluaran per Kategori
            _sectionTitle('Pengeluaran per Kategori'),
            const SizedBox(height: 14),

            if (sortedExpenseCategories.isEmpty)
              _emptyMessage('Belum ada pengeluaran pada bulan ini.')
            else
              _buildCategoryList(
                sortedExpenseCategories,
                totalExpense,
                categoryNames,
                Colors.red,
              ),

            const SizedBox(height: 28),

            _sectionTitle('Rincian Transaksi'),
            const SizedBox(height: 12),

            if (transactions.isEmpty)
              _emptyMessage('Belum ada transaksi pada bulan ini.')
            else
              ...transactions.map(
                (transaction) =>
                    _buildTransactionTile(transaction, categoryNames),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return InkWell(
      onTap: _selectMonth,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, color: AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(double difference) {
    final isPositive = difference >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selisih Keuangan',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Text(
            '${isPositive ? '+' : '-'}'
            '${CurrencyFormatter.format(difference.abs())}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isPositive
                ? 'Pemasukan lebih besar dari pengeluaran'
                : 'Pengeluaran lebih besar dari pemasukan',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.format(amount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonChart(double income, double expense) {
    final maxValue = [income, expense].reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: BarChart(
              BarChartData(
                maxY: maxValue == 0 ? 100 : maxValue * 1.2,
                minY: 0,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final label = value.toInt() == 0
                            ? 'Pemasukan'
                            : value.toInt() == 1
                            ? 'Pengeluaran'
                            : '';

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            label,
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  _barGroup(0, income, Colors.green),
                  _barGroup(1, expense, Colors.red),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: Colors.green, label: 'Pemasukan'),
              SizedBox(width: 20),
              _LegendDot(color: Colors.red, label: 'Pengeluaran'),
            ],
          ),
        ],
      ),
    );
  }

  BarChartGroupData _barGroup(int x, double value, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          color: color,
          width: 38,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }

  // 3. Tambahkan parameter Color barColor
  Widget _buildCategoryList(
    List<MapEntry<String, double>> categories,
    double totalAmount,
    Map<String, String> categoryNames,
    Color barColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: categories.map((entry) {
          final percentage = totalAmount > 0 ? entry.value / totalAmount : 0.0;

          final categoryName = entry.key == 'uncategorized'
              ? 'Tanpa Kategori'
              : (categoryNames[entry.key] ?? 'Kategori tidak ditemukan');

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        categoryName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(entry.value),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade100,
                    color: barColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(percentage * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

Widget _buildTransactionTile(
  TransactionModel transaction,
  Map<String, String> categoryNames,
) {
  final isIncome = transaction.isIncome;
  final color = isIncome ? Colors.green : Colors.red;

  final categoryName = transaction.categoryId == null
      ? 'Tanpa Kategori'
      : categoryNames[transaction.categoryId] ??
          'Kategori tidak ditemukan';

  return Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(
          isIncome
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
          color: color,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.description?.trim().isNotEmpty == true
                    ? transaction.description!.trim()
                    : isIncome
                        ? 'Pemasukan'
                        : 'Pengeluaran',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                categoryName,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd MMM yyyy', 'id_ID')
                    .format(transaction.transactionDate),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${isIncome ? '+' : '-'}'
          '${CurrencyFormatter.format(transaction.amount)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
    );
  }

  Widget _emptyMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
