import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_bars.dart';
import 'brand.dart';
import 'buttons.dart';
import 'verify_account_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
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

  InputDecoration _decoration(
    String label,
    String hint,
    IconData icon, {
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.gold),
      suffixIcon: suffix,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      filled: true,
      fillColor: const Color(0xFF171717),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF393939)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF393939)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gold),
      ),
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      enabled: enabled,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: _decoration(label, hint, icon, suffix: suffix),
    );
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final email = _email.text.trim();
      final fullName = _name.text.trim();
      final phone = _phone.text.trim();

      final response = await _supabase.auth.signUp(
        email: email,
        password: _password.text,
        data: {
          'full_name': fullName,
          'phone': phone,
          'role': 'Customer',
        },
      );

      if (!mounted) return;

      /* -------------------------------------------------- */
      /* 1. Supabase returned no user → something went wrong */
      /* -------------------------------------------------- */
      if (response.user == null) {
        _message(
          'Account could not be created. Please try again.',
          color: AppColors.error,
        );
        return;
      }

      /* -------------------------------------------------- */
      /* 2. Session == null → email confirmation is required */
      /*    Send the user to the OTP screen                 */
      /* -------------------------------------------------- */
      if (response.session == null) {
        _message(
          'We sent a 6-digit code to $email. Please check your inbox.',
          color: AppColors.success,
        );

        // Give the SnackBar a moment to show before navigating
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyAccountScreen(email: email),
          ),
        );
        return;
      }

      /* -------------------------------------------------- */
      /* 3. Session exists → email confirmation is disabled  */
      /*    on this Supabase project. Account is ready.      */
      /* -------------------------------------------------- */
      _message(
        'Account created successfully! You are now logged in.',
        color: AppColors.success,
      );
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.pop(context);
    } on AuthException catch (e) {
      // Show the real reason: weak password, email exists, etc.
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
      appBar: const ScreenAppBar(title: 'Create Account'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                const Center(child: BrandLogo(size: 56)),
                const SizedBox(height: 24),
                const Text(
                  'Create Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Join the Cutting Edge family and start booking today!',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),

                /* ---------------- Full Name ---------------- */
                _field(
                  label: 'Full Name',
                  hint: 'John Doe',
                  icon: Icons.person_outline,
                  controller: _name,
                  enabled: !_loading,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter your full name'
                      : null,
                ),
                const SizedBox(height: 16),

                /* ---------------- Email ---------------- */
                _field(
                  label: 'Email',
                  hint: 'you@example.com',
                  icon: Icons.mail_outline,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_loading,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter your email';
                    }
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(v.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                /* ---------------- Phone ---------------- */
                _field(
                  label: 'Phone Number',
                  hint: '+27 78 767 6599',
                  icon: Icons.phone_outlined,
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  enabled: !_loading,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter your phone number'
                      : null,
                ),
                const SizedBox(height: 16),

                /* ---------------- Password ---------------- */
                _field(
                  label: 'Password',
                  hint: 'At least 8 characters',
                  icon: Icons.lock_outline,
                  controller: _password,
                  obscure: _hidePassword,
                  enabled: !_loading,
                  suffix: IconButton(
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.gold,
                    ),
                    onPressed: () => setState(
                      () => _hidePassword = !_hidePassword,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                /* ---------------- Confirm Password ---------------- */
                _field(
                  label: 'Confirm Password',
                  hint: 'Re-enter your password',
                  icon: Icons.lock_outline,
                  controller: _confirmPassword,
                  obscure: _hideConfirmPassword,
                  enabled: !_loading,
                  suffix: IconButton(
                    icon: Icon(
                      _hideConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.gold,
                    ),
                    onPressed: () => setState(
                      () => _hideConfirmPassword = !_hideConfirmPassword,
                    ),
                  ),
                  validator: (v) => v != _password.text
                      ? 'Passwords do not match'
                      : null,
                ),
                const SizedBox(height: 22),

                /* ---------------- Submit Button ---------------- */
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
                        label: 'Create Account',
                        onPressed: _createAccount,
                      ),

                const SizedBox(height: 18),
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: const Text(
                      'Already have an account? Back to Login',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}