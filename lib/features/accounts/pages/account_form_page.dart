
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_model.dart';
import '../providers/account_provider.dart';

class AccountFormPage extends ConsumerStatefulWidget {
  final AccountModel? account;

  const AccountFormPage({super.key, this.account});

  @override
  ConsumerState<AccountFormPage> createState() =>
      _AccountFormPageState();
}

class _AccountFormPageState extends ConsumerState<AccountFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _bankController;
  late final TextEditingController _numberController;
  late final TextEditingController _balanceController;

  late String _accountType;

  bool _loading = false;
  bool _deleting = false;

  bool get _isEditing => widget.account != null;
  bool get _isBank => _accountType == 'bank';
  bool get _isEwallet => _accountType == 'ewallet';

  final _currencyFormat = NumberFormat('#,##0', 'id_ID');

  @override
  void initState() {
    super.initState();

    final account = widget.account;

    _nameController = TextEditingController(
      text: account?.name ?? '',
    );

    _bankController = TextEditingController(
      text: account?.bankName ?? '',
    );

    _numberController = TextEditingController(
      text: account?.accountNumber ?? '',
    );

    _balanceController = TextEditingController(
      text: account == null
          ? '0'
          : _currencyFormat.format(account.initialBalance),
    );

    _accountType = account?.accountType ?? 'bank';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankController.dispose();
    _numberController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  double _parseBalance(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.isEmpty) return 0;

    return double.parse(cleaned);
  }

  void _formatBalanceInput(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      _balanceController.value = const TextEditingValue(
        text: '0',
        selection: TextSelection.collapsed(offset: 1),
      );
      return;
    }

    final formatted = _currencyFormat.format(int.parse(digits));

    _balanceController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: formatted.length,
      ),
    );
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final repository = ref.read(accountRepositoryProvider);

      final name = _nameController.text.trim();
      final bankName = _isBank
          ? _bankController.text.trim()
          : null;
      final accountNumber =
          (_isBank || _isEwallet)
              ? _numberController.text.trim()
              : null;

      final balance = _parseBalance(_balanceController.text);

      if (_isEditing) {
        await repository.updateAccount(
          id: widget.account!.id,
          name: name,
          accountType: _accountType,
          bankName: bankName,
          accountNumber: accountNumber,
          initialBalance: balance,
        );
      } else {
        await repository.createAccount(
          name: name,
          accountType: _accountType,
          bankName: bankName,
          accountNumber: accountNumber,
          initialBalance: balance,
        );
      }

      ref.invalidate(accountsProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Akun berhasil diperbarui.'
                : 'Akun berhasil ditambahkan.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan akun: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    if (!_isEditing || _deleting || _loading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.delete_forever_outlined,
            color: Colors.red,
            size: 36,
          ),
          title: const Text('Hapus Akun?'),
          content: Text(
            'Apakah Anda yakin ingin menghapus akun '
            '"${widget.account!.name}" secara permanen?\n\n'
            'Akun yang sudah memiliki riwayat transaksi atau '
            'transfer tidak dapat dihapus.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Ya, Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);

    try {
      final repository = ref.read(accountRepositoryProvider);

      await repository.deleteAccount(widget.account!.id);

      ref.invalidate(accountsProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun berhasil dihapus secara permanen.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      final message = e is PostgrestException
          ? e.message
          : e.toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus akun: $message'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  InputDecoration _decoration(
    String label,
    IconData icon, {
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.grey.withValues(alpha: 0.25),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF2563EB),
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _loading || _deleting;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Akun' : 'Tambah Akun'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Color(0xFF2563EB),
                      size: 30,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Informasi Akun',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Masukkan informasi akun keuangan Anda.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              const Text(
                'Jenis Akun',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                initialValue: _accountType,
                decoration: _decoration(
                  'Pilih jenis akun',
                  Icons.category_outlined,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'bank',
                    child: Text('Bank'),
                  ),
                  DropdownMenuItem(
                    value: 'ewallet',
                    child: Text('E-Wallet'),
                  ),
                  DropdownMenuItem(
                    value: 'cash',
                    child: Text('Uang Tunai'),
                  ),
                  DropdownMenuItem(
                    value: 'other',
                    child: Text('Lainnya'),
                  ),
                ],
                onChanged: isBusy
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _accountType = value);
                        }
                      },
              ),

              const SizedBox(height: 20),

              // Semua jenis akun memiliki nama akun.
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                enabled: !isBusy,
                decoration: _decoration(
                  'Nama Akun',
                  Icons.wallet_outlined,
                  hint: 'Contoh: BCA Utama, Dompet Pribadi',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama akun wajib diisi.';
                  }

                  return null;
                },
              ),

              // Khusus akun bank.
              if (_isBank) ...[
                const SizedBox(height: 20),

                TextFormField(
                  controller: _bankController,
                  textCapitalization: TextCapitalization.words,
                  enabled: !isBusy,
                  decoration: _decoration(
                    'Nama Bank',
                    Icons.account_balance_outlined,
                    hint: 'Contoh: BCA, BRI, Mandiri',
                  ),
                ),
              ],

              // Bank dan E-Wallet menggunakan nomor akun.
              if (_isBank || _isEwallet) ...[
                const SizedBox(height: 20),

                TextFormField(
                  controller: _numberController,
                  keyboardType: TextInputType.number,
                  enabled: !isBusy,
                  decoration: _decoration(
                    _isBank ? 'Nomor Rekening' : 'Nomor E-Wallet',
                    Icons.numbers_outlined,
                    hint: _isBank
                        ? 'Masukkan nomor rekening'
                        : 'Masukkan nomor HP atau akun E-Wallet',
                  ),
                ),
              ],

              const SizedBox(height: 26),

              const Text(
                'Saldo Awal',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _balanceController,
                keyboardType: TextInputType.number,
                enabled: !isBusy,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9.]'),
                  ),
                ],
                onChanged: _formatBalanceInput,
                decoration: _decoration(
                  'Saldo awal',
                  Icons.payments_outlined,
                  hint: '0',
                ).copyWith(prefixText: 'Rp '),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Saldo awal wajib diisi.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 8),

              Text(
                'Masukkan saldo yang tersedia ketika akun ini '
                'mulai dicatat di FinTrack.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: isBusy ? null : _saveAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing
                              ? 'Simpan Perubahan'
                              : 'Simpan Akun',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              if (_isEditing) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : _deleteAccount,
                    icon: _deleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.red,
                            ),
                          )
                        : const Icon(Icons.delete_outline),
                    label: Text(
                      _deleting
                          ? 'Menghapus Akun...'
                          : 'Hapus Akun',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Akun yang sudah memiliki riwayat transaksi '
                  'atau transfer tidak dapat dihapus permanen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
