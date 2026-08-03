import 'package:flutter/foundation.dart';

/// Lightweight helpers for commerce links (e.g., Amazon search).
class CommerceService {
  // Amazon Associates tag - hardcoded for immediate use
  static const String amazonAssociateTag = 'adaptlyappid-20';

  /// Build an Amazon search URL for a query. We intentionally use a generic
  /// search to avoid scraping and to work without the Product Advertising API.
  /// If an associate tag is provided at build-time, it will be appended.
  Uri amazonSearchUrl(String query) {
    try {
      final q = query.trim();
      final base = Uri.https('www.amazon.com', '/s', {
        'k': q,
        if (amazonAssociateTag.trim().isNotEmpty) 'tag': amazonAssociateTag.trim(),
      });
      return base;
    } catch (e) {
      debugPrint('CommerceService.amazonSearchUrl error: $e');
      // Fallback to home if somehow invalid
      return Uri.parse('https://www.amazon.com');
    }
  }
}
