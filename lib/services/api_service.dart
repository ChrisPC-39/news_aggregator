import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article_model.dart';

class ApiService {
  static const String _apiKey = '820af07e70224a6db48476c866c892ae';
  static const String _baseUrl = 'https://newsapi.org/v2/everything';

  Future<List<Article>> fetchNews(Map<String, dynamic> searchParams) async {
    // Build the query parameters string
    final queryParameters = {'apiKey': _apiKey};

    // Add parameters from the form if they are not null or empty
    if (searchParams['q'] != null && searchParams['q'].isNotEmpty) {
      queryParameters['q'] = searchParams['q'];
    }
    if (searchParams['searchIn'] != null &&
        searchParams['searchIn'].isNotEmpty) {
      queryParameters['searchIn'] = searchParams['searchIn'];
    }
    if (searchParams['sources'] != null && searchParams['sources'].isNotEmpty) {
      queryParameters['sources'] = searchParams['sources'];
    }
    if (searchParams['domains'] != null && searchParams['domains'].isNotEmpty) {
      queryParameters['domains'] = searchParams['domains'];
    }
    if (searchParams['excludeDomains'] != null &&
        searchParams['excludeDomains'].isNotEmpty) {
      queryParameters['excludeDomains'] = searchParams['excludeDomains'];
    }
    if (searchParams['from'] != null) {
      // Format DateTime to ISO 8601 string
      queryParameters['from'] =
          (searchParams['from'] as DateTime).toIso8601String();
    }
    if (searchParams['to'] != null) {
      queryParameters['to'] =
          (searchParams['to'] as DateTime).toIso8601String();
    }
    if (searchParams['language'] != null) {
      queryParameters['language'] = searchParams['language'];
    }
    if (searchParams['sortBy'] != null) {
      queryParameters['sortBy'] = searchParams['sortBy'];
    }
    if (searchParams['pageSize'] != null) {
      queryParameters['pageSize'] = searchParams['pageSize'];
    }
    if (searchParams['page'] != null) {
      queryParameters['page'] = searchParams['page'];
    }

    // Create the final URI
    final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParameters);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body);

      if (json['status'] == 'ok') {
        final List<dynamic> articlesJson = json['articles'];
        // Use List.map to convert the list of json objects to a list of Article objects
        return articlesJson.map((json) => Article.fromJson(json)).toList();
      } else {
        // Handle API errors (e.g., bad request, key invalid)
        throw Exception('API Error: ${json['message']}');
      }
    } else {
      // Handle HTTP errors (e.g., 404, 500)
      throw Exception(
        'Failed to load news. Status code: ${response.statusCode}',
      );
    }
  }
}
