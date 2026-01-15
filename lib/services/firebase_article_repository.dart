import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import '../models/article_model.dart';

class FirebaseArticleRepository {
  final _collection = FirebaseFirestore.instance.collection('articles');

  List<List<T>> chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }

  String generateArticleHash(Article article) {
    final normalized = (
        article.title.trim().toLowerCase() +
            article.sourceName.trim().toLowerCase() +
            article.url.trim()
    );

    return sha256.convert(utf8.encode(normalized)).toString();
  }

  Future<void> syncArticles(List<Article> scrapedArticles) async {
    final Map<String, Article> hashToArticle = {};

    for (final article in scrapedArticles) {
      final hash = generateArticleHash(article);
      hashToArticle[hash] = article;
    }

    final hashes = hashToArticle.keys.toList();
    final hashChunks = chunk(hashes, 10);

    final existingHashes = <String>{};

    // Batch existence check
    for (final batch in hashChunks) {
      final snapshot = await _collection
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      for (final doc in snapshot.docs) {
        existingHashes.add(doc.id);
      }
    }

    // Insert only missing
    final batchWrite = FirebaseFirestore.instance.batch();
    for (final entry in hashToArticle.entries) {
      if (existingHashes.contains(entry.key)) continue;

      final article = entry.value;

      batchWrite.set(
        _collection.doc(entry.key),
        {
          'title': article.title,
          'description': article.description,
          'url': article.url,
          'imageUrl': article.urlToImage,
          'source': article.sourceName,
          'publishedAt': article.publishedAt.toIso8601String(),
          'hash': entry.key,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    }

    await batchWrite.commit();
  }

  /// UI reads from Firebase, not scraper
  Stream<List<Article>> watchArticles() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Article(
          title: data['title'],
          description: data['description'],
          url: data['url'],
          urlToImage: data['imageUrl'],
          sourceName: data['source'],
          publishedAt: DateTime.parse(data['publishedAt']),
        );
      }).toList();
    });
  }
}
