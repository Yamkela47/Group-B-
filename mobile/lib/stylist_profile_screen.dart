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
import 'edit_profile_screen.dart';   
import 'my_appointment_screen.dart'; 
import 'settings_screen.dart';       
import 'catalog_image.dart';         
import 'package:intl/intl.dart';     

class StylistProfileScreen extends StatefulWidget {
  const StylistProfileScreen({super.key});

  @override
  State<StylistProfileScreen> createState() => _StylistProfileScreenState();
}

class _StylistProfileScreenState extends State<StylistProfileScreen> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  Map<String, dynamic>? _profile;
  dynamic _stylistId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final profileData = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final stylistData = await _supabase
          .from('stylists')
          .select('stylist_id')
          .eq('profile_id', user.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _profile = profileData;
        _stylistId = stylistData?['stylist_id'];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error loading profile: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  // ==========================================
  // MONTHLY EARNINGS & REPORT LOGIC
  // ==========================================
  Future<void> _showMonthlyEarningsReport() async {
    if (_stylistId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Stylist profile not found.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
    );

    try {
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0); 

      final String startStr = '${firstDayOfMonth.year}-${firstDayOfMonth.month.toString().padLeft(2, '0')}-01';
      final String endStr = '${lastDayOfMonth.year}-${lastDayOfMonth.month.toString().padLeft(2, '0')}-${lastDayOfMonth.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('bookings')
          .select('booking_id, customer_id, appointment_date, payment_method_id, final_price, services(name, price)')
          .eq('stylist_id', _stylistId)
          .gte('appointment_date', startStr)
          .lte('appointment_date', endStr)
          .eq('status', 'completed')
          .order('appointment_date', ascending: false);

      final List<Map<String, dynamic>> bookings = List<Map<String, dynamic>>.from(response);

      final customerIds = bookings.map((b) => b['customer_id']).where((id) => id != null).toSet().toList();
      Map<String, String> customerNames = {};

      if (customerIds.isNotEmpty) {
        final profiles = await _supabase
            .from('profiles')
            .select('id, full_name')
            .inFilter('id', customerIds);
            
        for (var p in profiles) {
          customerNames[p['id']] = p['full_name'] ?? 'Unknown Client';
        }
      }

      double totalEarnings = 0.0;
      double totalCash = 0.0;
      double totalCard = 0.0;

      for (var b in bookings) {
        final dynamic rawPrice = b['final_price'] ?? b['services']?['price'] ?? '0';
        final double price = double.tryParse(rawPrice.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        
        totalEarnings += price;
        
        final int methodId = b['payment_method_id'] ?? 1;
        if (methodId == 1) {
          totalCash += price;
        } else {
          totalCard += price;
        }

        b['customer_name'] = customerNames[b['customer_id']] ?? 'Unknown Client';
      }

      if (!mounted) return;
      Navigator.pop(context); // Close loading spinner

      // Show the Report Bottom Sheet
      _showReportBottomSheet(now, totalEarnings, totalCash, totalCard, bookings);

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close spinner
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error calculating earnings: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  void _showReportBottomSheet(DateTime now, double total, double cash, double card, List<Map<String, dynamic>> bookings) {
    final String stylistName = _profile?['full_name'] ?? 'Stylist';
    final String monthYear = DateFormat('MMMM yyyy').format(now);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppColors.gold, width: 1.5),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Container(
                          width: 40, height: 4, 
                          decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2))
                        ),
                        const SizedBox(height: 16),
                        const Text('MONTHLY EARNINGS REPORT', style: TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                        const SizedBox(height: 4),
                        Text('$stylistName · $monthYear', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        
                        // PDF DOWNLOAD BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: () => _generatePdfReport(stylistName, monthYear, total, cash, card, bookings),
                            icon: const Icon(Icons.picture_as_pdf, color: AppColors.gold, size: 18),
                            label: const Text('DOWNLOAD PDF REPORT', style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.gold),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  
                  // Summary Cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(child: _buildStatCard('TOTAL EARNED', 'R${total.toStringAsFixed(2)}', AppColors.gold)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildStatCard('CASH', 'R${cash.toStringAsFixed(2)}', AppColors.success)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildStatCard('CARD', 'R${card.toStringAsFixed(2)}', Colors.blueAccent)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 10),

                  // List of Transactions
                  Expanded(
                    child: bookings.isEmpty 
                      ? const Center(child: Text('No completed appointments this month.', style: TextStyle(color: AppColors.textMuted)))
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: bookings.length,
                          itemBuilder: (context, index) {
                            final b = bookings[index];
                            final date = DateFormat('dd MMM').format(DateTime.parse(b['appointment_date']));
                            final customer = b['customer_name'];
                            final service = b['services']?['name'] ?? 'Service';
                            final method = (b['payment_method_id'] ?? 1) == 1 ? 'Cash' : 'Card';
                            
                            final dynamic rawPrice = b['final_price'] ?? b['services']?['price'] ?? '0';
                            final double price = double.tryParse(rawPrice.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.black,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(date, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(customer, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 4),
                                        Text(service, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('R${price.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            method == 'Cash' ? Icons.payments_outlined : Icons.credit_card, 
                                            color: AppColors.textMuted, size: 12
                                          ),
                                          const SizedBox(width: 4),
                                          Text(method, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  // ==========================================
  // PDF GENERATION LOGIC
  // ==========================================
  Future<void> _generatePdfReport(
    String stylistName, 
    String monthYear, 
    double total, 
    double cash, 
    double card, 
    List<Map<String, dynamic>> bookings
  ) async {
    try {
      final ByteData bytes = await rootBundle.load('assets/images/logo.jpeg');
      final Uint8List logoBytes = bytes.buffer.asUint8List();

      final pdf = pw.Document();
      
      final gold = PdfColor.fromHex('#E8C158');
      final black = PdfColor.fromHex('#000000');
      final white = PdfColor.fromHex('#FFFFFF');
      final grey = PdfColor.fromHex('#9E9E9E');

      // Using MultiPage so it handles many bookings and creates new pages automatically
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // HEADER
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: black,
                  border: pw.Border.all(color: gold, width: 2),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                padding: const pw.EdgeInsets.all(24),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Image(pw.MemoryImage(logoBytes), height: 50, width: 50),
                        pw.SizedBox(width: 16),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('CUTTING EDGE', style: pw.TextStyle(color: gold, fontSize: 20, fontWeight: pw.FontWeight.bold, letterSpacing: 2)),
                            pw.Text('STYLIST EARNINGS REPORT', style: pw.TextStyle(color: gold, fontSize: 10, letterSpacing: 1.5)),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 20),
                    pw.Divider(color: gold, thickness: 1),
                    pw.SizedBox(height: 16),
                    pw.Text(stylistName, style: pw.TextStyle(color: white, fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.Text(monthYear, style: pw.TextStyle(color: gold, fontSize: 14)),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // SUMMARY
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildPdfSummaryBox('TOTAL EARNED', 'R${total.toStringAsFixed(2)}', gold),
                  _buildPdfSummaryBox('CASH', 'R${cash.toStringAsFixed(2)}', PdfColor.fromHex('#3DD68C')),
                  _buildPdfSummaryBox('CARD', 'R${card.toStringAsFixed(2)}', PdfColor.fromHex('#4A90E2')),
                ]
              ),
              pw.SizedBox(height: 30),

              // TABLE HEADER
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                color: black,
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 2, child: pw.Text('Date', style: pw.TextStyle(color: gold, fontWeight: pw.FontWeight.bold, fontSize: 12))),
                    pw.Expanded(flex: 4, child: pw.Text('Client', style: pw.TextStyle(color: gold, fontWeight: pw.FontWeight.bold, fontSize: 12))),
                    pw.Expanded(flex: 4, child: pw.Text('Service', style: pw.TextStyle(color: gold, fontWeight: pw.FontWeight.bold, fontSize: 12))),
                    pw.Expanded(flex: 2, child: pw.Text('Method', style: pw.TextStyle(color: gold, fontWeight: pw.FontWeight.bold, fontSize: 12))),
                    pw.Expanded(flex: 2, child: pw.Text('Amount', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: gold, fontWeight: pw.FontWeight.bold, fontSize: 12))),
                  ]
                )
              ),
              pw.SizedBox(height: 8),

              // TABLE BODY
              ...bookings.map((b) {
                final date = DateFormat('dd MMM').format(DateTime.parse(b['appointment_date']));
                final customer = b['customer_name'];
                final service = b['services']?['name'] ?? 'Service';
                final method = (b['payment_method_id'] ?? 1) == 1 ? 'Cash' : 'Card';
                
                final dynamic rawPrice = b['final_price'] ?? b['services']?['price'] ?? '0';
                final double price = double.tryParse(rawPrice.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromHex('#DDDDDD'), width: 0.5))
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 2, child: pw.Text(date, style: pw.TextStyle(fontSize: 10))),
                      pw.Expanded(flex: 4, child: pw.Text(customer, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 4, child: pw.Text(service, style: pw.TextStyle(fontSize: 10))),
                      pw.Expanded(flex: 2, child: pw.Text(method, style: pw.TextStyle(fontSize: 10, color: grey))),
                      pw.Expanded(flex: 2, child: pw.Text('R${price.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, color: gold, fontWeight: pw.FontWeight.bold))),
                    ]
                  )
                );
              }),

              pw.SizedBox(height: 30),
              pw.Divider(color: gold, thickness: 1),
              pw.SizedBox(height: 10),
              pw.Text(
                'Generated on ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(color: grey, fontSize: 8),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Earnings_Report_$monthYear',
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  pw.Widget _buildPdfSummaryBox(String label, String value, PdfColor color) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: color.shade(0.1),
        border: pw.Border.all(color: color, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: pw.TextStyle(color: PdfColors.grey700, fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(color: color, fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ]
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    final String fullName = _profile?['full_name'] ?? 'Stylist';
    final String firstName = fullName.split(' ').first;
    final String lastName = fullName.contains(' ') ? fullName.split(' ').last : '';
    final String email = _profile?['email'] ?? _supabase.auth.currentUser?.email ?? 'Not set';
    final String phone = _profile?['phone'] ?? 'Not set';
    final String dob = _profile?['date_of_birth'] != null 
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(_profile!['date_of_birth'])) 
        : 'Not set';
    final String? photoUrl = _profile?['photo_url'];

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: const ScreenAppBar(title: 'My Profile'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        child: Column(
          children: [
            // HEADER
            Center(
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: photoUrl != null && photoUrl.isNotEmpty
                        ? CatalogImage(source: photoUrl, width: 90, height: 90)
                        : const Icon(Icons.person, color: AppColors.gold, size: 50),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    fullName,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Stylist',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // INFO CARD
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.person_outline, 'Name', firstName),
                  _buildDivider(),
                  _buildInfoRow(Icons.person_outline, 'Surname', lastName),
                  _buildDivider(),
                  _buildInfoRow(Icons.email_outlined, 'Email', email),
                  _buildDivider(),
                  _buildInfoRow(Icons.phone_outlined, 'Phone', phone),
                  _buildDivider(),
                  _buildInfoRow(Icons.cake_outlined, 'Date of Birth', dob),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ACTION TILES
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildActionTile(
                    icon: Icons.calendar_month_outlined,
                    title: 'My Appointments',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyAppointmentsScreen())),
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'This Month\'s Earnings', 
                    onTap: _showMonthlyEarningsReport, 
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      
      // BOTTOM EDIT BUTTON
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
                if (result == true) _loadProfile(); 
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('EDIT PROFILE', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: AppColors.gold, size: 22),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
    );
  }

  Widget _buildDivider() {
    return const Divider(color: AppColors.border, height: 1, indent: 16, endIndent: 16);
  }
}