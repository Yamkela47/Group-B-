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

/// A screen that allows a customer to rate a stylist and leave a comment 
/// after a service has been completed.
class RateStylistScreen extends StatefulWidget {
  final Map<String, dynamic> booking; // The booking details (used to get IDs)
  final String stylistName;           // The name of the stylist being rated

  const RateStylistScreen({
    super.key,
    required this.booking,
    required this.stylistName,
  });

  @override
  State<RateStylistScreen> createState() => _RateStylistScreenState();
}

class _RateStylistScreenState extends State<RateStylistScreen> {
  final _supabase = Supabase.instance.client;
  
  // Controller to manage the text input for the optional comment
  final TextEditingController _commentController = TextEditingController();
  
  // State variables
  int _rating = 0;             // Default rating is 0 (no stars selected)
  bool _isSubmitting = false;  // Tracks if the review is currently being saved

  /// Handles the submission of the review to the database.
  Future<void> _submitReview() async {
    // 1. Validation: Ensure the user has selected at least 1 star
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating.'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      // 2. Insert the review into the 'reviews' table in Supabase
      await _supabase.from('reviews').insert({
        'booking_id': widget.booking['booking_id'],
        'customer_id': user.id,
        'stylist_id': widget.booking['stylist_id'],
        'rating': _rating,
        'comment': _commentController.text.trim(),
      });

      if (!mounted) return;
      
      // 3. Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you for your feedback!'),
          backgroundColor: AppColors.success,
        ),
      );
      
      // 4. Close the screen and return 'true' to tell the previous screen to refresh
      Navigator.pop(context, true); 
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      // Show error message if the database insert fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting review: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Experience'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context), // Close button in AppBar
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            
            // ==========================================
            // STYLIST AVATAR SECTION
            // ==========================================
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.1),
                border: Border.all(color: AppColors.gold, width: 2),
              ),
              child: const Icon(Icons.person, color: AppColors.gold, size: 50),
            ),
            const SizedBox(height: 20),
            const Text(
              'How was your service with',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              widget.stylistName,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 30),

            // ==========================================
            // STAR RATING SELECTION ROW
            // ==========================================
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                // Generates 5 stars. If the index is less than the current rating, 
                // it shows a solid star, otherwise an outlined star.
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: AppColors.gold,
                      size: 46,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            
            // Text indicating the current rating selection
            Text(
              _rating == 0 ? 'Tap to rate' : '$_rating Star${_rating > 1 ? 's' : ''}',
              style: const TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            // ==========================================
            // OPTIONAL COMMENT BOX
            // ==========================================
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Leave a comment (Optional)',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _commentController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Tell us what you loved about your visit...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
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
            ),
            const SizedBox(height: 40),

            // ==========================================
            // SUBMIT BUTTON
            // ==========================================
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                // Disables the button while submitting to prevent double-clicks
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSubmitting
                    // Show spinner while submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    // Show text otherwise
                    : const Text('SUBMIT REVIEW', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}