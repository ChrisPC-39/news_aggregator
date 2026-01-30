// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../models/article_model.dart';
//
// class FirebaseArticleRepository {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final String _collection = 'news';
//
//   // Configuration
//   static const int articlesPerBatch = 700;
//   static const int maxBatches = 10;
//
//   /// Watch all batches and emit combined articles whenever any batch changes
//   /// Optional: filter articles by date range
//   Stream<List<Article>> watchArticles({DateTime? since}) {
//     return _firestore
//         .collection(_collection)
//         .doc('metadata')
//         .snapshots()
//         .asyncExpand((metadataSnapshot) async* {
//       if (!metadataSnapshot.exists) {
//         yield [];
//         return;
//       }
//
//       final data = metadataSnapshot.data()!;
//       final totalBatches = (data['totalBatches'] as int?) ?? 1;
//
//       // Create streams for all batches
//       final batchStreams = <Stream<List<Article>>>[];
//       for (int i = 0; i < totalBatches && i < maxBatches; i++) {
//         batchStreams.add(
//           _firestore
//               .collection(_collection)
//               .doc('batch_$i')
//               .snapshots()
//               .map((snapshot) => _parseBatchArticles(snapshot, since: since)),
//         );
//       }
//
//       // Combine all batch streams
//       yield* _combineStreams(batchStreams);
//     });
//   }
//
//   /// Combine multiple streams into one that emits whenever any stream changes
//   Stream<List<Article>> _combineStreams(List<Stream<List<Article>>> streams) {
//     if (streams.isEmpty) return Stream.value([]);
//
//     final controller = StreamController<List<Article>>();
//     final latestValues = List<List<Article>>.filled(streams.length, []);
//     final initialized = List<bool>.filled(streams.length, false);
//
//     for (int i = 0; i < streams.length; i++) {
//       streams[i].listen((articles) {
//         latestValues[i] = articles;
//         initialized[i] = true;
//
//         // Only emit after all streams have emitted at least once
//         if (initialized.every((val) => val)) {
//           final combined = latestValues.expand((list) => list).toList();
//           controller.add(combined);
//         }
//       });
//     }
//
//     return controller.stream;
//   }
//
//   /// Parse articles from a batch document
//   List<Article> _parseBatchArticles(DocumentSnapshot snapshot, {DateTime? since}) {
//     if (!snapshot.exists) return [];
//
//     final data = snapshot.data() as Map<String, dynamic>?;
//     if (data == null || !data.containsKey('articles')) return [];
//
//     final articlesData = data['articles'] as List<dynamic>;
//     final articles = articlesData
//         .map((json) => Article.fromJson(json as Map<String, dynamic>))
//         .toList();
//
//     // Filter by date if 'since' parameter is provided
//     if (since != null) {
//       return articles.where((article) => article.publishedAt.isAfter(since)).toList();
//     }
//
//     return articles;
//   }
//
//   /// Sync new articles to Firestore using batch system
//   Future<void> syncArticles(List<Article> newArticles) async {
//     if (newArticles.isEmpty) return;
//
//     // 1. Read metadata to determine current state
//     final metadataDoc = await _firestore.collection(_collection).doc('metadata').get();
//
//     int totalBatches = 1;
//     if (metadataDoc.exists) {
//       totalBatches = (metadataDoc.data()?['totalBatches'] as int?) ?? 1;
//     }
//
//     // 2. Read all existing batches to check for duplicates and updates
//     final existingArticles = <String, Article>{};
//     final batchArticleCounts = <int>[];
//
//     for (int i = 0; i < totalBatches && i < maxBatches; i++) {
//       final batchDoc = await _firestore.collection(_collection).doc('batch_$i').get();
//
//       if (batchDoc.exists) {
//         final articles = _parseBatchArticles(batchDoc);
//         batchArticleCounts.add(articles.length);
//
//         for (var article in articles) {
//           final key = _generateArticleKey(article);
//           existingArticles[key] = article;
//         }
//       } else {
//         batchArticleCounts.add(0);
//       }
//     }
//
//     // 3. Process new articles: separate into updates and truly new articles
//     final articlesToAdd = <Article>[];
//     final articlesToUpdate = <String, Article>{}; // key -> updated article
//
//     for (var newArticle in newArticles) {
//       final key = _generateArticleKey(newArticle);
//
//       if (existingArticles.containsKey(key)) {
//         // Article exists - check if it needs updating
//         if (_hasArticleChanged(existingArticles[key]!, newArticle)) {
//           articlesToUpdate[key] = newArticle;
//         }
//       } else {
//         // Truly new article
//         articlesToAdd.add(newArticle);
//       }
//     }
//
//     // 4. Apply updates to existing articles in their batches
//     if (articlesToUpdate.isNotEmpty) {
//       await _updateExistingArticles(articlesToUpdate, totalBatches);
//     }
//
//     // 5. Add new articles to batch_0, creating new batches if needed
//     if (articlesToAdd.isNotEmpty) {
//       await _addNewArticles(articlesToAdd, batchArticleCounts, totalBatches);
//     }
//   }
//
//   /// Update existing articles in their respective batches
//   Future<void> _updateExistingArticles(
//       Map<String, Article> articlesToUpdate,
//       int totalBatches,
//       ) async {
//     for (int i = 0; i < totalBatches && i < maxBatches; i++) {
//       final batchDoc = await _firestore.collection(_collection).doc('batch_$i').get();
//
//       if (!batchDoc.exists) continue;
//
//       final articles = _parseBatchArticles(batchDoc);
//       bool hasChanges = false;
//
//       // Update articles in this batch
//       for (int j = 0; j < articles.length; j++) {
//         final key = _generateArticleKey(articles[j]);
//         if (articlesToUpdate.containsKey(key)) {
//           final updatedArticle = articlesToUpdate[key]!;
//
//           // Preserve the original publishedAt date
//           final mergedArticle = Article(
//             author: updatedArticle.author,
//             title: updatedArticle.title,
//             description: updatedArticle.description,
//             url: updatedArticle.url,
//             urlToImage: updatedArticle.urlToImage,
//             publishedAt: articles[j].publishedAt, // Keep original date
//             content: updatedArticle.content,
//             sourceName: updatedArticle.sourceName,
//             aiSummary: updatedArticle.aiSummary,
//           );
//
//           articles[j] = mergedArticle;
//           hasChanges = true;
//         }
//       }
//
//       // Write back if there were changes
//       if (hasChanges) {
//         await _firestore.collection(_collection).doc('batch_$i').set({
//           'articles': articles.map((a) => a.toJson()).toList(),
//           'articleCount': articles.length,
//           'lastUpdated': FieldValue.serverTimestamp(),
//         });
//       }
//     }
//   }
//
//   /// Add new articles to batch system, rotating batches as needed
//   Future<void> _addNewArticles(
//       List<Article> articlesToAdd,
//       List<int> batchArticleCounts,
//       int totalBatches,
//       ) async {
//     // Read batch_0
//     final batch0Doc = await _firestore.collection(_collection).doc('batch_0').get();
//     List<Article> batch0Articles = batch0Doc.exists ? _parseBatchArticles(batch0Doc) : [];
//
//     // Add new articles to batch_0
//     batch0Articles.addAll(articlesToAdd);
//
//     // Check if we need to rotate batches
//     if (batch0Articles.length > articlesPerBatch) {
//       await _rotateBatches(batch0Articles, totalBatches);
//     } else {
//       // for (var i = 0; i < batch0Articles.length; i++) {
//       //   print('[$i] ${batch0Articles[i].title}');
//       // }
//       // Just update batch_0
//       await _firestore.collection(_collection).doc('batch_0').set({
//         'articles': batch0Articles.map((a) => a.toJson()).toList(),
//         'articleCount': batch0Articles.length,
//         'lastUpdated': FieldValue.serverTimestamp(),
//       });
//
//       // Update metadata
//       await _firestore.collection(_collection).doc('metadata').set({
//         'totalBatches': totalBatches,
//         'totalArticles': batchArticleCounts.fold(0, (a, b) => a + b) + articlesToAdd.length,
//         'lastUpdated': FieldValue.serverTimestamp(),
//       });
//     }
//   }
//
//   /// Rotate batches when batch_0 exceeds limit
//   Future<void> _rotateBatches(List<Article> batch0Articles, int currentTotalBatches) async {
//     // Keep first 700 in batch_0, move rest to new batch
//     final keepInBatch0 = batch0Articles.take(articlesPerBatch).toList();
//     final overflow = batch0Articles.skip(articlesPerBatch).toList();
//
//     // Write batch_0
//     await _firestore.collection(_collection).doc('batch_0').set({
//       'articles': keepInBatch0.map((a) => a.toJson()).toList(),
//       'articleCount': keepInBatch0.length,
//       'lastUpdated': FieldValue.serverTimestamp(),
//     });
//
//     // Shift existing batches down (batch_1 -> batch_2, etc.)
//     for (int i = currentTotalBatches - 1; i >= 1; i--) {
//       if (i >= maxBatches - 1) {
//         // Delete batches beyond max limit
//         await _firestore.collection(_collection).doc('batch_$i').delete();
//       } else {
//         // Read current batch
//         final currentDoc = await _firestore.collection(_collection).doc('batch_$i').get();
//         if (currentDoc.exists) {
//           // Write to next batch
//           await _firestore.collection(_collection).doc('batch_${i + 1}').set(currentDoc.data()!);
//         }
//       }
//     }
//
//     // Write overflow to batch_1
//     if (overflow.isNotEmpty) {
//       await _firestore.collection(_collection).doc('batch_1').set({
//         'articles': overflow.map((a) => a.toJson()).toList(),
//         'articleCount': overflow.length,
//         'lastUpdated': FieldValue.serverTimestamp(),
//       });
//     }
//
//     // Update metadata
//     final newTotalBatches = (currentTotalBatches + 1).clamp(1, maxBatches);
//     await _firestore.collection(_collection).doc('metadata').set({
//       'totalBatches': newTotalBatches,
//       'totalArticles': batch0Articles.length,
//       'lastUpdated': FieldValue.serverTimestamp(),
//     });
//   }
//
//   /// Generate unique key for article (for deduplication)
//   String _generateArticleKey(Article article) {
//     return '${article.sourceName}::${article.title.trim().toLowerCase()}';
//   }
//
//   /// Check if article content has changed
//   bool _hasArticleChanged(Article existing, Article updated) {
//     bool changed = false;
//     List<String> diffs = [];
//
//     if (existing.description != updated.description) {
//       diffs.add('DESCRIPTION: "${existing.description}" -> "${updated.description}"');
//       changed = true;
//     }
//
//     if (existing.url != updated.url) {
//       diffs.add('URL: ${existing.url} -> ${updated.url}');
//       changed = true;
//     }
//
//     if (existing.urlToImage != updated.urlToImage) {
//       diffs.add('IMAGE: ${existing.urlToImage} -> ${updated.urlToImage}');
//       changed = true;
//     }
//
//     // if (changed) {
//     //   print('🔄 Article Changed: ${existing.title}');
//     //   for (var d in diffs) {
//     //     print('   └─ $d');
//     //   }
//     // }
//
//     return changed;
//   }
//
//   /// Initialize Firestore structure (call once on first setup)
//   Future<void> initialize() async {
//     final metadataDoc = await _firestore.collection(_collection).doc('metadata').get();
//
//     if (!metadataDoc.exists) {
//       await _firestore.collection(_collection).doc('metadata').set({
//         'totalBatches': 1,
//         'totalArticles': 0,
//         'lastUpdated': FieldValue.serverTimestamp(),
//       });
//
//       await _firestore.collection(_collection).doc('batch_0').set({
//         'articles': [],
//         'articleCount': 0,
//         'lastUpdated': FieldValue.serverTimestamp(),
//       });
//     }
//   }
// }