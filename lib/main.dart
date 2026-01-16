import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:news_aggregator/screens/news_story_screen.dart';
import 'package:news_aggregator/services/firebase_article_repository.dart';

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

  await Hive.openBox<NewsStoryHive>('groupedStories');
  await FirebaseArticleRepository().initialize();

  runApp(const MyApp());
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
      home: const GroupedNewsResultsPage(),
    );
  }
}
