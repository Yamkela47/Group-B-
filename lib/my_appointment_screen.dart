import 'package:flutter/material.dart';
import 'app_theme.dart';      // AppColors
import 'badges.dart';        // StatusBadge
import 'cards.dart';         // AppCard
import 'appointment_details_screen.dart'; // navigation target

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MY APPOINTMENTS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
          tabs: const [
            Tab(text: 'UPCOMING'),
            Tab(text: 'COMPLETED'),
            Tab(text: 'CANCELLED'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          /* ---------------------------------------- UPCOMING TAB */
          ListView(
            padding: const EdgeInsets.all(20),
            children: const [
              _ApptCard(
                client: 'Lethabo Kgame',
                service: 'Cut & Dye',
                time: 'Mon, 21 Sep · 10:30',
                status: 'Confirmed',
                statusColor: AppColors.success,
              ),
              _ApptCard(
                client: 'Thandi Nkosi',
                service: 'Standard Haircut',
                time: 'Mon, 21 Sep · 11:45',
                status: 'Confirmed',
                statusColor: AppColors.success,
              ),
              _ApptCard(
                client: 'Bongani Zulu',
                service: 'Beard Shave',
                time: 'Mon, 21 Sep · 14:00',
                status: 'Pending',
                statusColor: AppColors.gold,
              ),
            ],
          ),

          /* --------------------------------------- COMPLETED TAB */
          const Center(
            child: Text(
              'No completed appointments',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),

          /* --------------------------------------- CANCELLED TAB */
          const Center(
            child: Text(
              'No cancelled appointments',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------ Appointment card */

class _ApptCard extends StatelessWidget {
  final String client;
  final String service;
  final String time;
  final String status;
  final Color statusColor;

  const _ApptCard({
    required this.client,
    required this.service,
    required this.time,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /* Client name + status badge */
          Row(
            children: [
              Expanded(
                child: Text(
                  client,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusBadge(text: status, color: statusColor),
            ],
          ),
          const SizedBox(height: 6),

          /* Service name (gold) */
          Text(
            service,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),

          /* Time row */
          Row(
            children: [
              const Icon(
                Icons.access_time,
                color: AppColors.textSecondary,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                time,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          /* View details button */
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AppointmentDetailsScreen(),
                ),
              ),
              child: const Text(
                'View Details',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}