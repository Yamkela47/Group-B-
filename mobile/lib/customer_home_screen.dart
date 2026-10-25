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
import 'app_theme.dart';            // Custom colors and styles
import 'app_bars.dart';             // Custom AppBar
import 'app_drawer.dart';           // Side navigation drawer
import 'bottom_nav.dart';           // Custom bottom navigation bar
import 'notifications_screen.dart'; // Screen to view all notifications
import 'my_profile_screen.dart';    // Customer profile screen
import 'services_screen.dart';      // Screen showing all services
import 'my_bookings_screen.dart';   // Screen showing customer's bookings
import 'salon_info_screen.dart';    // Screen with salon location/details
import 'our_team_screen.dart';      // Screen showing the stylists
import 'notification_service.dart'; // Service for handling realtime notifications
import 'booking_gate.dart';         // Utility to prevent double bookings
import 'catalog_image.dart';        // Custom image widget with error handling
import 'book_appointment_screen.dart'; // Added this import to handle booking navigation

/// The main dashboard screen for customers after logging in.
/// It provides quick access to services, stylists, bookings, and special offers.
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});
  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  // State to keep track of the currently selected bottom navigation tab
  int _nav = 0;
  
  // Instance of the notification service to listen for real-time updates
  late final NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    // Initialize the notification service when the screen loads
    _notificationService = NotificationService(context);
    _notificationService.initialize();
  }

  @override
  void dispose() {
    // Clean up the notification service when leaving the screen to prevent memory leaks
    _notificationService.dispose();
    super.dispose();
  }

  /// A helper method to navigate to the Services screen.
  /// This is used by multiple buttons on the home screen.
  void _openServices() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ServicesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The side navigation drawer for the customer role
      drawer: const AppDrawer(isStylist: false),
      
      // Custom AppBar with a notification bell action
      appBar: MainAppBar(
        onBell: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        ),
      ),
      
      // The main body of the screen, wrapped in a scroll view
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card with a "Book Now" button
            _WelcomeCard(
              // Tapping "Book Now" triggers the BookingGate to check for existing appointments
              onBookNow: () => BookingGate.attemptBooking(context),
            ),
            const SizedBox(height: 16),
            
            // The dynamic slideshow for promotions
            const _SpecialOfferBanner(),
            const SizedBox(height: 24),
            
            // Section Title for Quick Actions
            const _SectionTitle(title: 'Quick Actions'),
            const SizedBox(height: 12),
            
            // Row of 4 quick action buttons
            Row(
              children: [
                _QuickAction(
                  icon: Icons.content_cut,
                  label: 'Services',
                  onTap: _openServices,
                ),
                const SizedBox(width: 8),
                _QuickAction(
                  icon: Icons.groups_outlined,
                  label: 'Team',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OurTeamScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                _QuickAction(
                  icon: Icons.calendar_month_outlined,
                  label: 'Bookings',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                _QuickAction(
                  icon: Icons.location_on_outlined,
                  label: 'Find Us',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SalonInfoScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Row containing the title for Popular Services and a "View All" button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionTitle(title: 'Popular Services'),
                TextButton(
                  onPressed: _openServices,
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            
            // Horizontal list of popular services fetched from the database
            _PopularServicesRow(onCardTap: _openServices),
          ],
        ),
      ),
      
      // Custom bottom navigation bar
      bottomNavigationBar: BottomNav(
        index: _nav,
        onChanged: (i) {
          // Handle navigation based on the selected tab index
          if (i == 1) {
            // Opens services
            _openServices();
          } else if (i == 2) {
            // Opens bookings
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MyBookingsScreen()));
          } else if (i == 3) {
            // Opens profile
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MyProfileScreen()));
          } else {
            // If Home is selected, just update the nav state
            setState(() => _nav = i);
          }
        },
        items: const [
          BottomNavItem(Icons.home_outlined, 'Home'),
          BottomNavItem(Icons.content_cut, 'Service'),
          BottomNavItem(Icons.calendar_month_outlined, 'Bookings'),
          BottomNavItem(Icons.person_outline, 'Profile'),
        ],
      ),
    );
  }
}

