
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'app_bars.dart';
import 'buttons.dart';
import 'account_created_screen.dart';

class VerifyAccountScreen extends StatefulWidget {
  final String email;

  const VerifyAccountScreen({
    super.key,
    required this.email,
  });

  @override
  State<VerifyAccountScreen> createState() =>
      _VerifyAccountScreenState();
}

class _VerifyAccountScreenState
    extends State<VerifyAccountScreen> {
  final List<TextEditingController> _codes =
      List.generate(6, (_) => TextEditingController());

  bool _isVerifying = false;

  @override
  void dispose() {
    for (final controller in _codes) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final token = _codes.map((controller) => controller.text).join();

    if (token.length != 6 ||
        !RegExp(r'^\d{6}$').hasMatch(token)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the complete 6-digit code.'),
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email.trim(),
        token: token,
        type: OtpType.signup,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AccountCreatedScreen(),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verification failed. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendCode() async {
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new verification email has been requested.'),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not resend the email. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Verify Account'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.gold,
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  color: AppColors.gold,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Verify Your Account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a verification code to ${widget.email}. '
                'Enter it below to continue.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 46,
                    height: 56,
                    child: TextField(
                      controller: _codes[i],
                      maxLength: 1,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(1),
                      ],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 30),
              GoldButton(
                label: _isVerifying
                    ? 'Verifying...'
                    : 'Verify & Continue',
                onPressed: _isVerifying ? null : _verifyCode,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isVerifying ? null : _resendCode,
                child: const Text(
                  'Resend verification code',
                  style: TextStyle(color: AppColors.gold),
                ),
              ),
              GhostButton(
                label: 'Back to Login',
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 24),
              const Text(
                'Your account is protected',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
