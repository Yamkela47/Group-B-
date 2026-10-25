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
import 'app_theme.dart';      // Imports AppColors for custom UI colors
import 'services_screen.dart'; // The default destination if no other is provided

/// The `BookingGate` class is a utility class designed to prevent users from 
/// booking multiple appointments at the same time. It checks the database for 
/// existing active bookings before allowing navigation to a booking screen.
class BookingGate {
  
  /// 1. Used for explicit "book" actions (e.g., from the Home Screen).
  /// 
  /// This method checks for active bookings. If the user is clear to book,
  /// it navigates to the provided [destination]. If no destination is given,
  /// it defaults to the [ServicesScreen].
  static Future<void> attemptBooking(BuildContext context, {Widget? destination}) async {
    // Check if the user has an active booking
    bool canProceed = await _checkActiveBookings(context);
    
    // If they can proceed and the context is still valid
    if (canProceed && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => destination ?? const ServicesScreen(),
        ),
      );
    }
  }

  /// 2. Used by specific entry points (like the Team Member Profile) to go to a specific stylist.
  /// 
  /// Similar to `attemptBooking`, but it returns a `bool` indicating success 
  /// so the calling widget can perform additional actions if needed.
  static Future<bool> checkAndProceedToBook(BuildContext context, Widget destination) async {
    bool canProceed = await _checkActiveBookings(context);
    
    if (canProceed && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );
      return true; // Successfully navigated
    }
    return false; // Blocked from navigating
  }

  /// The core logic that actually checks the database for active bookings.
  /// 
  /// It shows a loading spinner while fetching data. If an active booking is found,
  /// it displays a warning bottom sheet and returns `false`. Otherwise, it returns `true`.
  static Future<bool> _checkActiveBookings(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    
    // If no user is logged in, they can't book.
    if (user == null) return false;

    // Show a blocking loading spinner while we query the database
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
    );

    bool hasActiveBooking = false;

    try {
      // Query the 'bookings' table for all bookings belonging to this user
      final data = await supabase
          .from('bookings')
          .select('booking_id, status')
          .eq('customer_id', user.id);

      final allBookings = List<Map<String, dynamic>>.from(data);

      // Check if ANY of the bookings have an active status
      hasActiveBooking = allBookings.any((b) {
        final status = (b['status'] ?? '').toString().toLowerCase().trim();
        // If the status is pending, confirmed, or booked, it's considered active
        return status == 'pending' || status == 'confirmed' || status == 'booked';
      });
    } catch (e) {
      // Log error but fail safely (allow booking if the check fails due to network, etc.)
      debugPrint('Error checking active bookings: $e');
    }

    if (!context.mounted) return false;
    
    // Close the loading spinner
    Navigator.pop(context); 

    // If an active booking was found, show the warning popup and block them
    if (hasActiveBooking) {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surfaceAlt,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_clock, color: AppColors.gold, size: 50),
              const SizedBox(height: 16),
              const Text(
                'Active Appointment Found',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'You must complete or cancel your current appointment before booking a new one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context), // Close the bottom sheet
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
      return false; // Block the booking action
    }

    return true; // No active booking found, allow the user to proceed
  }
}