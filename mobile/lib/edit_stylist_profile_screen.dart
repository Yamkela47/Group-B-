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
import 'app_theme.dart'; // Custom colors and styles

/// A screen that allows a Stylist to edit their professional profile details.
/// It fetches existing data from the database and allows updating the Name, Phone,
/// Specialization, and Bio. The Email field is read-only to prevent auth conflicts.
class EditStylistProfileScreen extends StatefulWidget {
  const EditStylistProfileScreen({super.key});

  @override
  State<EditStylistProfileScreen> createState() => _EditStylistProfileScreenState();
}

class _EditStylistProfileScreenState extends State<EditStylistProfileScreen> {
  // Key for validating the form before submission
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  
  // Controllers to manage the text input fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specializationController = TextEditingController();
  final _bioController = TextEditingController();
  
  // State variables to handle UI loading states
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Fetch the current profile data as soon as the screen loads
    _loadCurrentData();
  }

  @override
  void dispose() {
    // Clean up the controllers when the screen is closed to free memory
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Fetches the existing stylist data from the 'profiles' table in Supabase
  /// and populates the text controllers.
  Future<void> _loadCurrentData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Query the custom 'profiles' table for this user's ID
    final data = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();
    
    if (mounted) {
      setState(() {
        // Populate fields using the database data, falling back to Auth metadata if needed
        _nameController.text = data?['full_name'] ?? user.userMetadata?['full_name'] ?? '';
        _emailController.text = user.email ?? '';
        _phoneController.text = data?['phone'] ?? user.userMetadata?['phone'] ?? '';
        _specializationController.text = data?['specialization'] ?? '';
        _bioController.text = data?['bio'] ?? '';
        _isLoading = false;
      });
    }
  }

  /// Validates the form and saves the updated data back to Supabase.
  Future<void> _saveChanges() async {
    // Trigger validation on all form fields
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("Not logged in");

      // 1. Update the custom 'profiles' table with the new data
      await _supabase.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'bio': _bioController.text.trim(),
      }).eq('id', user.id);

      // 2. Update the Auth user metadata to keep it in sync
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
          },
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: AppColors.success),
      );
      
      // Close the screen and return to the previous one
      Navigator.pop(context);
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Full Name Field
                  _buildLabel('Full Name'),
                  _buildTextField(
                    controller: _nameController,
                    hint: 'e.g. Sarah Mitchell',
                    icon: Icons.person_outline,
                    validator: (v) => v == null || v.isEmpty ? 'Name cannot be empty' : null,
                  ),
                  const SizedBox(height: 16),

                  // Email Field (Read-Only)
                  _buildLabel('Email'),
                  _buildTextField(
                    controller: _emailController,
                    hint: 'e.g. stylist@cuttingedge.com',
                    icon: Icons.mail_outline,
                    readOnly: true, // Email cannot be edited here
                  ),
                  const SizedBox(height: 16),

                  // Phone Field
                  _buildLabel('Phone'),
                  _buildTextField(
                    controller: _phoneController,
                    hint: 'e.g. 071 234 5678',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) => v == null || v.isEmpty ? 'Phone cannot be empty' : null,
                  ),
                  const SizedBox(height: 16),

                  // Specialization Field
                  _buildLabel('Specialization'),
                  _buildTextField(
                    controller: _specializationController,
                    hint: 'e.g. Cut & Dye',
                    icon: Icons.workspace_premium_outlined,
                  ),
                  const SizedBox(height: 16),

                  // Bio Field (Multi-line)
                  _buildLabel('Bio'),
                  _buildTextField(
                    controller: _bioController,
                    hint: 'Passionate about creating confidence through great hair...',
                    icon: Icons.edit_note_outlined,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 30),

                  // Save Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isSaving 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : const Text('SAVE PROFILE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  /// Helper widget to build a consistent uppercase label for the text fields.
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(), 
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }

  /// Helper widget to build a consistent text input field.
  /// Handles read-only states (like the email field) and standard validation.
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      keyboardType: keyboardType,
      validator: validator,
      // Change text color if the field is read-only to indicate it cannot be edited
      style: TextStyle(color: readOnly ? AppColors.textMuted : Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        // Change icon color if read-only
        prefixIcon: Icon(icon, color: readOnly ? AppColors.textMuted : AppColors.gold, size: 20),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.gold)),
      ),
    );
  }
}