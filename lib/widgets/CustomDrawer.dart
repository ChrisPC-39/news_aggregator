import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/changelog_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/saved_stories_screen.dart';
import '../screens/news_story_screen.dart';
import '../services/auth_service.dart';

/// Identifies which top-level screen is currently active.
/// Pass this into [CustomDrawer] so it can highlight the correct item.
enum ActiveScreen { news, saved, settings, appInfo }

class CustomDrawer extends StatelessWidget {
  final bool isAdmin;
  final bool isPremium;
  final ActiveScreen activeScreen;

  const CustomDrawer({
    super.key,
    required this.isPremium,
    required this.isAdmin,
    this.activeScreen = ActiveScreen.news,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        children: [
          // 1. Blur layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  border: Border(
                    right: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Content layer
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserHeader(user),
                const SizedBox(height: 20),

                _buildDrawerItem(
                  context: context,
                  icon: Icons.newspaper_outlined,
                  title: 'Stories',
                  isActive: activeScreen == ActiveScreen.news,
                  onTap: () {
                    if (activeScreen == ActiveScreen.news) {
                      Navigator.pop(context); // Already here — just close
                    } else {
                      // Close drawer, then pop back to NewsStoryScreen
                      Navigator.pop(context);
                      Navigator.of(context).popUntil(
                            (route) =>
                        route.isFirst ||
                            route.settings.name == '/news',
                      );
                    }
                  },
                ),

                _buildDrawerItem(
                  context: context,
                  icon: Icons.bookmark_outline,
                  title: 'Saved Stories',
                  isActive: activeScreen == ActiveScreen.saved,
                  onTap: () {
                    if (activeScreen == ActiveScreen.saved) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SavedStoriesScreen(
                            isPremium: isPremium,
                            isAdmin: isAdmin,
                          ),
                        ),
                      );
                    }
                  },
                ),

                _buildDrawerItem(
                  context: context,
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  isActive: activeScreen == ActiveScreen.settings,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          isPremium: isPremium,
                          isAdmin: isAdmin,
                        ),
                      ),
                    );
                  },
                ),

                _buildDrawerItem(
                  context: context,
                  icon: Icons.info_outline,
                  title: 'App Info',
                  isActive: activeScreen == ActiveScreen.appInfo,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangelogPage(),
                      ),
                    );
                  },
                ),

                const Spacer(),

                _buildDrawerItem(
                  context: context,
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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
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
            style: const TextStyle(
              color: Color(0xFFA78BFA),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isActive = false,
    bool isError = false,
  }) {
    final Color activeColor = const Color(0xFF8B5CF6);
    final Color defaultColor = Colors.white70;
    final Color errorColor = Colors.redAccent.withValues(alpha: 0.8);

    final Color itemColor =
    isError ? errorColor : (isActive ? activeColor : defaultColor);

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: isActive
            ? BoxDecoration(
          color: activeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: activeColor.withValues(alpha: 0.25),
            width: 1,
          ),
        )
            : null,
        child: ListTile(
          onTap: onTap,
          hoverColor: Colors.white.withValues(alpha: 0.05),
          splashColor: Colors.white.withValues(alpha: 0.05),
          leading: Icon(icon, color: itemColor),
          title: Text(
            title,
            style: GoogleFonts.lexend(
              color: itemColor,
              fontSize: 15,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          trailing: isActive
              ? Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: activeColor,
              shape: BoxShape.circle,
            ),
          )
              : null,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}