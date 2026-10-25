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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';                // Custom colors and styles
import 'app_bars.dart';                 // Custom AppBar widget
import 'app_drawer.dart';               // Side navigation drawer
import 'bottom_nav.dart';               // Custom bottom navigation bar
import 'cards.dart';                    // Custom AppCard widget
import 'notifications_screen.dart';     // Screen to view notifications
import 'my_appointment_screen.dart';    // Screen to view all appointments
import 'daily_schedule_screen.dart';    // Screen to view today's schedule
import 'manage_availability_screen.dart'; // Screen to set working hours
import 'blocked_dates_screen.dart';     // Screen to block specific dates
import 'stylist_profile_screen.dart';   // Screen to view/edit stylist profile
import 'stylist_session.dart';          // Helper to resolve the current stylist's ID
import 'notification_service.dart';     // Service to handle realtime notifications

/// The main dashboard screen for Stylists after they log in.
/// It displays a summary of their day (appointment count and next appointment)
/// and provides quick access to their key management screens.
class StylistHomeScreen extends StatefulWidget {
  const StylistHomeScreen({super.key});
  @override
  State<StylistHomeScreen> createState() => _StylistHomeScreenState();
}

class _StylistHomeScreenState extends State<StylistHomeScreen> {
  // State variables
  int _nav = 0; // Tracks the currently selected bottom navigation tab
  final _supabase = Supabase.instance.client;
  
  String _firstName = 'Stylist'; // The stylist's first name to greet them
  bool _loading = true;          // Loading state for the dashboard data
  int _todayCount = 0;           // Number of active appointments today
  Map<String, dynamic>? _next;   // The next upcoming appointment today
  
  late NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    // Fetch initial dashboard data
    _loadDashboardData();
    
