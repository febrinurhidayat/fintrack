import 'package:fintrack/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../features/accounts/models/account_model.dart';
import '../../../features/accounts/providers/account_provider.dart';
import '../providers/transfer_provider.dart';

class TransferFormPage extends ConsumerStatefulWidget {
  const TransferFormPage({super.key});

  @override
  ConsumerState<TransferFormPage> createState() => _TransferFormPageState();
}

class _TransferFormPageState extends ConsumerState<TransferFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _fromAccountId;
  String? _toAccountId;
  DateTime _transferDate = DateTime.now();

  bool _isSubmitting = false;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _accountTypeLabel(String type) {
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

  String _accountLabel(AccountModel account) {
    final type = _accountTypeLabel(account.accountType);
    final bank = account.bankName;

    if (bank != null && bank.isNotEmpty) {
      return '${account.name} ($bank)';
    }

    return '${account.name} ($type)';
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _transferDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('id', 'ID'),
    );

    if (selectedDate != null) {
      setState(() {
        _transferDate = selectedDate;
      });
    }
  }

  Future<void> _submitTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromAccountId == null || _toAccountId == null) return;

    final amount = double.tryParse(
      _amountController.text.replaceAll('.', '').replaceAll(',', '.'),
    );

    if (amount == null || amount <= 0) {
      _showMessage('Nominal transfer tidak valid.');
      return;
    }

    final accounts = ref.read(activeAccountsProvider).asData?.value;

    final sourceAccount = accounts?.firstWhere(
      (account) => account.id == _fromAccountId,
    );

    if (sourceAccount == null) {
      _showMessage('Rekening sumber tidak ditemukan.');
      return;
    }

    if (amount > sourceAccount.currentBalance) {
      _showMessage('Saldo rekening sumber tidak mencukupi.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(transferRepositoryProvider)
          .createTransfer(
            fromAccountId: _fromAccountId!,
            toAccountId: _toAccountId!,
            amount: amount,
            description: _descriptionController.text.trim(),
            transferDate: _transferDate,
          );

      ref.invalidate(transfersProvider);
      ref.invalidate(accountsProvider);

      if (!mounted) return;

      _showMessage('Transfer berhasil disimpan.');

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(activeAccountsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer Antar Rekening')),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Gagal memuat rekening: $error'),
          ),
        ),
        data: (accounts) {
          if (accounts.length < 2) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Transfer membutuhkan minimal dua rekening aktif.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.swap_horiz_rounded,
                          size: 32,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Pindahkan saldo antar rekening milik Anda.',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Rekening Sumber',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    initialValue: _fromAccountId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      border: OutlineInputBorder(),
                      hintText: 'Pilih rekening sumber',
                    ),
                    items: accounts.map((account) {
                      return DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          _accountLabel(account),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _fromAccountId = value;

                        if (_toAccountId == value) {
                          _toAccountId = null;
                        }
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Pilih rekening sumber.' : null,
                  ),

                  if (_fromAccountId != null) ...[
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final account = accounts.firstWhere(
                          (item) => item.id == _fromAccountId,
                        );

                        return Text(
                          'Saldo tersedia: ${_currencyFormat.format(account.currentBalance)}',
                          style: theme.textTheme.bodySmall,
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 20),

                  const Text(
                    'Rekening Tujuan',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    initialValue: _toAccountId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.account_balance_outlined),
                      border: OutlineInputBorder(),
                      hintText: 'Pilih rekening tujuan',
                    ),
                    items: accounts
                        .where((account) => account.id != _fromAccountId)
                        .map((account) {
                          return DropdownMenuItem(
                            value: account.id,
                            child: Text(
                              _accountLabel(account),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        })
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _toAccountId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Pilih rekening tujuan.';
                      }
                      if (value == _fromAccountId) {
                        return 'Rekening tujuan harus berbeda.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Nominal Transfer',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      CurrencyFormatter.inputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      prefixText: 'Rp ',
                      hintText: 'Masukkan nominal transfer',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nominal transfer wajib diisi.';
                      }

                      final amount = double.tryParse(
                        value.replaceAll('.', '').replaceAll(',', '.'),
                      );

                      if (amount == null || amount <= 0) {
                        return 'Masukkan nominal yang valid.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Tanggal Transfer',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  InkWell(
                    onTap: _selectDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        DateFormat(
                          'dd MMMM yyyy',
                          'id_ID',
                        ).format(_transferDate),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Catatan (Opsional)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: Transfer dari BCA ke Dompet',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitTransfer,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.swap_horiz_rounded),
                      label: Text(
                        _isSubmitting ? 'Menyimpan...' : 'Simpan Transfer',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
