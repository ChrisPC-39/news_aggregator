import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;

class DefaultContentParser {
  static const _timeout = Duration(seconds: 10);

  static const _contentSelectors = [
    'article',
    '[role="main"]',
    '.article-body',
    '.article-content',
    '.post-content',
    '.entry-content',
    'main',
  ];

  static const _tagsToRemove = [
    'script', 'style', 'nav', 'header', 'footer',
    'aside', 'iframe', 'noscript',
  ];

  Future<String?> fetchContent(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Mozilla/5.0 (compatible; NewsApp/1.0)'},
      ).timeout(_timeout);

      if (response.statusCode != 200) return null;

      final document = parse(utf8.decode(response.bodyBytes));

      for (final tag in _tagsToRemove) {
        document.querySelectorAll(tag).forEach((e) => e.remove());
      }

      String? content;
      for (final selector in _contentSelectors) {
        final element = document.querySelector(selector);
        if (element != null) {
          content = element.text;
          break;
        }
      }

      content ??= document.body?.text;

      if (content == null) return null;

      return content
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .join('\n')
          .trim();
    } catch (e) {
      debugPrint('Failed to fetch article content from $url: $e');
      return null;
    }
  }
}