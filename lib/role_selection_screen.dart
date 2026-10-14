import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'brand.dart';
import 'buttons.dart';
import 'login_screen.dart';
import 'create_account_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});
  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String _role = 'Customer';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const BrandTitle(logoSize: 76),
              const Spacer(),
              const Text('Welcome',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'Welcome to Cutting Edge Salon application.\nPlease select how you would like to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 32),
              _RoleCard(
                icon: Icons.person_outline,
                title: 'Customer',
                selected: _role == 'Customer',
                onTap: () => setState(() => _role = 'Customer'),
              ),
              const SizedBox(height: 14),
              _RoleCard(
                icon: Icons.content_cut,
                title: 'Stylist',
                selected: _role == 'Stylist',
                onTap: () => setState(() => _role = 'Stylist'),
              ),
              const Spacer(),
              GoldButton(
                label: 'Sign In',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen(role: _role)),
                ),
              ),
              const SizedBox(height: 12),
              GhostButton(
                label: 'Create Account',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;
  const _RoleCard({
    required this.icon, required this.title,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? AppColors.gold : AppColors.textSecondary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: selected ? AppColors.gold : Colors.white,
                  fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.gold, size: 18),
          ],
        ),
      ),
    );
  }
}