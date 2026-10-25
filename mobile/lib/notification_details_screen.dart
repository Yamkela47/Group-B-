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
import 'app_theme.dart';  // Custom colors and styles
import 'app_bars.dart';   // Custom AppBar widget

/// A screen that displays the full details of a single notification.
/// It receives the notification's title, message, type, and timestamp as parameters.
/// It includes logic to specifically style "apology" notifications differently.
class NotificationDetailsScreen extends StatelessWidget {
  final String title;
  final String message;
  final String? notificationType;
  final DateTime? createdAt;

  const NotificationDetailsScreen({
    super.key,
    required this.title,
    this.message = '',
    this.notificationType,
    this.createdAt,
  });

  /// Checks if the notification is an apology by looking for specific keywords
  /// in the notification type or the title.
  bool get _isApology {
    final text = '${notificationType ?? ''} $title'.toLowerCase();
    return text.contains('apology') || 
           text.contains('apologise') || 
           text.contains('apologize');
  }

  @override
  Widget build(BuildContext context) {
    // Convert the UTC timestamp to the user's local time zone
    final localTime = createdAt?.toLocal();
    
    // Format the timestamp into a readable string (e.g., "24/10/2026 at 14:30")
    final timestamp = localTime == null
        ? null
        : '${localTime.day.toString().padLeft(2, '0')}/'
            '${localTime.month.toString().padLeft(2, '0')}/'
            '${localTime.year} at '
            '${localTime.hour.toString().padLeft(2, '0')}:'
            '${localTime.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: const ScreenAppBar(title: 'Notification Details'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        // The main card container holding the notification details
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Icon and Title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show a heart icon if it's an apology, otherwise a bell icon
                  Icon(
                    _isApology ? Icons.favorite_border : Icons.notifications_active_outlined, 
                    color: AppColors.gold, 
                    size: 26
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title, 
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)
                    ),
                  ),
                ],
              ),
              
              // Timestamp (only renders if createdAt is not null)
              if (timestamp != null) ...[
                const SizedBox(height: 12),
                Text(
                  timestamp, 
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)
                ),
              ],
              
              const SizedBox(height: 18),
              const Divider(color: AppColors.border), // Separator line
              const SizedBox(height: 12),
              
              // The main message body.
              // SelectableText is used so the user can long-press to copy the text.
              SelectableText(
                message.trim().isEmpty ? 'No message provided.' : message,
                style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.6),
              ),
              
              // If it's an apology, add a signature at the bottom
              if (_isApology) ...[
                const SizedBox(height: 24),
                const Text(
                  'Cutting Edge Salon', 
                  style: TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.bold)
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}