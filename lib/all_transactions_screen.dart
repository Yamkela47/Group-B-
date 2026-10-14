import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'badges.dart';
import 'cards.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});
  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen>
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
        title: const Text('ALL TRANSACTIONS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
          tabs: const [
            Tab(text: 'ALL'),
            Tab(text: 'COMPLETED'),
            Tab(text: 'PENDING'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: const [
              _TxRow(date: '21 Sep 2026', service: 'Cut & Dye',
                  client: 'Lethabo Kgame', amount: 'R 350',
                  status: 'Completed', color: AppColors.success),
              _TxRow(date: '21 Sep 2026', service: 'Standard Haircut',
                  client: 'Thandi Nkosi', amount: 'R 120',
                  status: 'Completed', color: AppColors.success),
              _TxRow(date: '20 Sep 2026', service: 'Beard Shave',
                  client: 'Bongani Zulu', amount: 'R 60',
                  status: 'Pending', color: AppColors.gold),
              _TxRow(date: '19 Sep 2026', service: 'Hot Towel Treatment',
                  client: 'Zanele M', amount: 'R 90',
                  status: 'Completed', color: AppColors.success),
            ],
          ),
          const Center(child: Text('No completed transactions',
              style: TextStyle(color: AppColors.textMuted))),
          const Center(child: Text('No pending transactions',
              style: TextStyle(color: AppColors.textMuted))),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final String date, service, client, amount, status;
  final Color color;
  const _TxRow({
    required this.date, required this.service, required this.client,
    required this.amount, required this.status, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('$client · $date',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount,
                  style: const TextStyle(
                      color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              StatusBadge(text: status, color: color),
            ],
          ),
        ],
      ),
    );
  }
}