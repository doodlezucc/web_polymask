import 'dart:math';

import 'package:test/test.dart';
import 'package:web_polygons/polygon.dart';

void main() {
  group('Polygon Calculus', () {
    var polygon = Polygon(points: [
      Point(3, 5),
      Point(4, 3),
      Point(1, 2),
      Point(7, 4),
      Point(7, 8),
    ]);

    test('Bounding Box', () {
      expect(polygon.getBoundingBox(), equals(Rectangle(1, 2, 6, 6)));
    });
  });
}
