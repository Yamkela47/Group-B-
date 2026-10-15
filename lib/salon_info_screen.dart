import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_bars.dart';
import 'buttons.dart';
import 'cards.dart';

class SalonInfoScreen extends StatelessWidget {
  const SalonInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Salon Information'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CustomPaint(painter: _MapPainter()),
                    ),
                  ),
                  const Center(child: Icon(Icons.location_on, color: AppColors.gold, size: 40)),
                  Positioned(
                    right: 12, top: 12,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('MAP',
                          style: TextStyle(
                              color: Colors.white, fontSize: 10,
                              letterSpacing: 1.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _InfoRow(icon: Icons.location_on_outlined, title: 'Address',
                value: '10 Melck Street, Pioneer Building, Welkom Central'),
            const _InfoRow(icon: Icons.phone_outlined, title: 'Phone', value: '078 767 6599'),
            const _InfoRow(icon: Icons.mail_outline, title: 'Email', value: 'cuttinged@88@gmail.com'),
            const _InfoRow(icon: Icons.access_time, title: 'Hours',
                value: 'Mon–Fri 9:00 – 18:00\nSat 8:30 – 17:00\nSun 8:30 – 13:00'),
            const SizedBox(height: 16),
            GoldButton(label: 'Open in Google Maps', icon: Icons.map_outlined, onPressed: () {}),
            const SizedBox(height: 20),
            const SectionHeading(text: 'Follow Us'),
            Row(
              children: const [
                _SocialChip(icon: Icons.camera_alt_outlined, label: 'Instagram'),
                SizedBox(width: 8),
                _SocialChip(icon: Icons.facebook, label: 'Facebook'),
                SizedBox(width: 8),
                _SocialChip(icon: Icons.music_note, label: 'TikTok'),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF141414);
    canvas.drawRect(Offset.zero & size, bg);
    final road = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;
    for (double x = 0; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), road);
    }
    for (double y = 0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), road);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
                  Text(title.toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 10,
                          letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
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

class _SocialChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SocialChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
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
    );
  }
}