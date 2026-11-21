import 'package:fintrack/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../accounts/providers/account_provider.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';

class TransactionFormPage extends ConsumerStatefulWidget {
  final TransactionModel? transaction;

  const TransactionFormPage({super.key, this.transaction});

  @override
  ConsumerState<TransactionFormPage> createState() =>
      _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _type = 'expense';
  String? _accountId;
  String? _categoryId;
  DateTime _transactionDate = DateTime.now();
  bool _isSaving = false;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;

    if (transaction != null) {
      _type = transaction.type;
      _accountId = transaction.accountId;
      _categoryId = transaction.categoryId;
      _transactionDate = transaction.transactionDate;
      _amountController.text = NumberFormat(
        '#,##0',
        'id_ID',
      ).format(transaction.amount);
      _descriptionController.text = transaction.description ?? '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Pilih tanggal transaksi',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );

    if (selectedDate != null) {
      setState(() {
        _transactionDate = selectedDate;
      });
    }
  }

  double? _parseAmount(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.isEmpty) return null;

    return double.tryParse(cleaned);
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = _parseAmount(_amountController.text);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal transaksi harus lebih dari nol.'),
        ),
      );
      return;
    }

    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih akun terlebih dahulu.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repository = ref.read(transactionRepositoryProvider);

      if (_isEditing) {
        await repository.updateTransaction(
          id: widget.transaction!.id,
          accountId: _accountId!,
          type: _type,
          amount: amount,
          categoryId: _categoryId,
          description: _descriptionController.text,
          transactionDate: _transactionDate,
        );
      } else {
        await repository.createTransaction(
          accountId: _accountId!,
          type: _type,
          amount: amount,
          categoryId: _categoryId,
          description: _descriptionController.text,
          transactionDate: _transactionDate,
        );
      }

      ref.invalidate(transactionsProvider);
      ref.invalidate(accountsProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Transaksi berhasil diperbarui.'
                : 'Transaksi berhasil ditambahkan.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan transaksi: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final incomeCategoriesAsync = ref.watch(incomeCategoriesProvider);
    final expenseCategoriesAsync = ref.watch(expenseCategoriesProvider);

    final categoriesAsync = _type == 'income'
        ? incomeCategoriesAsync
        : expenseCategoriesAsync;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Transaksi' : 'Tambah Transaksi',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Gagal memuat akun: $error'),
          ),
        ),
        data: (allAccounts) {
          final accounts = allAccounts
              .where(
                (account) =>
                    account.isActive ||
                    account.id == widget.transaction?.accountId,
              )
              .toList();

          if (accounts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 56,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Belum ada akun aktif',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tambahkan akun terlebih dahulu sebelum mencatat transaksi.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Kembali'),
                    ),
                  ],
                ),
              ),
            );
          }

          final selectedAccountId =
              accounts.any((account) => account.id == _accountId)
              ? _accountId
              : accounts.first.id;

          final categories = categoriesAsync.asData?.value ?? <CategoryModel>[];

          final selectedCategoryId =
              categories.any((category) => category.id == _categoryId)
              ? _categoryId
              : null;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Jenis Transaksi',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          selected: _type == 'expense',
                          onSelected: (_) {
                            setState(() {
                              _type = 'expense';
                              _categoryId = null;
                            });
                          },
                          showCheckmark: false,
                          avatar: Icon(
                            Icons.trending_down_rounded,
                            size: 18,
                            color: _type == 'expense'
                                ? Colors.white
                                : Colors.red,
                          ),
                          label: const Text('Pengeluaran'),
                          labelStyle: TextStyle(
                            color: _type == 'expense'
                                ? Colors.white
                                : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: Colors.red.withValues(alpha: 0.08),
                          selectedColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: _type == 'expense'
                                ? Colors.red
                                : Colors.red.shade100,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          selected: _type == 'income',
                          onSelected: (_) {
                            setState(() {
                              _type = 'income';
                              _categoryId = null;
                            });
                          },
                          showCheckmark: false,
                          avatar: Icon(
                            Icons.trending_up_rounded,
                            size: 18,
                            color: _type == 'income'
                                ? Colors.white
                                : Colors.green,
                          ),
                          label: const Text('Pemasukan'),
                          labelStyle: TextStyle(
                            color: _type == 'income'
                                ? Colors.white
                                : Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: Colors.green.withValues(alpha: 0.08),
                          selectedColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: _type == 'income'
                                ? Colors.green
                                : Colors.green.shade100,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Nominal Transaksi',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyFormatter.inputFormatter()],
                  decoration: const InputDecoration(
                    prefixText: 'Rp ',
                    hintText: '0',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nominal wajib diisi.';
                    }

                    final amount = _parseAmount(value);

                    if (amount == null || amount <= 0) {
                      return 'Masukkan nominal lebih dari nol.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 20),

                const Text(
                  'Pilih Akun',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedAccountId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: accounts.map((account) {
                    return DropdownMenuItem(
                      value: account.id,
                      child: Text(
                        '${account.name} ${account.bankName ?? ""} ${CurrencyFormatter.format(account.currentBalance)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _accountId = value);
                  },
                ),
                const SizedBox(height: 20),

                const Text(
                  'Kategori',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                categoriesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stack) => Text(
                    'Gagal memuat kategori: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                  data: (categoryList) {
                    return DropdownButtonFormField<String>(
                      initialValue: selectedCategoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      hint: const Text('Pilih kategori (opsional)'),
                      items: categoryList.map((category) {
                        return DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _categoryId = value);
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),

                const Text(
                  'Tanggal Transaksi',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    child: Text(
                      DateFormat(
                        'EEEE, dd MMMM yyyy',
                        'id_ID',
                      ).format(_transactionDate),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Catatan',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  maxLength: 250,
                  decoration: const InputDecoration(
                    hintText: 'Contoh: Belanja kebutuhan bulanan',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveTransaction,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _isSaving
                          ? 'Menyimpan...'
                          : _isEditing
                          ? 'Simpan Perubahan'
                          : 'Simpan Transaksi',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
