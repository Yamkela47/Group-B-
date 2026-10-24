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
import 'app_theme.dart'; // Custom colors and text styles
import 'catalog_image.dart'; // Custom image widget that handles null/errors gracefully

// Customer Screens
import 'customer_home_screen.dart';
import 'services_screen.dart';
import 'my_bookings_screen.dart';
import 'our_team_screen.dart';
import 'salon_info_screen.dart';
import 'my_profile_screen.dart';
import 'settings_screen.dart';
import 'gallery_screen.dart';
import 'logout_screen.dart';

// Stylist Screens
import 'stylist_home_screen.dart';
import 'my_appointment_screen.dart';
import 'daily_schedule_screen.dart';
import 'manage_availability_screen.dart';
import 'blocked_dates_screen.dart';

/// The `AppDrawer` is a side navigation menu that slides in from the left.
/// It is used to navigate between different screens in the app.
/// It dynamically changes its menu items based on whether the user is a
/// Customer (`isStylist = false`) or a Stylist (`isStylist = true`).
class AppDrawer extends StatefulWidget {
  final bool isStylist;

  const AppDrawer({super.key, this.isStylist = false});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  // Supabase client to fetch user data
  final _supabase = Supabase.instance.client;
  
  // State variable to hold the user's profile picture URL
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    // Fetch the profile picture as soon as the drawer is initialized
    _loadProfilePic();
  }

  /// Fetches the user's profile image URL from the `profiles` table in Supabase.
  Future<void> _loadProfilePic() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await _supabase
          .from('profiles')
          .select('photo_url')
          .eq('id', user.id)
          .maybeSingle();

      // If the widget is still mounted and data exists, update the state
      if (mounted && data != null) {
        setState(() => _photoUrl = data['photo_url']?.toString());
      }
    } catch (_) {
      // Silently fail if there's an error fetching the image
    }
  }

  /// Helper method to navigate to a new screen.
  /// It first closes the drawer, then pushes the new route.
  void _navigate(BuildContext context, Widget screen) {
    Navigator.pop(context); // Close the drawer first
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  /// Helper method to navigate back to the main Home screen.
  /// It closes the drawer and completely clears the navigation stack
  /// so the user can't press 'back' to return to previous screens.
  void _navigateHome(BuildContext context) {
    Navigator.pop(context);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => widget.isStylist
            ? const StylistHomeScreen()
            : const CustomerHomeScreen(),
      ),
      (route) => false, // Removes all previous routes
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    
    // Determine the user's name (falls back to 'Stylist' or 'Customer' if not found)
    final String userName = user?.userMetadata?['full_name'] ??
        (widget.isStylist ? 'Stylist' : 'Customer');
        
    // Determine the user's role for display
    final String userRole = widget.isStylist ? 'Stylist' : 'Customer';

    return Drawer(
      backgroundColor: AppColors.black,
      child: Column(
        children: [
          // ---------- HEADER (Profile Picture, Name, Role) ----------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              border: Border(
                bottom: BorderSide(color: AppColors.gold, width: 1.5), // Gold separator line
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Circular Profile Picture container
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 1.5),
                    color: Colors.black,
                  ),
                  clipBehavior: Clip.antiAlias, // Ensures the image doesn't spill out
                  child: CatalogImage(
                    source: _photoUrl,
                    width: 60,
                    height: 60,
                    circular: true,
                  ),
                ),
                const SizedBox(height: 16),
                // User Name
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                // User Role (Customer or Stylist)
                Text(
                  userRole,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // ---------- MENU ITEMS ----------
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                // Home Button (navigates to the respective home screen)
                _DrawerTile(
                  icon: Icons.home_outlined,
                  title: 'Home',
                  onTap: () => _navigateHome(context),
                ),

                // ==========================================
                // CUSTOMER MENU ITEMS
                // ==========================================
                if (!widget.isStylist) ...[
                  _DrawerTile(
                    icon: Icons.content_cut,
                    title: 'Services & Pricing',
                    onTap: () => _navigate(context, const ServicesScreen()),
                  ),
                  _DrawerTile(
                    icon: Icons.calendar_month_outlined,
                    title: 'My Bookings',
                    onTap: () => _navigate(context, const MyBookingsScreen()),
                  ),
                  _DrawerTile(
                    icon: Icons.photo_library_outlined,
                    title: 'Gallery',
                    onTap: () => _navigate(context, const GalleryScreen()),
                  ),
                  _DrawerTile(
                    icon: Icons.groups_outlined,
                    title: 'Our Team',
                    onTap: () => _navigate(context, const OurTeamScreen()),
                  ),
                ],

                // ==========================================
                // STYLIST MENU ITEMS
                // ==========================================
                if (widget.isStylist) ...[
                  _DrawerTile(
                    icon: Icons.calendar_month_outlined,
                    title: 'My Appointments',
                    onTap: () => _navigate(context, const MyAppointmentsScreen()),
                  ),
                  _DrawerTile(
                    icon: Icons.schedule_outlined,
                    title: 'Daily Schedule',
                    onTap: () => _navigate(context, const DailyScheduleScreen()),
                  ),
                  _DrawerTile(
                    icon: Icons.tune_outlined,
                    title: 'Manage Availability',
                    onTap: () => _navigate(context, const ManageAvailabilityScreen()),
                  ),
                  _DrawerTile(
                    icon: Icons.block_outlined,
                    title: 'Blocked Dates',
                    onTap: () => _navigate(context, const BlockedDatesScreen()),
                  ),
                ],

                // ==========================================
                // COMMON MENU ITEMS (For both Customer & Stylist)
                // ==========================================
                _DrawerTile(
                  icon: Icons.location_on_outlined,
                  title: 'Salon Info',
                  onTap: () => _navigate(context, const SalonInfoScreen()),
                ),

                const Divider(color: AppColors.border, height: 30),

                _DrawerTile(
                  icon: Icons.person_outline,
                  title: 'My Profile',
                  onTap: () => _navigate(context, const MyProfileScreen()),
                ),
                _DrawerTile(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () => _navigate(context, const SettingsScreen()),
                ),

                // Logout Button (styled differently in red)
                _DrawerTile(
                  icon: Icons.logout,
                  title: 'Logout',
                  isLogout: true,
                  onTap: () => _navigate(context, const LogoutScreen()),
                ),
              ],
            ),
          ),

          // ---------- FOOTER ----------
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Cutting Edge v1.0.0',
              style: TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

/// A reusable widget for each row/item in the Drawer.
/// It handles the icon, title, and onTap logic, and styles the logout button differently.
class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isLogout; // If true, styles the text and icon red

  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isLogout = false,
  });

  @override
  Widget build(BuildContext context) {
    // Choose color based on whether it's a logout button or a normal menu item
    final color = isLogout ? AppColors.error : Colors.white;

    return ListTile(
      // Icon color changes to red for logout, otherwise gold
      leading: Icon(icon, color: isLogout ? AppColors.error : AppColors.gold, size: 22),
      
      // Title text
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: isLogout ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      
      // Trigger navigation on tap
      onTap: onTap,
      
      // Padding for the list item
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}