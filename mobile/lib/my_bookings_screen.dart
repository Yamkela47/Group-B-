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
import 'rate_stylist_screen.dart';  // Screen to leave a review for a completed booking
import 'booking_gate.dart';         // Prevents double-booking
import 'services_screen.dart';      // Screen to browse and book new services

/// A screen for Customers to view their bookings.
/// It divides the bookings into three tabs: Upcoming, Past, and Cancelled.
/// It also allows users to cancel, reschedule, and rate their appointments.
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});
  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _supabase = Supabase.instance.client;
  
  // State variables for loading and error handling
  bool _loading = true;
  String? _errorMessage;
  
  // Lists to hold the categorized bookings
  List<Map<String, dynamic>> _upcoming = [];
  List<Map<String, dynamic>> _past = [];
  List<Map<String, dynamic>> _cancelled = [];
  
  // Set to track which bookings have already been reviewed
  Set<String> _reviewedBookingIds = {};
  
  // Tracks the currently selected tab (0 = Upcoming, 1 = Past, 2 = Cancelled)
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Fetches all bookings and reviews for the currently logged-in customer,
  /// then categorizes them into Upcoming, Past, and Cancelled lists.
  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('You are not logged in.');

      // 1. Fetch all bookings for this customer, newest first
      final data = await _supabase
          .from('bookings')
          .select('*')
          .eq('customer_id', user.id)
          .order('appointment_date', ascending: false);

      // 2. Fetch all reviews left by this customer to check which bookings are rated
      final reviewsData = await _supabase
          .from('reviews')
          .select('booking_id')
          .eq('customer_id', user.id);

      final all = List<Map<String, dynamic>>.from(data);
      final now = DateTime.now();

      setState(() {
        _reviewedBookingIds = (reviewsData as List).map((r) => r['booking_id'].toString()).toSet();

        // Filter: Upcoming (Pending/Confirmed AND Date is today or in the future)
        _upcoming = all.where((b) {
          final d = DateTime.parse(b['appointment_date']);
          final isTodayOrFuture = !d.isBefore(DateTime(now.year, now.month, now.day));
          final status = b['status']?.toString().toLowerCase();
          return (status == 'pending' || status == 'confirmed') && isTodayOrFuture;
        }).toList();

        // Filter: Past (Completed OR Date has already passed)
        _past = all.where((b) {
          final d = DateTime.parse(b['appointment_date']);
          final status = b['status']?.toString().toLowerCase();
          return status == 'completed' || ((status == 'confirmed' || status == 'pending') && d.isBefore(DateTime(now.year, now.month, now.day)));
        }).toList();

        // Filter: Cancelled (Cancelled by customer or stylist)
        _cancelled = all.where((b) {
          final status = b['status']?.toString().toLowerCase();
          return status == 'cancelled' || status == 'cancelled_by_stylist';
        }).toList();

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  /// Prompts the user for a cancellation reason, then updates the booking status.
  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final TextEditingController reasonController = TextEditingController();

    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceAlt,
        title: const Text('Cancel Booking', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: reasonController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Reason for cancellation (Optional)',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Booking', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    
    try {
      // 1. Update the booking status to 'cancelled'
      await _supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('booking_id', booking['booking_id']);

      // 2. Insert the cancellation reason into a separate table (if it exists)
      try {
        await _supabase.from('cancellations').insert({
          'booking_id': booking['booking_id'],
          'reason': reasonController.text.isEmpty ? 'No reason provided' : reasonController.text,
        });
      } catch (e) {
        debugPrint('Could not save cancellation reason: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled.'), backgroundColor: AppColors.success),
      );
      _load(); // Refresh the list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  /// Handles the complex logic of rescheduling a booking.
  /// It requires checking the stylist's availability on the new date.
  Future<void> _rescheduleBooking(Map<String, dynamic> booking) async {
    final int? stylistId = booking['stylist_id'];
    if (stylistId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot reschedule: No stylist assigned.'), backgroundColor: AppColors.error),
      );
      return;
    }

    // Retrieve the duration of the original service to maintain it
    final int requestedDuration = (booking['duration_minutes'] as num?)?.toInt() ?? 40;

    // 1. Ask the user for a new date
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.gold, surface: AppColors.surfaceAlt),
        ),
        child: child!,
      ),
    );
    if (pickedDate == null) return;

    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.gold)));
    
    // List to hold existing bookings for the chosen date
    List<Map<String, String>> existingBookings = [];
    
    try {
      final dateStr = '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
      
      // 2. Fetch all other bookings for this stylist on the chosen date
      final data = await _supabase
          .from('bookings')
          .select('start_time, end_time')
          .eq('stylist_id', stylistId)
          .eq('appointment_date', dateStr)
          .neq('status', 'cancelled')
          .neq('booking_id', booking['booking_id']); // Exclude the current booking being rescheduled

      for (var row in (data as List)) {
        final start = row['start_time'] as String? ?? '';
        final end = row['end_time'] as String? ?? '';
        
        if (start.length >= 5 && end.length >= 5) {
          existingBookings.add({
            'start': start.substring(0, 5),
            'end': end.substring(0, 5),
          });
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error checking availability: $e')));
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);

    // 3. Show the custom dialog to pick a specific time slot
    final String? pickedTime = await showDialog<String>(
      context: context,
      builder: (ctx) => _TimeSelectionDialog(
        date: pickedDate,
        existingBookings: existingBookings,
        requestedDuration: requestedDuration,
      ),
    );

    if (pickedTime == null) return;

    try {
      final String formattedDate = '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
      final String formattedStartTime = '$pickedTime:00';

      // Calculate the new end time based on the duration
      final String formattedEndTime = _calculateEndTime(formattedStartTime, requestedDuration);

      // 4. Update the booking in the database with the new date and time
      await _supabase
          .from('bookings')
          .update({
            'appointment_date': formattedDate,
            'start_time': formattedStartTime,
            'end_time': formattedEndTime, 
            'status': 'confirmed', 
          })
          .eq('booking_id', booking['booking_id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully rescheduled!'), backgroundColor: AppColors.success),
      );
      await _load();

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reschedule: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  /// Helper function to calculate the end time based on a start time and duration.
  String _calculateEndTime(String startTime, int durationMinutes) {
    final parts = startTime.split(':');
    // Convert start time to total minutes, add duration, then convert back
    final totalMinutes = (int.parse(parts[0]) * 60) + int.parse(parts[1]) + durationMinutes;
    final endHour = (totalMinutes ~/ 60) % 24;
    final endMinute = totalMinutes % 60;
    return '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}:00';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text('My Bookings', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.gold),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.surfaceAlt,
        onRefresh: _load,
        child: _buildBody(),
      ),
      // Bottom button to book a new service
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () => BookingGate.checkAndProceedToBook(
                context, 
                const ServicesScreen(),
              ).then((_) => _load()), // Refresh the list after returning from the booking screen
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.content_cut, size: 18),
                  SizedBox(width: 10),
                  Text('BOOK ANOTHER SERVICE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the main content area of the screen.
  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.gold));

    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 50),
          const SizedBox(height: 16),
          const Text('Error Loading Bookings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_errorMessage!, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _load, child: const Text('Try Again')),
        ],
      );
    }

    return Column(
      children: [
        // Tab Selection Row
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              _buildTab('Upcoming', _upcoming.length, 0),
              const SizedBox(width: 8),
              _buildTab('Past', _past.length, 1),
              const SizedBox(width: 8),
              _buildTab('Cancelled', _cancelled.length, 2),
            ],
          ),
        ),
        // List of bookings for the selected tab
        Expanded(child: _getListForCurrentTab()),
      ],
    );
  }

  /// Builds the custom Tab buttons (Upcoming, Past, Cancelled).
  Widget _buildTab(String label, int count, int index) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.gold : AppColors.border),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(color: isSelected ? Colors.black : AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  /// Returns the correct list of bookings based on the selected tab index.
  Widget _getListForCurrentTab() {
    List<Map<String, dynamic>> items;
    if (_tabIndex == 0) items = _upcoming;
    else if (_tabIndex == 1) items = _past;
    else items = _cancelled;

    if (items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 60),
          Center(child: Text('No bookings here.', style: TextStyle(color: AppColors.textMuted, fontSize: 14))),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildBookingCard(items[index]),
    );
  }

  /// Builds the UI card for a single booking.
  Widget _buildBookingCard(Map<String, dynamic> b) {
    // Determine status color
    final status = b['status']?.toString().toUpperCase() ?? 'CONFIRMED';
    final isCancelled = status == 'CANCELLED' || status == 'CANCELLED_BY_STYLIST';
    final isPending = status == 'PENDING';
    
    Color statusColor = AppColors.success;
    if (isCancelled) statusColor = AppColors.error;
    if (isPending) statusColor = Colors.orange;

    final String dateStr = b['appointment_date'] ?? 'Unknown Date';
    final String timeStr = b['start_time'] ?? 'Unknown Time';
    final bool hasBeenReviewed = _reviewedBookingIds.contains(b['booking_id'].toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Appointment text and Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Appointment', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: statusColor)),
                child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Date and Time Row
          Row(
            children: [
              const Icon(Icons.calendar_today, color: AppColors.gold, size: 14),
              const SizedBox(width: 8),
              Text(dateStr, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(width: 16),
              const Icon(Icons.access_time, color: AppColors.gold, size: 14),
              const SizedBox(width: 8),
              Text(timeStr, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
          
          // Action Buttons for Upcoming Bookings
          if (_tabIndex == 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _cancelBooking(b),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _rescheduleBooking(b),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
                    child: const Text('Reschedule'),
                  ),
                ),
              ],
            ),
          ],
          
          // Rate Button for Past Bookings
          if (_tabIndex == 1 && status == 'COMPLETED') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: hasBeenReviewed
                  // If reviewed, show a disabled "Rated" button
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                      label: const Text('Rated', style: TextStyle(color: AppColors.success)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.success),
                      ),
                    )
                  // If not reviewed, show the "Rate Service" button
                  : ElevatedButton.icon(
                      onPressed: () async {
                        // Fetch the stylist's name to pass to the review screen
                        final stylistData = await _supabase
                            .from('stylists')
                            .select('profiles(full_name)')
                            .eq('stylist_id', b['stylist_id'])
                            .maybeSingle();
                        
                        String stylistName = 'Your Stylist';
                        if (stylistData != null && stylistData['profiles'] != null) {
                          stylistName = stylistData['profiles']['full_name'] ?? 'Your Stylist';
                        }

                        if (!mounted) return;
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RateStylistScreen(
                              booking: b,
                              stylistName: stylistName,
                            ),
                          ),
                        );
                        if (result == true) _load(); // Reload if a review was submitted
                      },
                      icon: const Icon(Icons.star, size: 18),
                      label: const Text('Rate Service'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/* ============================================================
   TIME SELECTION DIALOG (For Rescheduling)
   ============================================================ */
/// A custom dialog that presents available time slots for a given date.
/// It intelligently blocks out times that overlap with existing bookings.
class _TimeSelectionDialog extends StatefulWidget {
  final DateTime date;
  final List<Map<String, String>> existingBookings;
  final int requestedDuration;

  const _TimeSelectionDialog({
    required this.date, 
    required this.existingBookings,
    required this.requestedDuration,
  });

  @override
  State<_TimeSelectionDialog> createState() => _TimeSelectionDialogState();
}

class _TimeSelectionDialogState extends State<_TimeSelectionDialog> {
  String? _selectedTime;

  int _toMinutes(String time) {
    final parts = time.split(':');
    return (int.parse(parts[0]) * 60) + int.parse(parts[1]);
  }

  Map<String, List<String>> _generateSlots() {
    final morning = <String>[];
    final afternoon = <String>[];
    
    // Generate 30-minute slots between 9 AM and 5 PM
    for (int hour = 9; hour < 17; hour++) {
      for (final minute in [0, 30]) {
        final hh = hour.toString().padLeft(2, '0');
        final mm = minute.toString().padLeft(2, '0');
        final slot = '$hh:$mm';
        (hour < 12 ? morning : afternoon).add(slot);
      }
    }
    return {'Morning': morning, 'Afternoon': afternoon};
  }

  /// Checks if a given time slot overlaps with any existing bookings.
  bool _isSlotBlocked(String slotTime) {
    final slotStart = _toMinutes(slotTime);
    final slotEnd = slotStart + widget.requestedDuration;

    for (var booking in widget.existingBookings) {
      final takenStart = _toMinutes(booking['start']!);
      final takenEnd = _toMinutes(booking['end']!);

      // Standard overlap logic: If the new slot starts before an existing booking ends,
      // AND the new slot ends after an existing booking starts, it's a conflict.
      if (slotStart < takenEnd && slotEnd > takenStart) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _generateSlots();

    return AlertDialog(
      backgroundColor: AppColors.surfaceAlt,
      title: const Text('Select New Time', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            if (grouped['Morning']!.isNotEmpty) ...[
              const Text('MORNING', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: grouped['Morning']!.map((t) => _buildTimeChip(t)).toList(),
              ),
              const SizedBox(height: 16),
            ],
            if (grouped['Afternoon']!.isNotEmpty) ...[
              const Text('AFTERNOON', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: grouped['Afternoon']!.map((t) => _buildTimeChip(t)).toList(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _selectedTime == null ? null : () => Navigator.pop(context, _selectedTime),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  /// Builds the individual time chips.
  Widget _buildTimeChip(String time) {
    final isTaken = _isSlotBlocked(time);
    final isSelected = _selectedTime == time;

    return GestureDetector(
      onTap: isTaken ? null : () => setState(() => _selectedTime = time),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isTaken 
              ? AppColors.surface 
              : isSelected ? AppColors.gold : AppColors.black,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isTaken 
                ? AppColors.border 
                : isSelected ? AppColors.gold : AppColors.border,
          ),
        ),
        child: Text(
          time,
          style: TextStyle(
            color: isTaken 
                ? AppColors.textMuted 
                : isSelected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            decoration: isTaken ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}