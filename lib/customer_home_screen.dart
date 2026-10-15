import 'dart:async';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_bars.dart';
import 'bottom_nav.dart';
import 'notifications_screen.dart';
import 'my_profile_screen.dart';
import 'services_screen.dart';
import 'my_bookings_screen.dart';
import 'salon_info_screen.dart';
import 'our_team_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});
  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _nav = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MainAppBar(
        onBell: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /* 1. WELCOME CARD */
            const _WelcomeCard(),
            const SizedBox(height: 16),

            /* 2. SLIDESHOW */
            const _SpecialOfferBanner(),
            const SizedBox(height: 24),

            /* 3. QUICK ACTIONS */
            const _SectionTitle(title: 'Quick Actions'),
            const SizedBox(height: 12),
            Row(
              children: [
                _QuickAction(
                  icon: Icons.content_cut,
                  label: 'Services',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ServicesScreen()),
                  ),
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

            /* 4. POPULAR SERVICES */
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionTitle(title: 'Popular Services'),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ServicesScreen()),
                  ),
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
            const _PopularServicesRow(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        index: _nav,
        onChanged: (i) {
          if (i == 1) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ServicesScreen()));
          } else if (i == 2) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MyBookingsScreen()));
          } else if (i == 3) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MyProfileScreen()));
          } else {
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
   IMAGE PLACEHOLDER
   ============================================================ */
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
   WELCOME CARD
   ============================================================ */
class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

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
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ServicesScreen()),
                  ),
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
          ClipOval(
            child: Image.asset(
              'assets/images/welcome_photo.jpg',
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
   SPECIAL OFFER SLIDESHOW
   ============================================================ */
class _SpecialOfferBanner extends StatefulWidget {
  const _SpecialOfferBanner();

  @override
  State<_SpecialOfferBanner> createState() => _SpecialOfferBannerState();
}

class _SpecialOfferBannerState extends State<_SpecialOfferBanner> {
  late final PageController _controller;
  Timer? _timer;
  int _currentPage = 0;

  static const List<_PromoSlide> _slides = [
    _PromoSlide(
      badge: 'SPECIAL OFFER',
      title: '20% OFF',
      subtitle: 'Royal Prince Combo',
      imagePath: 'assets/images/offer_photo.jpg',
      icon: Icons.local_offer_outlined,
    ),
    _PromoSlide(
      badge: 'FLAGSHIP SERVICE',
      title: 'CUT & DYE',
      subtitle: 'From R220 · 1h 15min',
      imagePath: 'assets/images/cut_and_dye.jpg',
      icon: Icons.color_lens_outlined,
    ),
    _PromoSlide(
      badge: 'THIS MONTH ONLY',
      title: 'HOT TOWEL',
      subtitle: 'Free with any haircut',
      imagePath: 'assets/images/hot_towel.jpg',
      icon: Icons.spa_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAutoRotate();
  }

  void _startAutoRotate() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_currentPage + 1) % _slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (i) {
              setState(() => _currentPage = i);
              _startAutoRotate();
            },
            itemBuilder: (_, i) => _PromoSlideCard(slide: _slides[i]),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slides.length, (i) {
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
class _PromoSlideCard extends StatelessWidget {
  final _PromoSlide slide;
  const _PromoSlideCard({required this.slide});

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  slide.badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  slide.title,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  slide.subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              ClipOval(
                child: Image.asset(
                  slide.imagePath,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
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
                    child: Icon(
                      slide.icon,
                      color: AppColors.gold,
                      size: 34,
                    ),
                  ),
                ),
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
                      'THIS\nMONTH\nONLY',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 9,
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
    );
  }
}

/* ============================================================
   SLIDE DATA MODEL
   ============================================================ */
class _PromoSlide {
  final String badge;
  final String title;
  final String subtitle;
  final String imagePath;
  final IconData icon;

  const _PromoSlide({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.icon,
  });
}

/* ============================================================
   QUICK ACTION
   ============================================================ */
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
   POPULAR SERVICES ROW
   ============================================================ */
class _PopularServicesRow extends StatelessWidget {
  const _PopularServicesRow();

  @override
  Widget build(BuildContext context) {
    final items = const [
      _PopularItem(
        imagePath: 'assets/images/popular_haircuts.jpg',
        title: 'Haircuts',
        price: 'From R140',
      ),
      _PopularItem(
        imagePath: 'assets/images/popular_cut_dye.jpg',
        title: 'Cut & Dye',
        price: 'From R220',
      ),
      _PopularItem(
        imagePath: 'assets/images/popular_hot_towel.jpg',
        title: 'Hot Towel',
        price: 'From R120',
      ),
    ];

    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _PopularCard(item: items[i]),
      ),
    );
  }
}

class _PopularItem {
  final String imagePath;
  final String title;
  final String price;
  const _PopularItem({
    required this.imagePath,
    required this.title,
    required this.price,
  });
}

class _PopularCard extends StatelessWidget {
  final _PopularItem item;
  const _PopularCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ServicesScreen()),
      ),
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
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
              child: Image.asset(
                item.imagePath,
                width: 150,
                height: 130,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => _ImagePlaceholder(
                  icon: Icons.image_outlined,
                  width: 150,
                  height: 130,
                  label: item.title,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.price,
                    style: const TextStyle(
                      color: Colors.white,
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