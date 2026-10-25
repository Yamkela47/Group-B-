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
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';  // Custom colors and styles
import 'app_bars.dart';   // Custom AppBar widget
import 'buttons.dart';    // Custom GoldButton widget
import 'cards.dart';      // Custom AppCard and SectionHeading widgets

/// A screen that provides information about the salon's location, contact details, 
/// operating hours, and links to their social media profiles.
class SalonInfoScreen extends StatelessWidget {
  const SalonInfoScreen({super.key});

  // =================================================================
  // GOOGLE MAPS LAUNCH LOGIC
  // =================================================================
  /// Opens Google Maps using an external application with the salon's address.
  Future<void> _openGoogleMaps(BuildContext context) async {
    const String address = 'pioneer building, Melck St, Welkom Central, Welkom, 9459';
    // Construct the Google Maps URL
    final Uri mapUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');

    try {
      // Attempt to launch the URL. LaunchMode.externalApplication forces it to open in the Google Maps app or browser.
      if (!await launchUrl(mapUrl, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch map');
      }
    } catch (e) {
      if (!context.mounted) return;
      // Show an error if the device doesn't have an app to handle the link
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Google Maps. Please check if you have a browser or Maps app installed.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // =================================================================
  // SOCIAL MEDIA LAUNCH LOGIC
  // =================================================================
  /// Opens a given social media URL in an external application (e.g., Instagram app or browser).
  Future<void> _launchSocial(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch URL');
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the link.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- SOCIAL MEDIA LINKS ---
    const String instagramUrl = 'https://www.instagram.com/_thecuttingedgebarbershop/?hl=en';
    const String facebookUrl = 'https://www.facebook.com/p/Cutting-Edge-100083283944909/';
    const String tiktokUrl = 'https://www.tiktok.com/@cutting_edge057?_r=1&_t=ZS-9Aln9ZjtPg0';

    return Scaffold(
      appBar: const ScreenAppBar(title: 'Salon Information'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            
            // ==========================================
            // FAKE MAP PREVIEW (CLICKABLE)
            // ==========================================
            GestureDetector(
              onTap: () => _openGoogleMaps(context),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Stack(
                  children: [
                    // Renders a custom drawn grid to look like a map
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CustomPaint(painter: _MapPainter()),
                      ),
                    ),
                    // A pin icon in the center
                    const Center(
                      child: Icon(Icons.location_on, color: AppColors.gold, size: 40),
                    ),
                    // A small "TAP TO OPEN" badge in the top right corner
                    Positioned(
                      right: 12, top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                        ),
                        child: const Text('TAP TO OPEN',
                            style: TextStyle(
                                color: AppColors.gold, fontSize: 10,
                                letterSpacing: 1.2, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ==========================================
            // INFO ROWS
            // ==========================================
            const _InfoRow(icon: Icons.location_on_outlined, title: 'Address',
                value: '10 Melck Street, Pioneer Building, Welkom Central'),
            const _InfoRow(icon: Icons.phone_outlined, title: 'Phone', value: '078 767 6599'),
            const _InfoRow(icon: Icons.mail_outline, title: 'Email', value: 'cuttinged@88@gmail.com'),
            const _InfoRow(icon: Icons.access_time, title: 'Hours',
                value: 'Mon–Fri 9:00 – 18:00\nSat 8:30 – 17:00\nSun 8:30 – 13:00'),
            
            const SizedBox(height: 16),

            // ==========================================
            // BUTTON TO OPEN MAPS
            // ==========================================
            GoldButton(
              label: 'Open in Google Maps', 
              icon: Icons.map_outlined, 
              onPressed: () => _openGoogleMaps(context),
            ),
            
            const SizedBox(height: 20),
            const SectionHeading(text: 'Follow Us'),
            
            // ==========================================
            // SOCIAL MEDIA CHIPS
            // ==========================================
            Row(
              children: [
                _SocialChip(
                  icon: Icons.camera_alt_outlined, 
                  label: 'Instagram',
                  onTap: () => _launchSocial(context, instagramUrl),
                ),
                const SizedBox(width: 8),
                _SocialChip(
                  icon: Icons.facebook, 
                  label: 'Facebook',
                  onTap: () => _launchSocial(context, facebookUrl),
                ),
                const SizedBox(width: 8),
                _SocialChip(
                  icon: Icons.music_note, 
                  label: 'TikTok',
                  onTap: () => _launchSocial(context, tiktokUrl),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// MAP DRAWING (Background lines)
// ==========================================
/// A custom painter that draws a simple grid to simulate a stylized map background.
class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fill the background with a dark grey
    final bg = Paint()..color = const Color(0xFF141414);
    canvas.drawRect(Offset.zero & size, bg);
    
    // Set up the paint for the "roads"
    final road = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;
      
    // Draw vertical lines (roads)
    for (double x = 0; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), road);
    }
    // Draw horizontal lines (roads)
    for (double y = 0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), road);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================
// INFO ROW WIDGET
// ==========================================
/// A reusable widget for displaying a single piece of contact information 
/// (e.g., Address, Phone, Email) with an icon.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title, value;
  const _InfoRow({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.gold, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Uppercase label
                  Text(title.toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 10,
                          letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  // The actual value text
                  Text(value,
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// SOCIAL CHIP WIDGET (Clickable)
// ==========================================
/// A reusable widget for the clickable social media buttons at the bottom of the screen.
class _SocialChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SocialChip({
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.gold, size: 18),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
            ],
          ),
        ),
      ),
    );
  }
}