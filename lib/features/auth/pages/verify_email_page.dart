
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../repositories/auth_repository.dart';

class VerifyEmailPage extends StatefulWidget {
  final String email;

  const VerifyEmailPage({
    super.key,
    required this.email,
  });

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _repository = AuthRepository();
  final _tokenController = TextEditingController();

  bool _loading = false;
  bool _resending = false;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final token = _tokenController.text.trim();

    if (token.length != 6) {
      _showMessage('Masukkan kode OTP 6 digit.');
      return;
    }

    setState(() => _loading = true);

    try {
      await _repository.verifySignupOtp(
        email: widget.email,
        token: token,
      );

      if (!mounted) return;

      _showMessage('Email berhasil diverifikasi.');

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Verifikasi gagal: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);

    try {
      await _repository.resendSignupOtp(email: widget.email);

      if (!mounted) return;
      _showMessage('Kode OTP baru telah dikirim.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Gagal mengirim ulang OTP: $e');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi Email')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 72,
                  color: Colors.blue,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Periksa Email Anda',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kami telah mengirimkan kode verifikasi ke ${widget.email}.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _tokenController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Kode OTP',
                    hintText: '000000',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _verify,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Verifikasi Email'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _resending ? null : _resend,
                  child: _resending
                      ? const CircularProgressIndicator()
                      : const Text('Kirim Ulang Kode OTP'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
