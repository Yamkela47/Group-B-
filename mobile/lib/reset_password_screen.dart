/*
===========================================================
PROJECT: Cutting Edge Salon
STUDENT DETAILS:
-----------------------------------------------------------
Name                  | Student Number
-----------------------------------------------------------
Goitse Kgwele         | 221050663
Thabang Zitha         | 223007074
Yamkela Mazamani      | 224007421
Nyakallo Pali         | 223060226
Bennet Linda          | 224004294
===========================================================
*/

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_bars.dart';
import 'buttons.dart';
import 'login_screen.dart'; 

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String expectedCode; 

  const ResetPasswordScreen({
    super.key, 
    required this.email,
    required this.expectedCode,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final code = _codeController.text.trim();
      final newPassword = _passwordController.text;

      // 1. Check if the code matches the one we emailed
      if (code != widget.expectedCode) {
        throw Exception('Incorrect code. Please check your email.');
      }

      // 2. Call the database function to securely update the password
      final supabase = Supabase.instance.client;
      await supabase.rpc(
        'update_user_password',
        params: {
          'user_email': widget.email,
          'new_password': newPassword,
        },
      );

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successfully! Please log in.'), backgroundColor: AppColors.success),
      );

      // 3. Redirect to Login Screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Reset Password'),
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
                  'Set New Password',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit code sent to ${widget.email} and your new password.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 26),

                // Verification Code
                const Text('Verification Code', style: TextStyle(color: AppColors.gold, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('6-digit code', Icons.pin_outlined),
                  validator: (v) => v == null || v.length < 6 ? 'Enter the 6-digit code' : null,
                ),
                const SizedBox(height: 20),

                // New Password
                const Text('New Password', style: TextStyle(color: AppColors.gold, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _hidePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('At least 8 characters', Icons.lock_outline, suffix: IconButton(
                    icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.gold),
                    onPressed: () => setState(() => _hidePassword = !_hidePassword),
                  )),
                  validator: (v) => v == null || v.length < 8 ? 'Password must be at least 8 characters' : null,
                ),
                const SizedBox(height: 20),

                // Confirm Password
                const Text('Confirm Password', style: TextStyle(color: AppColors.gold, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _hideConfirmPassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Re-enter password', Icons.lock_outline, suffix: IconButton(
                    icon: Icon(_hideConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.gold),
                    onPressed: () => setState(() => _hideConfirmPassword = !_hideConfirmPassword),
                  )),
                  validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
                ),

                const SizedBox(height: 32),

                _loading 
                  ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                  : GoldButton(label: 'Reset Password', onPressed: _resetPassword),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.gold, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.gold)),
    );
  }
}