// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:url_launcher/url_launcher.dart';
//
// import '../services/api_service.dart';
// import '../models/article_model.dart';
//
// class NewsResultsPage extends StatefulWidget {
//   final Map<String, dynamic> searchParams;
//
//   const NewsResultsPage({super.key, required this.searchParams});
//
//   @override
//   State<NewsResultsPage> createState() => _NewsResultsPageState();
// }
//
// class _NewsResultsPageState extends State<NewsResultsPage> {
//   late Future<List<Article>> _newsFuture;
//   final ApiService _apiService = ApiService();
//
//   @override
//   void initState() {
//     super.initState();
//     // Start the API call when the widget is first created
//     _newsFuture = _apiService.fetchNews(widget.searchParams);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('News Results'),
//         backgroundColor: Theme.of(context).primaryColor,
//         foregroundColor: Colors.white,
//       ),
//       body: FutureBuilder<List<Article>>(
//         future: _newsFuture,
//         builder: (context, snapshot) {
//           // 1. Check for errors
//           if (snapshot.hasError) {
//             return Center(
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Text(
//                   'Error: ${snapshot.error}',
//                   style: const TextStyle(color: Colors.red, fontSize: 16),
//                   textAlign: TextAlign.center,
//                 ),
//               ),
//             );
//           }
//
//           // 2. Check if data is loading
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }
//
//           // 3. Check if data is available but empty
//           if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return const Center(
//               child: Text(
//                 'No articles found for your search criteria.',
//                 style: TextStyle(fontSize: 18),
//               ),
//             );
//           }
//
//           // 4. If we have data, display it
//           final articles = snapshot.data!;
//           return ListView.builder(
//             itemCount: articles.length,
//             itemBuilder: (context, index) {
//               final article = articles[index];
//               return Card(
//                 margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 elevation: 4,
//                 clipBehavior: Clip.antiAlias,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // Display image if available
//                     if (article.urlToImage != null)
//                       Image.network(
//                         article.urlToImage!,
//                         height: 200,
//                         width: double.infinity,
//                         fit: BoxFit.cover,
//                         // Show a placeholder while loading and an error icon if it fails
//                         loadingBuilder: (context, child, progress) {
//                           return progress == null
//                               ? child
//                               : SizedBox(
//                                 height: 200,
//                                 child: CircularProgressIndicator(),
//                               );
//                         },
//                         errorBuilder: (context, error, stackTrace) {
//                           return const SizedBox();
//                         },
//                       ),
//                     Padding(
//                       padding: const EdgeInsets.all(16.0),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           TextButton(
//                             onPressed:
//                                 () => launchArticleUrl(context, article.url),
//                             child: Text(
//                               article.title,
//                               style: Theme.of(
//                                 context,
//                               ).textTheme.titleLarge?.copyWith(fontSize: 18),
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           Text(
//                             article.description,
//                             style: Theme.of(context).textTheme.bodyMedium,
//                             maxLines: 3,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                           const SizedBox(height: 12),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Expanded(
//                                 child: Text(
//                                   article.sourceName,
//                                   style: TextStyle(
//                                     fontStyle: FontStyle.italic,
//                                     color: Theme.of(context).primaryColor,
//                                   ),
//                                   overflow: TextOverflow.ellipsis,
//                                 ),
//                               ),
//                               Text(
//                                 DateFormat(
//                                   'MMM d, yyyy',
//                                 ).format(article.publishedAt),
//                                 style: const TextStyle(color: Colors.grey),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
//
//   Future<void> launchArticleUrl(BuildContext context, String url) async {
//     final uri = Uri.parse(url);
//
//     final canLaunch = await launchUrl(uri);
//     if (!canLaunch) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Could not open the link'),
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//     }
//   }
// }
