import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'book_appointment_screen.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final List<_Service> _services = const [
    _Service(
      imagePath: 'assets/images/standard_haircut.jpg',
      name: 'Standard Haircut',
      description: 'Clean. Stylish. Always in trend',
      duration: '40 min',
      price: 'R140',
    ),
    _Service(
      imagePath: 'assets/images/cut_and_dye.jpg',
      name: 'Cut & Dye',
      description: 'A new look with color of your choice',
      duration: '1h 15m',
      price: 'R220',
    ),
    _Service(
      imagePath: 'assets/images/beard_shave.jpg',
      name: 'Beard Shave',
      description: 'Smooth. Sharp. Confident',
      duration: '5 min',
      price: 'R60',
    ),
    _Service(
      imagePath: 'assets/images/hot_towel.jpg',
      name: 'Hot Towel Treatment',
      description: 'Relax and refresh your hair and scalp',
      duration: '40 min',
      price: 'R120',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 90,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: const [
                Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  'Back',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 1.4),
              ),
              child: const Icon(Icons.content_cut,
                  color: AppColors.gold, size: 13),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'CUTTING EDGE',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                Text(
                  'OUR VISION, YOUR STYLE',
                  style: TextStyle(
                    color: AppColors.goldDim,
                    fontSize: 6.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, size: 22),
            onPressed: () {
              // Hook this up to your drawer if needed
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          /* ------------- HEADINGS ------------- */
          const Text(
            'Services & Pricing',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose a service',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),

          /* ------------- CARDS ------------- */
          ..._services.map((service) => _ServiceCard(service: service)),
        ],
      ),
    );
  }
}

/* ===================================================================
   DATA MODEL
   =================================================================== */
class _Service {
  final String imagePath;
  final String name;
  final String description;
  final String duration;
  final String price;

  const _Service({
    required this.imagePath,
    required this.name,
    required this.description,
    required this.duration,
    required this.price,
  });
}

/* ===================================================================
   SERVICE CARD
   =================================================================== */
class _ServiceCard extends StatelessWidget {
  final _Service service;
  const _ServiceCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /* ---------- Image on the left ---------- */
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              service.imagePath,
              width: 84,
              height: 96,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 84,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.image_outlined,
                  color: AppColors.gold,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          /* ---------- Text + button on the right ---------- */
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service name
                Text(
                  service.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),

                // Description
                Text(
                  service.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),

                // Duration + price + Select
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoLine(
                            icon: Icons.access_time,
                            text: service.duration,
                          ),
                          const SizedBox(height: 5),
                          _InfoLine(
                            icon: Icons.local_offer_outlined,
                            text: service.price,
                          ),
                        ],
                      ),
                    ),

                    // Select button
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookAppointmentScreen(
                            service: service.name,
                            price: service.price,
                            showServicePicker: false,
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        minimumSize: const Size(0, 0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Select',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ===================================================================
   INFO LINE  (icon + text)
   =================================================================== */
class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 14),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}