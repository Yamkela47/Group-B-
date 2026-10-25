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
import 'app_theme.dart'; // Imports AppColors for consistent styling across the app
import 'badges.dart';    // Imports StatusBadge for displaying transaction status (e.g., Completed, Pending)
import 'cards.dart';     // Imports AppCard, a custom container widget for list items

/// A screen that displays a list of transactions using a TabBar layout.
/// It allows the user to filter between All, Completed, and Pending transactions.
class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

/// We use SingleTickerProviderStateMixin because we are using a TabController,
/// which requires a "Ticker" to animate the tabs.
class _AllTransactionsScreenState extends State<AllTransactionsScreen>
    with SingleTickerProviderStateMixin {
  
  // Initializes a TabController with 3 tabs.
  // 'vsync: this' links the animation to this widget's lifecycle.
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    // Properly dispose of the controller to prevent memory leaks when the screen closes.
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ALL TRANSACTIONS'),
        // Custom back button
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        // The TabBar sits at the bottom of the AppBar.
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.gold, // The underline color of the active tab
          labelColor: AppColors.gold,     // The text color of the active tab
          unselectedLabelColor: AppColors.textSecondary, // The text color of inactive tabs
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
          tabs: const [
            Tab(text: 'ALL'),
            Tab(text: 'COMPLETED'),
            Tab(text: 'PENDING'),
          ],
        ),
      ),
      
      // TabBarView displays the content corresponding to the selected tab.
      body: TabBarView(
        controller: _tab,
        children: [
          // Tab 1: ALL Transactions
          ListView(
            padding: const EdgeInsets.all(20),
            children: const [
              // Hardcoded mock data for demonstration
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
          
          // Tab 2: COMPLETED Transactions (Placeholder)
          const Center(child: Text('No completed transactions',
              style: TextStyle(color: AppColors.textMuted))),
              
          // Tab 3: PENDING Transactions (Placeholder)
          const Center(child: Text('No pending transactions',
              style: TextStyle(color: AppColors.textMuted))),
        ],
      ),
    );
  }
}

/// A custom private widget that builds an individual transaction row.
/// It takes in transaction details as parameters and displays them inside an AppCard.
class _TxRow extends StatelessWidget {
  final String date, service, client, amount, status;
  final Color color; // The color used for the StatusBadge
  
  const _TxRow({
    required this.date, required this.service, required this.client,
    required this.amount, required this.status, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Uses the custom AppCard widget for a consistent look across the app
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10), // Spacing between rows
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Left side of the card: Service, Client, and Date
          // Wrapped in Expanded so it takes up available space and doesn't overflow
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
          
          // Right side of the card: Amount and Status Badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount,
                  style: const TextStyle(
                      color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              // Uses the custom StatusBadge widget
              StatusBadge(text: status, color: color),
            ],
          ),
        ],
      ),
    );
  }
}