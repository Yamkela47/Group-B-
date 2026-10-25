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
import 'app_theme.dart';            // Custom colors and styles
import 'catalog_image.dart';       // Custom image widget with error handling
import 'package:supabase_flutter/supabase_flutter.dart';
import 'book_appointment_screen.dart'; // Screen to book a selected service
import 'brand.dart';               // Brand logo widget
import 'booking_gate.dart';        // Prevents double-booking

/// A screen that displays the list of available services and active promotions.
/// It includes a search bar and a category filter (All, Popular, Promotions).
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  // State variables for the fetched data
  List<_Service> _services = [];
  List<Map<String, dynamic>> _promotions = [];
  bool _loading = true;
  String? _error;

  // Search and Filter State
  String _searchQuery = '';
  String _selectedCategory = 'All Services';
  final List<String> _categories = ['All Services', 'Popular Services', 'Promotions'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Fetches both services and promotions from Supabase simultaneously.
  Future<void> _loadData() async {
    try {
      // Future.wait runs both database queries in parallel for faster loading
      final results = await Future.wait([
        Supabase.instance.client
            .from('services')
            .select('service_id,name,description,price,duration_minutes,image_url')
            .eq('active', true)
            .order('service_id'),
        Supabase.instance.client
            .from('promotions')
            .select()
            .eq('active', true)
            .order('created_at', ascending: false),
      ]);

      if (!mounted) return;

      final serviceRows = results[0] as List;
      final promoRows = results[1] as List;

      setState(() {
        // Map the raw database rows into our custom _Service model
        _services = serviceRows.map((row) {
          final minutes = (row['duration_minutes'] as num?)?.toInt() ?? 0;
          return _Service(
            serviceId: (row['service_id'] as num).toInt(),
            imagePath: row['image_url']?.toString() ?? '',
            name: row['name']?.toString() ?? 'Service',
            description: row['description']?.toString() ?? '',
            duration: '$minutes min',
            durationMinutes: minutes,
            priceNum: (row['price'] as num?)?.toDouble() ?? 0.0,
            price: 'R${(row['price'] as num? ?? 0).toStringAsFixed(2)}',
          );
        }).toList();

        _promotions = List<Map<String, dynamic>>.from(promoRows);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  /// Helper method to determine if a service should be categorized as "Popular"
  /// based on specific keywords in its name.
  bool _isPopular(_Service service) {
    final keywords = ['haircut', 'cut & dye', 'cut and dye', 'fiber', 'bleach'];
    final name = service.name.toLowerCase();
    return keywords.any((kw) => name.contains(kw));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 90,
        // Custom back button
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Row(children: [
              Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Text('Back',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        // Brand Title in the center
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(size: 28),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('CUTTING EDGE',
                    style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8)),
                Text('OUR VISION, YOUR STYLE',
                    style: TextStyle(
                        color: AppColors.goldDim,
                        fontSize: 6.5,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? Center(child: Text('Unable to load data: $_error', style: const TextStyle(color: Colors.white)))
              : Column(
                  children: [
                    // ==========================================
                    // SEARCH & FILTER BAR
                    // ==========================================
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Search Text Field
                          TextField(
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search services or promos...',
                              hintStyle: const TextStyle(color: AppColors.textMuted),
                              prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                              filled: true,
                              fillColor: AppColors.surfaceAlt,
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (val) {
                              // Update the search query state whenever the user types
                              setState(() => _searchQuery = val.toLowerCase());
                            },
                          ),
                          const SizedBox(height: 12),
                          
                          // Category Dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCategory,
                                dropdownColor: AppColors.surfaceAlt,
                                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.gold),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                isExpanded: true,
                                items: _categories.map((String category) {
                                  return DropdownMenuItem<String>(
                                    value: category,
                                    child: Text(category),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() => _selectedCategory = newValue);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ==========================================
                    // MAIN LIST
                    // ==========================================
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadData,
                        color: AppColors.gold,
                        backgroundColor: AppColors.surfaceAlt,
                        child: _buildFilteredList(),
                      ),
                    ),
                  ],
                ),
    );
  }

  /// Builds the list of services and promotions based on the current search query and selected category.
  Widget _buildFilteredList() {
    // 1. Filter Promotions based on the search query
    final filteredPromos = _promotions.where((promo) {
      final title = (promo['title'] ?? '').toString().toLowerCase();
      final desc = (promo['description'] ?? '').toString().toLowerCase();
      return title.contains(_searchQuery) || desc.contains(_searchQuery);
    }).toList();

    // 2. Filter Services based on the search query and if 'Popular' is selected
    final filteredServices = _services.where((service) {
      final matchesSearch = service.name.toLowerCase().contains(_searchQuery) || 
                            service.description.toLowerCase().contains(_searchQuery);
      
      if (_selectedCategory == 'Popular Services') {
        return matchesSearch && _isPopular(service);
      }
      return matchesSearch;
    }).toList();

    // 3. Determine which sections to show based on the Dropdown selection
    bool showPromos = false;
    bool showServices = false;

    if (_selectedCategory == 'Promotions') {
      showPromos = true;
    } else if (_selectedCategory == 'Popular Services') {
      showServices = true;
    } else {
      // All Services (show both promos and services)
      showPromos = true;
      showServices = true;
    }

    // Handle the empty state
    if ((!showPromos || filteredPromos.isEmpty) && (!showServices || filteredServices.isEmpty)) {
      return ListView(
        children: const [
          SizedBox(height: 50),
          Center(child: Text('No results found.', style: TextStyle(color: AppColors.textMuted))),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        const Text('Services & Pricing',
            style: TextStyle(
                color: AppColors.gold,
                fontSize: 22,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('Choose a service',
            style: TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 18),

        // --- Promotions Section ---
        if (showPromos && filteredPromos.isNotEmpty) ...[
          const Text('Special Offers',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          // Render each promo card
          ...filteredPromos.map((promo) {
            // Find the corresponding service data for this promo
            final matchedService = _services.firstWhere(
              (s) => s.serviceId == promo['service_id'],
              orElse: () => _Service(serviceId: 0, imagePath: '', name: 'Service', description: '', duration: '30 min', durationMinutes: 30, priceNum: 0, price: 'R0'),
            );
            return _PromoCard(promo: promo, service: matchedService);
          }),
          const SizedBox(height: 24),
          
          // Divider between Promos and Services if both are shown
          if (showServices && filteredServices.isNotEmpty) ...[
            const Divider(color: AppColors.border),
            const SizedBox(height: 18),
          ]
        ],

        // --- Services Section ---
        if (showServices && filteredServices.isNotEmpty) ...[
          if (_selectedCategory == 'Popular Services')
            const Text('Popular Services',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          if (_selectedCategory == 'Popular Services')
            const SizedBox(height: 12),
          // Render each service card
          ...filteredServices.map((service) => _ServiceCard(service: service)),
        ],
      ],
    );
  }
}

/// A data model class to hold the details of a single service.
class _Service {
  final int serviceId;
  final String imagePath;
  final String name;
  final String description;
  final String duration;
  final int durationMinutes;
  final double priceNum;
  final String price;

  const _Service({
    required this.serviceId,
    required this.imagePath,
    required this.name,
    required this.description,
    required this.duration,
    required this.durationMinutes,
    required this.priceNum,
    required this.price,
  });
}

/* ============================================================
   PROMO CARD WIDGET
   ============================================================ */
/// A card widget that displays a promotional offer.
/// It calculates the discounted price and shows the savings.
class _PromoCard extends StatelessWidget {
  final Map<String, dynamic> promo;
  final _Service service;
  
  const _PromoCard({required this.promo, required this.service});

  @override
  Widget build(BuildContext context) {
    final String title = promo['title'] ?? 'SPECIAL OFFER';
    final String? imageUrl = promo['image_url'];
    
    // Extract discount details
    final num discountValue = promo['discount_value'] ?? 0;
    final String discountType = (promo['discount_type'] ?? '').toString().toLowerCase();
    
    // Calculate the final price and how much the user saves
    double finalPrice = service.priceNum;
    double savings = 0.0;

    if (service.priceNum > 0) {
      if (discountType.contains('percent')) {
        // Calculate percentage discount
        savings = service.priceNum * (discountValue / 100);
        finalPrice = service.priceNum - savings;
      } else {
        // Calculate fixed amount discount
        savings = discountValue.toDouble();
        finalPrice = service.priceNum - savings;
      }
    }

    return GestureDetector(
      // Tapping the card goes through the BookingGate to ensure the user can book
      onTap: () => BookingGate.checkAndProceedToBook(
        context,
        BookAppointmentScreen(
          service: '$title - ${service.name}',
          price: 'R${finalPrice.toStringAsFixed(2)}', 
          serviceId: service.serviceId, 
          durationMinutes: service.durationMinutes, 
          serviceImagePath: imageUrl ?? service.imagePath,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold, width: 1.5), // Highlighted border for promos
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Promo Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(imageUrl, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (_,__,___) => _placeholder())
                      : _placeholder(),
                ),
                const SizedBox(width: 14),
                
                // Promo Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: AppColors.gold, size: 16),
                          const SizedBox(width: 4),
                          const Text('PROMO', style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const Spacer(),
                          // Show savings badge if applicable
                          if (savings > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                              child: Text('Save R${savings.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(title.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('Applies to: ${service.name}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 8),
                      
                      // Price and Duration Row
                      Row(
                        children: [
                          // Show original price crossed out if there's a saving
                          if (savings > 0) ...[
                            Text(
                              'R${service.priceNum.toStringAsFixed(2)}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12, decoration: TextDecoration.lineThrough),
                            ),
                            const SizedBox(width: 6),
                          ],
                          // Final discounted price
                          Text(
                            'R${finalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.access_time, color: AppColors.textSecondary, size: 14),
                          const SizedBox(width: 4),
                          Text('${service.durationMinutes} min', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Book Promo Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => BookingGate.checkAndProceedToBook(
                  context,
                  BookAppointmentScreen(
                    service: '$title - ${service.name}', 
                    price: 'R${finalPrice.toStringAsFixed(2)}', 
                    serviceId: service.serviceId, 
                    durationMinutes: service.durationMinutes, 
                    serviceImagePath: imageUrl ?? service.imagePath,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('BOOK PROMO', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
              ),
            )
          ],
        ),
      ),
    );
  }

  /// A fallback UI if the promo image fails to load.
  Widget _placeholder() {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
      child: const Icon(Icons.local_offer_outlined, color: AppColors.gold, size: 30),
    );
  }
}

/* ============================================================
   SERVICE CARD WIDGET
   ============================================================ */
/// A card widget that displays standard service details.
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
          // Service Image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CatalogImage(
              source: service.imagePath,
              width: 84,
              height: 96,
            ),
          ),
          const SizedBox(width: 14),
          
          // Service Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(service.description,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        height: 1.35)),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoLine(
                              icon: Icons.access_time, text: service.duration),
                          const SizedBox(height: 5),
                          _InfoLine(
                              icon: Icons.local_offer_outlined,
                              text: service.price),
                        ],
                      ),
                    ),
                    
                    // Select Button
                    ElevatedButton(
                      onPressed: () => BookingGate.checkAndProceedToBook(
                        context,
                        BookAppointmentScreen(
                          service: service.name,
                          price: service.price,
                          serviceId: service.serviceId,
                          durationMinutes: service.durationMinutes,
                          serviceImagePath: service.imagePath,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        minimumSize: const Size(0, 0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Text('Select',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3)),
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

/// A helper widget to display a single line of information with an icon.
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
        Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}