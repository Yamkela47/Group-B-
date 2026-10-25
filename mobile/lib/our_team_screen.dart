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
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';                 // Custom colors and styles
import 'app_bars.dart';                  // Custom AppBar widget
import 'catalog_image.dart';             // Custom image widget with error handling
import 'team_member_profile_screen.dart'; // Screen to view the full profile of a team member

/// A screen that displays the list of stylists (the "Team") working at the salon.
/// It fetches active stylists from the database and displays them in a list.
class OurTeamScreen extends StatefulWidget {
  const OurTeamScreen({super.key});

  @override
  State<OurTeamScreen> createState() => _OurTeamScreenState();
}

class _OurTeamScreenState extends State<OurTeamScreen> {
  final _supabase = Supabase.instance.client;
  
  // State variables
  bool _loading = true;
  String? _errorMessage;
  List<TeamMember> _team = [];

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  /// Fetches the list of active stylists and their profile details from Supabase.
  Future<void> _loadTeam() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch all active stylists from the 'stylists' table
      final response = await _supabase
          .from('stylists')
          .select('stylist_id, rating, profile_id')
          .eq('active', true);

      List<TeamMember> loadedTeam = [];

      // 2. Loop through each stylist row to get their profile information
      for (var row in (response as List)) {
        String name = 'Stylist';
        String? photoUrl;
        
        // If the stylist is linked to a profile, fetch their name and photo
        if (row['profile_id'] != null) {
          try {
            final profile = await _supabase
                .from('profiles')
                .select('full_name, photo_url')
                .eq('id', row['profile_id'])
                .maybeSingle();
                
            if (profile != null) {
              name = profile['full_name'] ?? 'Stylist';
              photoUrl = profile['photo_url'];
            }
          } catch (e) {
            debugPrint('Error fetching profile for stylist: $e');
          }
        }

        // Hardcode a role based on the name to match a specific visual requirement
        String role = 'Stylist';
        if (name.toLowerCase().contains('nqobile')) {
          role = 'Senior Stylist'; 
        }

        // Add the formatted data to our local list
        loadedTeam.add(TeamMember(
          name: name,
          role: role,
          photoUrl: photoUrl,
          rating: (row['rating'] as num?)?.toDouble() ?? 5.0,
          bio: 'With over a decade of experience in the industry, I specialize in precision fades, classic tapers, and modern textured cuts.',
          services: ['Haircut', 'Styling', 'Treatments'],
        ));
      }

      if (!mounted) return;
      setState(() {
        _team = loadedTeam;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
      debugPrint('Error loading team: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Our Team'),
      // Conditional rendering: Loading, Error, Empty, or the List
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _errorMessage != null
              ? _buildErrorState()
              : _team.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadTeam,
                      color: AppColors.gold,
                      backgroundColor: AppColors.surfaceAlt,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                        // +1 is added because index 0 is used for the Header
                        itemCount: _team.length + 1, 
                        itemBuilder: (context, index) {
                          // Header Section
                          if (index == 0) {
                            return _buildHeader();
                          }

                          // Stylist Cards Section (index - 1 adjusts for the header)
                          final member = _team[index - 1];
                          return _buildMemberCard(member);
                        },
                      ),
                    ),
    );
  }

  /// Builds the title and description at the top of the list.
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const Text(
          'Our Team',
          style: TextStyle(
            color: AppColors.gold,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Meet the Cutting Edge stylists.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Builds the visual card for a single stylist.
  Widget _buildMemberCard(TeamMember member) {
    return GestureDetector(
      // Navigate to the stylist's detailed profile when tapped
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeamMemberProfileScreen(member: member),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.5),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            // Profile Picture (Circular)
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 1.5),
                color: AppColors.surface,
              ),
              clipBehavior: Clip.antiAlias,
              child: member.photoUrl != null && member.photoUrl!.isNotEmpty
                  ? CatalogImage(
                      source: member.photoUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    )
                  : const Icon(Icons.person, color: AppColors.gold, size: 30),
            ),
            const SizedBox(width: 16),
            
            // Name and Role Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    member.role,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            // Chevron Icon indicating the card is clickable
            const Icon(
              Icons.chevron_right,
              color: AppColors.gold,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  /// Displays a message when there are no stylists in the database.
  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 100),
        Icon(Icons.group_off, color: AppColors.textMuted, size: 60),
        SizedBox(height: 16),
        Center(
          child: Text(
            'No stylists available right now.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  /// Displays an error message and a retry button if the fetch fails.
  Widget _buildErrorState() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.error_outline, color: AppColors.error, size: 60),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Could not load the team',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _errorMessage ?? 'Unknown error occurred',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loadTeam,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.black,
          ),
          child: const Text('TRY AGAIN'),
        ),
      ],
    );
  }
}

/// A data model class to hold the details of a single team member.
class TeamMember {
  final String name;
  final String role;
  final String? photoUrl;
  final double rating;
  final String bio;
  final List<String> services;

  TeamMember({
    required this.name,
    required this.role,
    this.photoUrl,
    required this.rating,
    required this.bio,
    required this.services,
  });
}