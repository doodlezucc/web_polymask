import 'dart:math';

import 'package:test/test.dart';
import 'package:web_polymask/math/polymath.dart';
import 'package:web_polymask/polygon.dart';

void main() {
  group('Polygon Calculus', () {
    var polygon = Polygon(points: [
      Point(3, 5),
      Point(4, 3),
      Point(1, 2),
      Point(7, 2),
      Point(7, 8),
    ]);

    test('Polygon Bounding Box', () {
      expect(polygon.boundingBox, equals(Rectangle(1, 2, 6, 6)));
    });

    test('Segment Rough Intersect (using bounding boxes)', () {
      expect(
          segmentRoughIntersect(
            Point(0, 0),
            Point(2, 2),
            Point(3, 0),
            Point(3, 3),
          ),
          equals(false));
      expect(
          segmentRoughIntersect(
            Point(0, 0),
            Point(2, 2),
            Point(2, 0),
            Point(1, 0),
          ),
          equals(true));
      expect(
          segmentRoughIntersect(
            Point(2, 2),
            Point(2, 4),
            Point(3, 2),
            Point(2, 4),
          ),
          equals(true));
    });

    test('Segment Intersection Point', () {
      expect(
          segmentIntersect(
            Point(2, 2),
            Point(2, 4),
            Point(3, 3),
            Point(2, 0),
          ),
          equals(null));
      expect(
          segmentIntersect(
            Point(0, 0),
            Point(2, 2),
            Point(2, 0),
            Point(0, 2),
          ),
          equals(Point(1.0, 1.0)));
      expect(
          segmentIntersect(
            Point(0, 2), // horizontal line
            Point(4, 2),

            Point(1, 0), // diagonal line
            Point(4, 4),
          ),
          equals(Point(2.5, 2)));
    });
  });
}