/* ============================================================
   DYNAMIC SPECIAL OFFER SLIDESHOW
   ============================================================ */
/// A stateful widget that fetches active promotions from the database
/// and displays them in an auto-rotating carousel.
class _SpecialOfferBanner extends StatefulWidget {
  const _SpecialOfferBanner();

  @override
  State<_SpecialOfferBanner> createState() => _SpecialOfferBannerState();
}

class _SpecialOfferBannerState extends State<_SpecialOfferBanner> {
  final _supabase = Supabase.instance.client;
  late final PageController _controller;
  
  // Timer to handle the auto-rotation of the slideshow
  Timer? _timer;
  int _currentPage = 0;

  bool _isLoading = true;
  List<Map<String, dynamic>> _promotions = [];

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _fetchPromotions();
  }

  /// Fetches active promotions from the Supabase 'promotions' table.
  Future<void> _fetchPromotions() async {
    try {
      final response = await _supabase
          .from('promotions')
          .select()
          .eq('active', true)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _promotions = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });

      // Only start auto-rotating if there are multiple promotions
      if (_promotions.isNotEmpty) {
        _startAutoRotate();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('Error fetching promotions: $e');
    }
  }

  /// Sets up a timer to automatically move to the next slide every 4 seconds.
  void _startAutoRotate() {
    _timer?.cancel(); // Cancel any existing timer
    if (_promotions.length <= 1) return;

    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      
      // Calculate the next page index, looping back to 0 if at the end
      final next = (_currentPage + 1) % _promotions.length;
      
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    // Clean up timer and controller to prevent memory leaks
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 170,
        child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    if (_promotions.isEmpty) {
      return Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'No active promotions at the moment.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: [
        // The PageView for the slideshow
        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _controller,
            itemCount: _promotions.length,
            onPageChanged: (i) {
              setState(() => _currentPage = i);
              _startAutoRotate(); // Reset the timer when the user manually swipes
            },
            itemBuilder: (_, i) => _PromoSlideCard(promo: _promotions[i]),
          ),
        ),
        const SizedBox(height: 14),
        
        // Pagination dots at the bottom
        if (_promotions.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_promotions.length, (i) {
              final active = i == _currentPage;
              return GestureDetector(
                onTap: () {
                  _controller.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                  );
                  _startAutoRotate();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? AppColors.gold : AppColors.textMuted,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}

/* ============================================================
   SINGLE PROMO SLIDE
   ============================================================ */
/// A widget representing a single slide in the special offer banner.
class _PromoSlideCard extends StatelessWidget {
  final Map<String, dynamic> promo;
  const _PromoSlideCard({required this.promo});

  @override
  Widget build(BuildContext context) {
    final String title = promo['title'] ?? 'SPECIAL OFFER';
    final String discountAmount = promo['discount_amount']?.toString() ?? '';
    final String discountType = promo['discount_type'] ?? '';

    // Determine the text to display for the discount
    final String discountText = discountAmount.isNotEmpty
        ? (discountType.toLowerCase() == 'percentage'
            ? '$discountAmount% OFF'
            : 'R$discountAmount OFF')
        : 'Limited Time Offer';

    final String? imageUrl = promo['image_url'];

    return GestureDetector(
      // Gate the promotion click to ensure the user doesn't have an active booking
      onTap: () => BookingGate.checkAndProceedToBook(
        context,
        BookAppointmentScreen(
          service: title, // Using Promo Title as Service Name
          price: discountText, // Using Discount Text as Price
          serviceId: 0, // 0 indicates it's a promo
          durationMinutes: 30, // Default duration for promos
          serviceImagePath: imageUrl ?? '',
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold, width: 1.2),
        ),
        child: Row(
          children: [
            // Left side: Text details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'PROMOTION',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    discountText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            
            // Right side: Image and limited time badge
            Stack(
              alignment: Alignment.center,
              children: [
                ClipOval(
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
                Positioned(
                  right: -8,
                  child: Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        'TAP TO\nBOOK',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Fallback UI if the promotion image fails to load.
  Widget _buildPlaceholder() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: const Icon(
        Icons.local_offer_outlined,
        color: AppColors.gold,
        size: 34,
      ),
    );
  }
}

/* ============================================================
   WELCOME CARD
   ============================================================ */
/// A welcoming card with a quick "Book Now" button and the salon logo.
class _WelcomeCard extends StatelessWidget {
  final VoidCallback onBookNow;
  const _WelcomeCard({required this.onBookNow});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold, width: 1.2),
      ),
      child: Row(
        children: [
          // Left side: Text and Book Now button
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome Back!',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Beauty. Style. Confidence',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'All in one place',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onBookNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    minimumSize: const Size(0, 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Book Now',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          // Right side: Logo image
          ClipOval(
            child: Image.asset(
              'assets/images/logo.jpeg',
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const _ImagePlaceholder(
                icon: Icons.content_cut,
                width: 100,
                height: 100,
                circular: true,
                label: 'welcome\nphoto',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   IMAGE PLACEHOLDER
   ============================================================ */
/// A reusable placeholder widget to display if an image fails to load.
class _ImagePlaceholder extends StatelessWidget {
  final IconData icon;
  final double width;
  final double height;
  final bool circular;
  final String? label;

  const _ImagePlaceholder({
    required this.icon,
    required this.width,
    required this.height,
    this.circular = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.gold, size: width * 0.28),
          if (label != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/* ============================================================
   SECTION TITLE
   ============================================================ */
/// A standardized widget for rendering section headings on the home screen.
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/* ============================================================
   QUICK ACTION
   ============================================================ */
/// A tappable card used in the "Quick Actions" row.
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold, width: 1.2),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.gold, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ============================================================
   POPULAR SERVICES ROW (Keyword Matching)
   ============================================================ */
/// Fetches all active services, filters them by specific keywords, 
/// and displays them in a horizontal scrolling list.
class _PopularServicesRow extends StatefulWidget {
  final VoidCallback onCardTap;
  const _PopularServicesRow({required this.onCardTap});

  @override
  State<_PopularServicesRow> createState() => _PopularServicesRowState();
}

class _PopularServicesRowState extends State<_PopularServicesRow> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _services = [];

  @override
  void initState() {
    super.initState();
    _fetchPopularServices();
  }

  Future<void> _fetchPopularServices() async {
    try {
      final data = await _supabase
          .from('services')
          .select('name, price, image_url')
          .eq('active', true);

      if (!mounted) return;

      final allServices = List<Map<String, dynamic>>.from(data);

      // Keywords used to determine if a service is "popular"
      final keywords = [
        'haircut',
        'cut & dye',
        'cut and dye',
        'fiber',
        'bleach'
      ];
      List<Map<String, dynamic>> filtered = [];

      // Loop through keywords and services to find matches
      for (var kw in keywords) {
        for (var service in allServices) {
          final name = (service['name'] ?? '').toString().toLowerCase();
          // Add to list if it matches the keyword and isn't already in the list
          if (name.contains(kw) &&
              !filtered.any((s) => s['name'] == service['name'])) {
            filtered.add(service);
          }
        }
      }

      setState(() {
        _services = filtered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      debugPrint('Error fetching popular services: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child:
            Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    if (_services.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No popular services available right now.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _services.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final item = _services[i];
          final String name = item['name'] ?? 'Service';
          final num price = item['price'] ?? 0;

          return _PopularCard(
            title: name,
            price: 'R${price.toStringAsFixed(0)}',
            imageUrl: item['image_url'],
            onTap: widget.onCardTap,
          );
        },
      ),
    );
  }
}

/// The card widget representing a single popular service.
class _PopularCard extends StatelessWidget {
  final String title;
  final String price;
  final String? imageUrl;
  final VoidCallback onTap;

  const _PopularCard({
    required this.title,
    required this.price,
    required this.onTap,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
              child: CatalogImage(
                source: imageUrl,
                width: 150,
                height: 130,
              ),
            ),
            
            // Service Details (Name & Price)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}