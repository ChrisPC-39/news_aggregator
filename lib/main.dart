import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:news_aggregator/screens/login_screen.dart';
import 'package:news_aggregator/screens/news_story_screen.dart';

import 'firebase_options.dart';
import 'models/hive_models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  await Hive.initFlutter();
  Hive.registerAdapter(ArticleHiveAdapter());
  Hive.registerAdapter(NewsStoryHiveAdapter());

  await Hive.openBox<ArticleHive>('articles');
  await Hive.openBox<NewsStoryHive>('groupedStories');

  // await Hive.box<NewsStoryHive>('groupedStories').clear();

  runApp(const MyApp());
}

/// Fetches isPremium and isAdmin from the user's Firestore document.
/// Returns defaults (both false) if the doc is missing or malformed —
/// this guards against the edge case where a user somehow exists in Auth
/// but their doc hasn't been created yet.
Future<Map<String, bool>> _fetchUserData(String uid) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();

  if (!doc.exists) {
    return {'isPremium': false, 'isAdmin': false};
  }

  return {
    'isPremium': (doc.data()?['isPremium'] as bool?) ?? false,
    'isAdmin': (doc.data()?['isAdmin'] as bool?) ?? false,
  };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 16.0),
          bodyMedium: TextStyle(fontSize: 14.0),
          titleLarge: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 16.0,
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Not logged in
          if (!snapshot.hasData) {
            return const LoginPage();
          }

          // Logged in — fetch the user doc before rendering the main screen.
          // FutureBuilder re-runs automatically if the User object changes
          // (i.e. a different account signs in), because the future key
          // changes with the uid.
          return FutureBuilder<Map<String, bool>>(
            future: _fetchUserData(snapshot.data!.uid),
            builder: (context, userSnapshot) {
              // Still fetching — show a simple spinner so the app doesn't
              // flash the main screen before we know the user's status.
              if (!userSnapshot.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final isPremium = userSnapshot.data!['isPremium'] ?? false;
              final isAdmin = userSnapshot.data!['isAdmin'] ?? false;

              return NewsStoryScreen(
                isPremium: isPremium,
                isAdmin: isAdmin,
              );
            },
          );
        },
      ),
    );
  }
}