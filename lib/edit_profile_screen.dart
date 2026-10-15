import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_bars.dart';
import 'buttons.dart';
import 'inputs.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Edit Profile'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 82, height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.12),
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                child: const Icon(Icons.person, color: AppColors.gold, size: 40),
              ),
            ),
            const SizedBox(height: 24),
            const AppTextField(
              label: 'Full Name', hint: 'Nqobile Ngwenya',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            const AppTextField(
              label: 'Email', hint: 'nqobile@example.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.mail_outline,
            ),
            const SizedBox(height: 16),
            const AppTextField(
              label: 'Phone', hint: '071 234 5678',
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
            ),
            const SizedBox(height: 24),
            GoldButton(label: 'Save Profile', onPressed: () {}),
          ],
        ),
      ),
    );
  }
}