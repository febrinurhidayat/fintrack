
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../repositories/auth_repository.dart';
import 'reset_password_page.dart';

class VerifyRecoveryPage extends StatefulWidget {
  final String email;

  const VerifyRecoveryPage({
    super.key,
    required this.email,
  });

  @override
  State<VerifyRecoveryPage> createState() => _VerifyRecoveryPageState();
}

class _VerifyRecoveryPageState extends State<VerifyRecoveryPage> {
  final _repository = AuthRepository();
  final _tokenController = TextEditingController();

  bool _loading = false;

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
      await _repository.verifyRecoveryOtp(
        email: widget.email,
        token: token,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ResetPasswordPage(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('OTP tidak valid atau sudah kedaluwarsa: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
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
      appBar: AppBar(title: const Text('Verifikasi Reset Password')),
      body: SafeArea(
        child: Padding(
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
                'Masukkan Kode OTP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Kode reset password telah dikirim ke ${widget.email}.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
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
                    : const Text('Verifikasi OTP'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
