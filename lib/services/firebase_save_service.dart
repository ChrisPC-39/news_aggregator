import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:news_aggregator/services/summary_service.dart';

import '../models/news_story_model.dart';

class FirebaseSaveService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SummaryService _summaryService = SummaryService();

  /// Returns the current user's document reference in the "users" collection.
  /// Throws a [StateError] if no user is signed in.
  DocumentReference<Map<String, dynamic>> _userDoc() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found.');
    }
    return _firestore.collection('users').doc(user.uid);
  }

  /// Saves a [NewsStory] to the current user's document.
  ///
  /// Stories are stored in a map keyed by [canonicalTitle] inside a
  /// top-level "stories" field on the user document. If the user document
  /// or the "stories" map doesn't exist yet, it is created automatically
  /// via the merge behaviour of [set].
  Future<void> saveStory(NewsStory story) async {
    final docRef = _userDoc();

    // Use a unique, stable key for the story. canonicalTitle works well
    // here; swap in a UUID or other ID if titles aren't guaranteed unique.
    final storyKey = story.canonicalTitle;

    await docRef.set(
      {
        'stories': {storyKey: story.toJson()},
      },
      SetOptions(merge: true), // creates the doc if it doesn't exist
    );

    // Generate summary and patch it back in.
    try {
      final summary = await _summaryService.generateSummary(story);

      await docRef.update({
        FieldPath(['stories', storyKey, 'aiSummary']): summary,
      });
    } catch (e) {
      // Story is already saved — log the error but don't throw,
      // so the caller isn't blocked by a summarization failure.
    }
  }

  /// Deletes a single story (by its canonicalTitle key) from the user doc.
  Future<void> deleteStory(String canonicalTitle) async {
    try {
      await _userDoc().update({
        FieldPath(['stories', canonicalTitle]): FieldValue.delete(),
      });
    } catch (e) {
      print('Error deleting story: $e');
    }
  }

  /// Returns all stories saved for the current user, or an empty list
  /// if the document or the "stories" field doesn't exist.
  Future<List<NewsStory>> fetchAllStories() async {
    final snapshot = await _userDoc().get();
    final data = snapshot.data();

    if (data == null) return [];

    final storiesMap = data['stories'] as Map<String, dynamic>?;
    if (storiesMap == null) return [];

    return storiesMap.values
        .map((json) => NewsStory.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Returns the set of canonicalTitles for every story saved in Firebase.
  /// Reads keys directly from the stories map — does not deserialize into
  /// NewsStory, so it will never fail due to missing or changed model fields.
  Future<Set<String>> fetchSavedTitles() async {
    final snapshot = await _userDoc().get();
    final data = snapshot.data();

    if (data == null) return {};

    final storiesMap = data['stories'] as Map<String, dynamic>?;
    if (storiesMap == null) return {};

    return storiesMap.keys.toSet();
  }

  Future<void> updateStorySummary(String title, String summary) async {
    await _userDoc().update({
      FieldPath(['stories', title, 'aiSummary']): summary
    });
  }

  /// Returns the raw "stories" map from Firestore: title → story data.
  /// This is the single fetch that _fetchSavedStories needs — it can read
  /// aiSummary, deserialize missing stories, and get the title set all
  /// from one snapshot without making multiple round trips.
  Future<Map<String, dynamic>> fetchRawStoriesMap() async {
    final snapshot = await _userDoc().get();
    final data = snapshot.data();

    if (data == null) return {};

    return data['stories'] as Map<String, dynamic>? ?? {};
  }

  /// Returns a stream that emits the raw map for a single saved story
  /// whenever it changes in Firestore. The stream emits null if the
  /// story doesn't exist (yet) in the document.
  Stream<Map<String, dynamic>?> watchStory(String canonicalTitle) {
    return _userDoc().snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;

      final storiesMap = data['stories'] as Map<String, dynamic>?;
      return storiesMap?[canonicalTitle] as Map<String, dynamic>?;
    });
  }

  // Stream<Map<String, dynamic>?> watchStory(String title) {
  //   return _userDoc().snapshots().map((doc) {
  //     final stories = (doc.data())?['stories'] as Map<String, dynamic>?;
  //     return stories?[title] as Map<String, dynamic>?;
  //   }).distinct((prev, next) => mapEquals(prev, next)); // Only emit if the specific story map changed
  // }

  // Stream<Map<String, dynamic>?> watchStory(String title) {
  //   return _userDoc().snapshots().map((doc) {
  //     if (!doc.exists) return null;
  //
  //     // Dig into the nested map: stories -> {title}
  //     final data = doc.data();
  //     final stories = data?['stories'] as Map<String, dynamic>?;
  //
  //     return stories?[title] as Map<String, dynamic>?;
  //   });
  // }
}