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
import 'app_theme.dart'; // Custom colors and themes
import 'app_bars.dart';  // Custom ScreenAppBar

/// A screen that allows customers to send a support message directly to the 
/// salon manager. It includes a form for the subject and message, a category
/// dropdown, and direct contact links.
class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  // Key used to validate the form fields before submission
  final _formKey = GlobalKey<FormState>();
  
  // Controllers to retrieve the text input by the user
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  
  // State variable to show a loading indicator while sending
  bool _sending = false;
  
  // State variable for the currently selected category in the dropdown
  String _selectedCategory = 'General Inquiry';

  /// Handles the submission of the support form.
  /// Validates the form, inserts the data into Supabase, and handles UI feedback.
  void _submitMessage() async {
    // Check if the form is valid (e.g., fields are not empty)
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sending = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      // Ensure the user is logged in
      if (user == null) {
        throw Exception('You must be logged in to send a message.');
      }

      // Extract text from controllers and trim whitespace
      final subject = _subjectController.text.trim();
      final message = _messageController.text.trim();

     
      await supabase.from('customer_enquiries').insert({
        'customer_id': user.id,
        'subject': subject,
        'category': _selectedCategory,
        'message': message,
        'status': 'open', // Required by your ASP.NET backend to show it as a new ticket
      });

      if (!mounted) return;
      setState(() => _sending = false);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message sent! The manager has been notified.'),
          backgroundColor: AppColors.success,
        ),
      );

      // Close the screen and return to the previous one
      Navigator.pop(context);
      
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      
      // Show error message if the database insert fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    // Clean up controllers to free up memory when the screen is closed
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Contact Support'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Header
              const Text(
                'Send us a message',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Fill out the form below and we will get back to you as soon as possible.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // ==========================================
              // Category Dropdown
              // ==========================================
              const Text(
                'Category',
                style: TextStyle(color: AppColors.gold, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    dropdownColor: AppColors.surfaceAlt,
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.gold),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() => _selectedCategory = newValue);
                      }
                    },
                    items: <String>[
                      'General Inquiry',
                      'Booking Issue',
                      'Cancellation Issue',
                      'Feedback',
                      'Technical Problem',
                    ].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ==========================================
              // Subject Input
              // ==========================================
              const Text(
                'Subject',
                style: TextStyle(color: AppColors.gold, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectController,
                style: const TextStyle(color: Colors.white),
                // Validation logic to ensure the field is not empty
                validator: (val) => val == null || val.isEmpty ? 'Please enter a subject' : null,
                decoration: _inputDecoration('Brief title for your message', Icons.subject),
              ),
              const SizedBox(height: 20),

              // ==========================================
              // Message Input
              // ==========================================
              const Text(
                'Message',
                style: TextStyle(color: AppColors.gold, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                maxLines: 6, // Allows for a multi-line text box
                style: const TextStyle(color: Colors.white),
                // Validation logic to ensure the field is not empty
                validator: (val) => val == null || val.isEmpty ? 'Please enter a message' : null,
                decoration: _inputDecoration('Describe your issue in detail...', Icons.message_outlined),
              ),
              const SizedBox(height: 32),

              // ==========================================
              // Submit Button
              // ==========================================
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  // Disables the button while sending to prevent double-clicks
                  onPressed: _sending ? null : _submitMessage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _sending
                      // Show spinner if sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      // Otherwise show text
                      : const Text('SEND MESSAGE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
              ),

              const SizedBox(height: 30),

              // ==========================================
              // Direct Contact Info
              // ==========================================
              const Text(
                'OR CONTACT US DIRECTLY',
                style: TextStyle(color: AppColors.gold, fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              _ContactTile(
                icon: Icons.phone_outlined,
                title: 'Phone',
                subtitle: '078 767 6599',
                onTap: () {},
              ),
              const SizedBox(height: 10),
              _ContactTile(
                icon: Icons.mail_outline,
                title: 'Email',
                subtitle: 'cuttinged@88@gmail.com',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A helper method that returns a consistent InputDecoration for the text fields.
  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.gold, size: 20),
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
    );
  }
}

/* ===================================================================
   CONTACT TILE WIDGET
   =================================================================== */
/// A reusable widget that creates a clickable card for contact information
/// (like a phone number or email address) with an icon on the left.
class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // The icon container on the left
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: AppColors.gold, size: 18),
            ),
            const SizedBox(width: 14),
            
            // The text details (Title and Subtitle)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}