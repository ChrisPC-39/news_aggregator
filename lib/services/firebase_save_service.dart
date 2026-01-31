import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/news_story_model.dart';

class FirebaseSaveService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // final SummaryService _summaryService = SummaryService();

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
}