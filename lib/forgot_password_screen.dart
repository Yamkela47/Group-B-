import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_bars.dart';
import 'buttons.dart';
import 'inputs.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;

  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _message(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      await _supabase.auth.resetPasswordForEmail(
        _email.text.trim(),
      );

      if (!mounted) return;

      _message(
        'Reset link sent! Check ${_email.text.trim()} for instructions.',
        color: AppColors.success,
      );

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pop(context);
    } on AuthException catch (e) {
      _message(e.message, color: AppColors.error);
    } catch (e) {
      _message(
        'Something went wrong. Please try again.',
        color: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Forgot Password'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No worries! Enter your email address below and we will send you a link to reset your password.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 26),

                AppTextField(
                  label: 'Email',
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline,
                  controller: _email,
                  enabled: !_loading,
                ),

                const SizedBox(height: 22),

                _loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.gold,
                          ),
                        ),
                      )
                    : GoldButton(
                        label: 'Send Reset Link',
                        icon: Icons.arrow_forward,
                        onPressed: _sendResetLink,
                      ),

                const SizedBox(height: 16),
                GhostButton(
                  label: 'Back to Login',
                  onPressed: _loading ? null : () => Navigator.pop(context),
                ),
                const SizedBox(height: 26),
                const Center(
                  child: Text(
                    'Need help? Contact your salon admin',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}