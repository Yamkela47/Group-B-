import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_bars.dart';          // ScreenAppBar
import 'team_member_profile_screen.dart'; // the new profile screen

class OurTeamScreen extends StatelessWidget {
  const OurTeamScreen({super.key});

  // ----------------------------------------------------------------
  //  Team data.
  //  Each stylist has a name, role, starting rating, image, and bio.
  //  Adding a new member is just one more entry here — the screen
  //  builds itself automatically.
  // ----------------------------------------------------------------
  static const List<TeamMember> _team = [
    TeamMember(
      name: 'Sipho Dlamini',
      role: 'Master Stylist',
      rating: 4.9,
      imagePath: 'assets/images/stylist_sipho.jpg',
      bio: 'Sipho has 12 years of experience with fades, tapers and '
          'classic cuts. He specialises in precision work.',
      services: ['Haircut', 'Beard Shave', 'Hot Towel'],
    ),
    TeamMember(
      name: 'Thabo Nkosi',
      role: 'Senior Stylist',
      rating: 4.8,
      imagePath: 'assets/images/stylist_thabo.jpg',
      bio: 'Thabo loves bold styles and modern cuts. Friendly, fast '
          'and always up for a chat.',
      services: ['Haircut', 'Kids Haircut', 'Beard Shave'],
    ),
    TeamMember(
      name: 'Lerato Mokoena',
      role: 'Colour Specialist',
      rating: 5.0,
      imagePath: 'assets/images/stylist_lerato.jpg',
      bio: 'Lerato is our colour expert. From subtle highlights to '
          'full transformations, she does it all.',
      services: ['Cut & Dye', 'Colour Touch-up', 'Treatment'],
    ),
    TeamMember(
      name: 'Nqobile Ngwenya',
      role: 'Stylist',
      rating: 4.7,
      imagePath: 'assets/images/stylist_nqobile.jpg',
      bio: 'Nqobile is passionate about making every client feel '
          'confident and fresh.',
      services: ['Haircut', 'Hot Towel', 'Beard Shave'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Our Team'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Meet the Cutting Edge team',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap a stylist to view their profile and rate them.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 20),

          // Build one card per team member
          ..._team.map((member) => _TeamMemberCard(member: member)),
        ],
      ),
    );
  }
}

/* ===================================================================
   TEAM MEMBER DATA MODEL
   Holds all the info we need for one stylist.
   =================================================================== */
class TeamMember {
  final String name;
  final String role;
  final double rating;
  final String imagePath;
  final String bio;
  final List<String> services;

  const TeamMember({
    required this.name,
    required this.role,
    required this.rating,
    required this.imagePath,
    required this.bio,
    required this.services,
  });
}

/* ===================================================================
   TEAM MEMBER CARD
   Row layout: photo on left, name/role/rating in the middle,
   chevron on the right. Tapping opens the profile screen.
   =================================================================== */
class _TeamMemberCard extends StatelessWidget {
  final TeamMember member;
  const _TeamMemberCard({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeamMemberProfileScreen(member: member),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // ---- Circular photo with placeholder fallback ----
                ClipOval(
                  child: Image.asset(
                    member.imagePath,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: AppColors.gold,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // ---- Name + role + rating ----
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        member.role,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              color: AppColors.gold, size: 12),
                          const SizedBox(width: 3),
                          Text(
                            member.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ---- Chevron ----
                const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}