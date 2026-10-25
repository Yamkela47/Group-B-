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

import 'catalog_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';                 // Custom colors and styles
import 'buttons.dart';                  // Custom GoldButton widget
import 'edit_profile_screen.dart';      // Screen to edit the profile
import 'settings_screen.dart';          // Screen for account settings
import 'notifications_screen.dart';     // Screen for viewing notifications
import 'my_bookings_screen.dart';       // Screen for viewing bookings
import 'payment_history_screen.dart';   // Screen for viewing payment history

/// A screen that displays the user's profile information.
/// It fetches data from both the Supabase Auth metadata and the 'profiles' database table.
/// It is designed to handle both Customer and Stylist roles.
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});
  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  // State variables for UI rendering
  bool _loading = true;
  String _fullName = 'Loading...';
  String? _photoUrl;
  String _email = 'Loading...';
  String _phone = 'Loading...';
  String _dob = 'Not set';
  String _firstName = '';
  String _surname = '';
  String _bio = '';
  String _role = 'Customer';
  String _specialization = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // We use didChangeDependencies so the profile reloads when the user
    // navigates back from the EditProfileScreen.
    _loadProfile();
  }

  /// Fetches the current user's profile data from Supabase.
  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // 1. Extract basic data from the Auth metadata
    final email = user.email ?? 'No email';
    final fullName = user.userMetadata?['full_name'] ?? 'Customer Name';
    final phone = user.userMetadata?['phone'] ?? 'No phone number';
    final dob = user.userMetadata?['date_of_birth'] ?? 'Not set';
    
    String? photoUrl;
    String bio = '';
    String role = 'Customer';
    String specialization = '';

    try {
      // 2. Fetch additional data from the custom 'profiles' table
      final profile = await Supabase.instance.client.from('profiles')
          .select('photo_url, bio, role, specialization')
          .eq('id', user.id)
          .maybeSingle();
          
      photoUrl = profile?['photo_url']?.toString();
      bio = profile?['bio']?.toString() ?? '';
      role = profile?['role']?.toString() ?? 'Customer';
      specialization = profile?['specialization']?.toString() ?? '';
    } catch (e) {
      debugPrint('Profile data unavailable: $e');
    } 

    // 3. Split the full name into first name and surname for the table display
    final nameParts = fullName.trim().split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final surname = nameParts.length > 1 ? nameParts.skip(1).join(' ') : '';

    // 4. Update the UI state
    if (mounted) {
      setState(() {
        _photoUrl = photoUrl;
        _email = email;
        _fullName = fullName;
        _phone = phone;
        _dob = dob;
        _firstName = firstName;
        _surname = surname;
        _bio = bio;
        _role = role;
        _specialization = specialization;
        _loading = false;
      });
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
          'Profile',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ==========================================
                // HEADER (Profile Picture & Name)
                // ==========================================
                Center(
                  child: Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold.withValues(alpha: 0.12),
                      border: Border.all(color: AppColors.gold, width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CatalogImage(source: _photoUrl, width: 90, height: 90, circular: true),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _fullName, 
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  _role,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 30),

                // ==========================================
                // INFO TABLE CARD
                // ==========================================
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  // Using a Table widget to align labels and values perfectly
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.2), // Label column
                      1: FlexColumnWidth(1.8), // Value column
                    },
                    children: [
                      _buildTableRow(Icons.person_outline, 'Name', _firstName),
                      _buildTableRow(Icons.person_outline, 'Surname', _surname.isEmpty ? '-' : _surname),
                      _buildTableRow(Icons.mail_outline, 'Email', _email),
                      _buildTableRow(Icons.phone_outlined, 'Phone', _phone),
                      _buildTableRow(Icons.cake_outlined, 'Date of Birth', _dob),
                      // Only show specialization if the user is a stylist and it exists
                      if (_specialization.isNotEmpty) _buildTableRow(Icons.workspace_premium_outlined, 'Specialization', _specialization),
                    ],
                  ),
                ),

                // ==========================================
                // BIO SECTION (Only visible if bio is not empty)
                // ==========================================
                if (_bio.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text('ABOUT ME', style: TextStyle(color: AppColors.gold, fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(_bio, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.5)),
                  ),
                ],

                const SizedBox(height: 24),

                // ==========================================
                // MENU ITEMS CARD
                // ==========================================
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _MenuRow(
                        icon: Icons.calendar_month_outlined,
                        title: 'My Bookings',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen())),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _MenuRow(
                        icon: Icons.receipt_long_outlined,
                        title: 'Payment History',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentHistoryScreen())),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _MenuRow(
                        icon: Icons.settings_outlined,
                        title: 'Account Settings',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _MenuRow(
                        icon: Icons.notifications_none,
                        title: 'Notifications',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // ==========================================
                // EDIT PROFILE BUTTON
                // ==========================================
                GoldButton(
                  label: 'Edit Profile',
                  onPressed: () async {
                    // Navigate to edit screen and wait for it to close.
                    // Then, reload the profile data to show any changes.
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                    _loadProfile(); 
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  /// Helper widget to build a single row inside the Info Table.
  TableRow _buildTableRow(IconData icon, String label, String value) {
    return TableRow(
      children: [
        // Left Column (Icon + Label)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ),
            ],
          ),
        ),
        // Right Column (Value)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            value, 
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// A reusable widget for the clickable menu items at the bottom of the profile.
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  
  const _MenuRow({required this.icon, required this.title, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.gold, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}