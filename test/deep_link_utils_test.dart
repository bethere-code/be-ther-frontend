import 'package:flutter_test/flutter_test.dart';

import 'package:be_ther/core/routing/deep_link_utils.dart';

void main() {
  group('eventRouteFromUri', () {
    test('parses https share links', () {
      expect(
        eventRouteFromUri(Uri.parse('https://be-ther.com/e/507f1f77bcf86cd799439011')),
        '/e/507f1f77bcf86cd799439011',
      );
    });

    test('parses path-only share links from the platform router', () {
      expect(
        eventRouteFromUri(Uri.parse('/e/507f1f77bcf86cd799439011')),
        '/e/507f1f77bcf86cd799439011',
      );
    });

    test('parses custom scheme links', () {
      expect(
        eventRouteFromUri(Uri.parse('bether://e/507f1f77bcf86cd799439011')),
        '/e/507f1f77bcf86cd799439011',
      );
    });

    test('rewrites legacy /event/ paths', () {
      expect(
        eventRouteFromUri(Uri.parse('/event/507f1f77bcf86cd799439011')),
        '/e/507f1f77bcf86cd799439011',
      );
    });

    test('ignores unrelated links', () {
      expect(eventRouteFromUri(Uri.parse('https://be-ther.com/feed')), isNull);
      expect(eventRouteFromUri(Uri.parse('mailto:test@example.com')), isNull);
    });
  });
}
