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
import 'app_theme.dart';            // Custom colors and styles
import 'catalog_image.dart';       // Custom image widget with error handling
import 'booking_confirmed_screen.dart'; // Screen shown after a successful booking

/// A screen that acts as the final review step before booking.
/// It displays the selected service, date, time, and allows the user 
/// to choose a payment method (Cash or Card) before confirming the booking.
class PaymentMethodScreen extends StatefulWidget {
  final String service;
  final String servicePrice;
  final String serviceImagePath;
  final String stylist;
  final dynamic stylistId; 
  final dynamic serviceId; 
  final int durationMinutes;
  final DateTime date;
  final String time;

  const PaymentMethodScreen({
    super.key,
    required this.service,
    required this.servicePrice,
    required this.serviceImagePath,
    required this.stylist,
    required this.stylistId,
    this.serviceId = 1,
    this.durationMinutes = 40,
    required this.date,
    required this.time,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  final _supabase = Supabase.instance.client;
  
  // State variables
  String _selectedMethod = 'Cash'; // Default payment method
  bool _saving = false;            // Indicates if the booking is currently being processed

  /// Formats a DateTime object into a long, readable string (e.g., "Monday, 24 October 2026").
  String _formatLongDate(DateTime d) {
    const wd = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const mo = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${wd[d.weekday - 1]}, ${d.day} ${mo[d.month - 1]} ${d.year}';
  }

  /// Calculates the end time of the appointment based on the start time and duration.
  String _calculateEndTime(String startTime, int duration) {
    final parts = startTime.split(':');
    final startHour = int.parse(parts[0]);
    final startMinute = int.parse(parts[1]);
    
    // Convert start time to total minutes, add duration, then convert back to HH:mm
    final totalMinutes = (startHour * 60) + startMinute + duration; 
    final endHour = (totalMinutes ~/ 60) % 24;
    final endMinute = totalMinutes % 60;
    
    return '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
  }

  /// Handles the core logic of saving the booking to Supabase.
  Future<void> _confirmBooking() async {
    setState(() => _saving = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('You must be signed in.');

      // Map the selected payment method to a database ID (1 for Cash, 2 for Card)
      final paymentMethodId = _selectedMethod == 'Cash' ? 1 : 2;
      
      // Format the date to YYYY-MM-DD for the database
      final dateStr = '${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}';
      
      // Calculate the end time to send to the database
      final endTimeStr = _calculateEndTime(widget.time, widget.durationMinutes);

      // 1. Create the booking record in the 'bookings' table
      await _supabase.from('bookings').insert({
        'customer_id': user.id,
        'appointment_date': dateStr,
        'start_time': widget.time,
        'end_time': endTimeStr,
        'status': 'confirmed', 
        'payment_method_id': paymentMethodId,
        'stylist_id': widget.stylistId,
        'service_id': widget.serviceId, 
      });

      // Wait a tiny fraction of a second to ensure the DB processes the booking
      await Future.delayed(const Duration(milliseconds: 500));

      // 2. Insert a notification for the user confirming their booking
      await _supabase.from('notifications').insert({
        'user_id': user.id, 
        'title': 'Booking Confirmed!',
        'message': 'Your appointment for ${widget.service} with ${widget.stylist} on $dateStr at ${widget.time} has been confirmed.',
        'notification_type': 'booking',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      // 3. Navigate to the Confirmation Screen and remove this screen from the stack
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BookingConfirmedScreen(
            service: widget.service,
            stylist: widget.stylist,
            date: _formatLongDate(widget.date),
            time: widget.time,
            total: widget.servicePrice,
            serviceImagePath: widget.serviceImagePath, 
          ),
        ),
      );
    } on PostgrestException catch (e) {
      // Handle specific database errors (e.g., double booking)
      if (!mounted) return;
      setState(() => _saving = false);
      String errorMessage = 'DB Error: ${e.message} (Code: ${e.code})';
      
      // Error code 23505 means a unique constraint was violated (slot already booked)
      if (e.code == '23505') {
        errorMessage = 'Sorry, this time slot was just booked by someone else. Please pick another.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: AppColors.error),
      );
    } catch (e) {
      // Handle network or other unexpected errors
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text('Review & Pay', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          // Page Title
          const Text('Review & Pay', style: TextStyle(color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Confirm your appointment details below.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),

          // ==========================================
          // SERVICE INFO CARD
          // ==========================================
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold, width: 1.2),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CatalogImage(
                    source: widget.serviceImagePath,
                    width: 85,
                    height: 85,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.service, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(widget.stylist, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 8),
                      Text(widget.servicePrice, style: const TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // SUMMARY CARD (Date, Time, Total)
          // ==========================================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _SummaryRow(icon: Icons.calendar_today_outlined, label: 'Date', value: _formatLongDate(widget.date)),
                const SizedBox(height: 12),
                _SummaryRow(icon: Icons.access_time, label: 'Time', value: widget.time),
                const SizedBox(height: 12),
                _SummaryRow(icon: Icons.payments_outlined, label: 'Total', value: widget.servicePrice),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ==========================================
          // PAYMENT METHOD SELECTION
          // ==========================================
          const Text('Choose a Payment Method', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          
          // Cash Option
          _PaymentOption(
            icon: Icons.payments_outlined,
            title: 'Cash',
            subtitle: 'Pay at the salon on arrival',
            selected: _selectedMethod == 'Cash',
            onTap: () => setState(() => _selectedMethod = 'Cash'),
          ),
          const SizedBox(height: 10),
          
          // Card Option
          _PaymentOption(
            icon: Icons.credit_card,
            title: 'Card',
            subtitle: 'Tap or insert card on arrival',
            selected: _selectedMethod == 'Card',
            onTap: () => setState(() => _selectedMethod = 'Card'),
          ),
          const SizedBox(height: 16),

          // Information Note
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.gold, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No online payment is processed. Your chosen method will be used when you pay at the salon.',
                  style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.9), fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
      
      // ==========================================
      // BOTTOM CONFIRM BUTTON
      // ==========================================
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(color: AppColors.black, border: Border(top: BorderSide(color: AppColors.border))),
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _saving ? null : _confirmBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              // Show a loading spinner while saving, otherwise show the text
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text('CONFIRM BOOKING', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
        ),
      ),
    );
  }
}

/// A helper widget to display a single row in the summary card (Date, Time, Total).
class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  
  const _SummaryRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 18),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        const Spacer(), // Pushes the value to the right
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// A custom, selectable card widget for choosing a payment method.
class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          // Highlight the border if this option is selected
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border, 
            width: selected ? 1.8 : 1
          ),
        ),
        child: Row(
          children: [
            // Icon changes color based on selection
            Icon(icon, color: selected ? AppColors.gold : AppColors.textSecondary, size: 24),
            const SizedBox(width: 14),
            
            // Text details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            
            // Radio button indicator (circle with a checkmark if selected)
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? AppColors.gold : AppColors.border, width: 2),
              ),
              child: selected ? const Center(child: Icon(Icons.check, color: AppColors.gold, size: 14)) : null,
            ),
          ],
        ),
      ),
    );
  }
}