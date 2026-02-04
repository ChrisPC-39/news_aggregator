import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart'; // Ensure this path is correct

class CustomDrawer extends StatelessWidget {
  final bool isPremium;

  const CustomDrawer({super.key, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      backgroundColor: Colors.transparent,
      // The edge shadow of the drawer can also look "fuzzy" against glass,
      // so we set elevation to 0 and use a border instead.
      elevation: 0,
      child: Stack(
        children: [
          // 1. The Blur Layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  border: Border(
                    right: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
                  ),
                ),
              ),
            ),
          ),

          // 2. The Content Layer
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserHeader(user),
                const SizedBox(height: 20),
                // const Padding(
                //   padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                //   child: Divider(color: Colors.white10),
                // ),

                _buildDrawerItem(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () => Navigator.pop(context),
                ),

                _buildDrawerItem(
                  icon: Icons.info_outline,
                  title: 'App Info',
                  onTap: () => Navigator.pop(context),
                ),

                const Spacer(), // Pushes logout to the bottom

                _buildDrawerItem(
                  icon: Icons.logout,
                  title: 'Log out',
                  isError: true,
                  onTap: () async {
                    await AuthService().signOut();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Methods ---

  Widget _buildUserHeader(User? user) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF8B5CF6), width: 2),
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              child: Text(
                user?.email?[0].toUpperCase() ?? "U",
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user?.email ?? "Guest User",
            style: GoogleFonts.lexend(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            isPremium ? "Premium Account" : "Member",
            style: TextStyle(color: Color(0xFFA78BFA), fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isError = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        // Using InkSparkle or very low opacity highlight to prevent "fuzzy" blur issues
        hoverColor: Colors.white.withValues(alpha: 0.05),
        splashColor: Colors.white.withValues(alpha: 0.05),
        leading: Icon(
          icon,
          color: isError ? Colors.redAccent.withValues(alpha: 0.8) : Colors.white70,
        ),
        title: Text(
          title,
          style: GoogleFonts.lexend(
            color: isError ? Colors.redAccent.withValues(alpha: 0.8) : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}