    // Initialize the notification service to listen for realtime updates
    _notificationService = NotificationService(context);
    _notificationService.initialize();
  }

  @override
  void dispose() {
    // Clean up the notification service to prevent memory leaks
    _notificationService.dispose();
    super.dispose();
  }

  /// Fetches the stylist's name, today's appointment count, and the next appointment.
  Future<void> _loadDashboardData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // 1. Fetch Stylist Profile Info (to get their full name)
    final profileData = await _supabase
        .from('profiles')
        .select('full_name')
        .eq('id', user.id)
        .maybeSingle();

    // 2. Fetch the Stylist ID from the session helper
    final stylistId = await StylistSession.resolve();
    if (stylistId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    // 3. Fetch Today's Appointments
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    final bookings = await _supabase
        .from('bookings')
        .select('start_time, status, services(name)')
        .eq('stylist_id', stylistId)
        .eq('appointment_date', todayStr)
        // We intentionally don't filter out cancelled statuses in the database query.
        // Instead, we fetch all bookings for today and sort them in Dart.
        .order('start_time', ascending: true);

    int count = 0;
    Map<String, dynamic>? nextAppt;

    if (bookings.isNotEmpty) {
      // Filter the bookings to only include "active" ones (pending, confirmed, booked).
      // This ignores completed, cancelled, and no-show appointments.
      final activeBookings = bookings.where((b) {
        final status = (b['status'] ?? '').toString().toLowerCase().trim();
        return status == 'pending' || status == 'confirmed' || status == 'booked';
      }).toList();

      count = activeBookings.length;
      if (activeBookings.isNotEmpty) {
        // The first item in the list is the next upcoming appointment
        nextAppt = activeBookings.first;
      }
    }

    if (mounted) {
      setState(() {
        // Extract just the first name for a friendly greeting
        _firstName = (profileData?['full_name'] ?? 'Stylist').split(' ').first;
        _todayCount = count;
        _next = nextAppt;
        _loading = false;
      });
    }
  }

  /// Formats the current date into a readable string (e.g., "Monday, 24 Oct 2026").
  String _getFormattedDate() {
    final now = DateTime.now();
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  /// Formats the label for the next appointment (e.g., "Next at 14:00 · Haircut").
  String _getNextLabel() {
    if (_next == null) return 'No appointments left today';
    final time = (_next!['start_time'] as String).substring(0, 5);
    final service = _next!['services']?['name'] ?? 'Service';
    return 'Next at $time · $service';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The side navigation drawer for the stylist role
      drawer: const AppDrawer(isStylist: true),
      
      // Custom AppBar with a notification bell action
      appBar: MainAppBar(
        onBell: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen())),
      ),
      
      // The main body of the screen
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
        : RefreshIndicator(
            onRefresh: _loadDashboardData,
            color: AppColors.gold,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 18),
                  
                  // ==========================================
                  // HEADER SECTION
                  // ==========================================
                  Text(
                    'Good Morning, $_firstName',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getFormattedDate(),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                  const SizedBox(height: 20),
                  
                  // ==========================================
                  // STATS CARD
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [AppColors.gold.withValues(alpha: 0.12), AppColors.surfaceAlt],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Today's Appointments",
                                  style: TextStyle(
                                      color: AppColors.textMuted, fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              // Large number showing today's count
                              Text('$_todayCount',
                                  style: const TextStyle(
                                      color: AppColors.gold, fontSize: 32, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 2),
                              Text(_todayCount == 1 ? 'appointment scheduled' : 'appointments scheduled',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              const SizedBox(height: 6),
                              // Shows the next appointment time and service
                              Text(_getNextLabel(),
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                        // Calendar icon
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.gold.withValues(alpha: 0.12),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.event_available, color: AppColors.gold, size: 24),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // ==========================================
                  // QUICK ACTIONS SECTION
                  // ==========================================
                  const Text('Quick Actions', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  
                  _ActionRow(
                    icon: Icons.calendar_month_outlined, 
                    title: 'My Appointments',
                    subtitle: 'View upcoming bookings', 
                    screen: const MyAppointmentsScreen(),
                  ),
                  _ActionRow(
                    icon: Icons.schedule_outlined, 
                    title: 'Daily Schedule',
                    subtitle: 'See your next shift', 
                    screen: const DailyScheduleScreen(),
                  ),
                  _ActionRow(
                    icon: Icons.tune_outlined, 
                    title: 'Manage Availability',
                    subtitle: 'Set working hours', 
                    screen: const ManageAvailabilityScreen(),
                  ),
                  _ActionRow(
                    icon: Icons.block_outlined, 
                    title: 'Blocked Dates',
                    subtitle: 'Mark days you are unavailable', 
                    screen: const BlockedDatesScreen(),
                  ),
                  _ActionRow(
                    icon: Icons.person_outline, 
                    title: 'My Profile',
                    subtitle: 'View your public information', 
                    screen: const StylistProfileScreen(),
                  ),
                  
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
      
      // ==========================================
      // BOTTOM NAVIGATION BAR
      // ==========================================
      bottomNavigationBar: BottomNav(
        index: _nav,
        onChanged: (i) {
          if (i == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyScheduleScreen()));
          } else if (i == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const StylistProfileScreen()));
          } else {
            setState(() => _nav = i);
          }
        },
        items: const [
          BottomNavItem(Icons.home_outlined, 'Home'),
          BottomNavItem(Icons.schedule_outlined, 'Schedule'),
          BottomNavItem(Icons.person_outline, 'Profile'),
        ],
      ),
    );
  }
}

/// A custom reusable widget for the quick action rows on the home screen.
/// It displays an icon, title, subtitle, and navigates to a new screen when tapped.
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget screen;
  
  const _ActionRow({
    required this.icon, required this.title,
    required this.subtitle, required this.screen,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: AppColors.gold, size: 18),
          ),
          const SizedBox(width: 14),
          
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          
          // Chevron icon
          const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
        ],
      ),
    );
  }
}