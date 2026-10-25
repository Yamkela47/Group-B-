import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_bars.dart';
import 'buttons.dart';
import 'email_service.dart'; 
import 'reset_password_screen.dart'; 

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
      final email = _email.text.trim();

      // 1. Generate a 6-digit reset code
      final resetCode = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();

      // 2. Send the email using hardcoded SMTP
      final emailSent = await EmailService.sendPasswordResetCode(email, resetCode);

      if (!mounted) return;

      if (emailSent) {
        _message('Reset code sent! Check $email.', color: AppColors.success);

        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;

        // 3. Redirect to the Reset Password Screen and PASS THE CODE
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(
              email: email, 
              expectedCode: resetCode,
            ),
          ),
        );
      } else {
        _message('Failed to send reset email. Check your console logs.', color: AppColors.error);
      }

    } catch (e) {
      _message(e.toString().replaceAll('Exception: ', ''), color: AppColors.error);
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
                  'No worries! Enter your email address below and we will send you a 6-digit code to reset your password.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 26),

                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_loading,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'you@example.com',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.mail_outline, color: AppColors.gold),
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.gold),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
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
                        label: 'Send Reset Code',
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