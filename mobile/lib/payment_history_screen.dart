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
import 'package:flutter/services.dart'; // For rootBundle
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'app_theme.dart';  
import 'app_bars.dart';   

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('bookings')
          .select('*, services(name, price)')
          .eq('customer_id', user.id)
          .inFilter('status', ['completed', 'confirmed'])
          .order('appointment_date', ascending: false);

      if (!mounted) return;
      setState(() {
        _history = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      debugPrint('Error loading payment history: $e');
    }
  }

  // ==========================================
  // PDF GENERATION LOGIC
  // ==========================================
  Future<void> _generatePdf(Map<String, dynamic> booking) async {
    try {
      // 1. Load the Logo Image
      final ByteData bytes = await rootBundle.load('assets/images/logo.jpeg');
      final Uint8List logoBytes = bytes.buffer.asUint8List();

      // 2. Setup the PDF Document
      final pdf = pw.Document();
      
      // Define Brand Colors
      final gold = PdfColor.fromHex('#E8C158');
      final black = PdfColor.fromHex('#000000');
      final white = PdfColor.fromHex('#FFFFFF');
      final grey = PdfColor.fromHex('#9E9E9E');

      // Generate the receipt details
      final String ref = 'CE-${booking['booking_id'].toString().padLeft(5, '0')}';
      final String date = booking['appointment_date'] ?? 'Unknown';
      final String service = booking['services']?['name'] ?? 'Salon Service';
      final String price = booking['services']?['price']?.toString() ?? 'R0';

      // 3. Add Page to PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                color: black,
                border: pw.Border.all(color: gold, width: 2),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // HEADER: Logo and Brand Name
                  pw.Image(pw.MemoryImage(logoBytes), height: 80, width: 80),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'CUTTING EDGE',
                    style: pw.TextStyle(color: gold, fontSize: 24, fontWeight: pw.FontWeight.bold, letterSpacing: 2),
                  ),
                  pw.Text(
                    'OUR VISION. YOUR STYLE',
                    style: pw.TextStyle(color: gold, fontSize: 10, letterSpacing: 1.5),
                  ),
                  
                  pw.SizedBox(height: 30),
                  pw.Divider(color: gold, thickness: 1),
                  pw.SizedBox(height: 20),

                  // RECEIPT TITLE
                  pw.Text(
                    'OFFICIAL RECEIPT',
                    style: pw.TextStyle(color: white, fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 20),

                  // RECEIPT DETAILS
                  _buildPdfRow('Reference', '#$ref', white, grey),
                  pw.SizedBox(height: 10),
                  _buildPdfRow('Date', date, white, grey),
                  pw.SizedBox(height: 10),
                  _buildPdfRow('Service', service, white, grey),
                  
                  pw.SizedBox(height: 20),
                  pw.Divider(color: gold, thickness: 1),
                  pw.SizedBox(height: 20),

                  // TOTAL
                  _buildPdfRow('TOTAL PAID', price, gold, grey, isBold: true),

                  pw.SizedBox(height: 40),

                  // FOOTER
                  pw.Text(
                    'Thank you for visiting Cutting Edge!',
                    style: pw.TextStyle(color: white, fontSize: 14),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    '10 Melck Street, Pioneer Building, Welkom Central\n078 767 6599',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(color: grey, fontSize: 10),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // 4. Open the Print/Save Dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Receipt_$ref',
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  // Helper widget for the PDF rows
  pw.Widget _buildPdfRow(String label, String value, PdfColor valueColor, PdfColor labelColor, {bool isBold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(color: labelColor, fontSize: 14)),
        pw.Text(
          value, 
          style: pw.TextStyle(
            color: valueColor, 
            fontSize: isBold ? 18 : 14, 
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal
          )
        ),
      ],
    );
  }

  // ==========================================
  // DIALOG PREVIEW
  // ==========================================
  void _showReceipt(Map<String, dynamic> booking) {
    final String ref = 'CE-${booking['booking_id'].toString().padLeft(5, '0')}';
    final String date = booking['appointment_date'] ?? 'Unknown';
    final String service = booking['services']?['name'] ?? 'Salon Service';
    final String price = booking['services']?['price']?.toString() ?? 'R0';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.gold, width: 1.2),
        ),
        title: const Center(
          child: Text('RECEIPT', style: TextStyle(color: AppColors.gold, letterSpacing: 2, fontWeight: FontWeight.bold)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(color: AppColors.border),
            _receiptRow('Reference', '#$ref'),
            _receiptRow('Date', date),
            _receiptRow('Service', service),
            const Divider(color: AppColors.border),
            _receiptRow('Total Paid', price, isBold: true),
            const Divider(color: AppColors.border),
            const SizedBox(height: 10),
            const Text('Thank you for visiting Cutting Edge!', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
        actions: [
          // PDF DOWNLOAD BUTTON
          ElevatedButton.icon(
            onPressed: () => _generatePdf(booking),
            icon: const Icon(Icons.picture_as_pdf, color: Colors.black, size: 18),
            label: const Text('DOWNLOAD PDF', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: TextStyle(color: isBold ? AppColors.gold : Colors.white, fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Payment History'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _history.isEmpty
              ? const Center(child: Text('No payment history yet.', style: TextStyle(color: AppColors.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final b = _history[index];
                    final service = b['services']?['name'] ?? 'Salon Service';
                    final price = b['services']?['price']?.toString() ?? 'R0';
                    final date = b['appointment_date'] ?? 'Unknown Date';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.receipt_long, color: AppColors.gold, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(service, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(date, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(price, style: const TextStyle(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => _showReceipt(b),
                                child: const Text('View Receipt', style: TextStyle(color: AppColors.textMuted, fontSize: 11, decoration: TextDecoration.underline)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}