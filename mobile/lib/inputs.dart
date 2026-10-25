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
import 'app_theme.dart'; // Custom colors and styles

/// A custom, reusable text input widget used across the app.
/// It provides a consistent look with an uppercase label, a styled text field,
/// optional prefix icons, and a built-in visibility toggle for passwords.
class AppTextField extends StatefulWidget {
  final String label;                   // The text to display above the input field
  final String? hint;                   // The placeholder text inside the field
  final TextEditingController? controller; // Manages the text being typed
  final bool obscure;                   // If true, hides the text (for passwords)
  final TextInputType? keyboardType;    // Determines the keyboard layout (e.g., email, phone)
  final IconData? prefixIcon;           // Optional icon on the left side of the field
  final int maxLines;                   // Number of lines (default 1 for single-line)
  final bool enabled;                   // Allows disabling the field (e.g., while loading)

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscure = false,
    this.keyboardType,
    this.prefixIcon,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  // Local state to manage whether the password is currently hidden or visible.
  // It is initialized with the value passed from the parent widget.
  late bool _obscure = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      // Aligns the label and the text field to the left side
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==========================================
        // LABEL TEXT
        // ==========================================
        Text(
          widget.label.toUpperCase(), // Converts the label to uppercase for a clean look
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            letterSpacing: 1.4, // Adds space between letters
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8), // Spacing between the label and the field

        // ==========================================
        // TEXT FIELD
        // ==========================================
        TextField(
          controller: widget.controller,
          obscureText: _obscure, // Uses the local state for hiding/showing text
          keyboardType: widget.keyboardType,
          maxLines: widget.maxLines,
          enabled: widget.enabled,
          style: const TextStyle(color: Colors.white, fontSize: 14), // Text color of the input
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            
            // Conditionally render a prefix icon if one was provided
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, color: AppColors.textMuted, size: 18)
                : null,
                
            // Conditionally render a visibility toggle icon if this is a password field
            suffixIcon: widget.obscure
                ? IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined // Eye closed (text is hidden)
                          : Icons.visibility_outlined,    // Eye open (text is visible)
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                    // Tapping the icon toggles the local state, rebuilding the widget
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}