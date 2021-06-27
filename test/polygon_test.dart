import 'dart:math';

import 'package:test/test.dart';
import 'package:web_polymask/math/polymath.dart';
import 'package:web_polymask/math/polygon.dart';

void main() {
  group('Polygon Calculus', () {
    var polygon = Polygon(points: [
      Point(3, 5),
      Point(4, 3),
      Point(1, 2),
      Point(7, 2),
      Point(7, 8),
    ]);

    var rect = Polygon(points: [
      Point(2, 4),
      Point(2, 7),
      Point(4, 7),
      Point(4, 4),
    ]);

    test('Polygon Bounding Box', () {
      expect(polygon.boundingBox, Rectangle(1, 2, 6, 6));
    });

    test('Segment Intersection (rough)', () {
      expect(
          segmentRoughIntersect(
            Point(0, 0),
            Point(2, 2),
            Point(3, 0),
            Point(3, 3),
          ),
          false);
      expect(
          segmentRoughIntersect(
            Point(0, 0),
            Point(2, 2),
            Point(2, 0),
            Point(1, 0),
          ),
          true);
      expect(
          segmentRoughIntersect(
            Point(2, 2),
            Point(2, 4),
            Point(3, 2),
            Point(2, 4),
          ),
          true);
    });

    test('Segment Intersection Point', () {
      expect(
          segmentIntersect(
            Point(2, 2),
            Point(2, 4),
            Point(3, 3),
            Point(2, 0),
          ),
          null);
      expect(
          segmentIntersect(
            Point(0, 0),
            Point(2, 2),
            Point(2, 0),
            Point(0, 2),
          ),
          Point(1.0, 1.0));
      expect(
          segmentIntersect(
            Point(0, 2), // horizontal line
            Point(4, 2),

            Point(1, 0), // diagonal line
            Point(4, 4),
          ),
          Point(2.5, 2));
    });

    test('Point Inside Polygon', () {
      expect(pointInsidePolygon(Point(1, 1), polygon), false);
      expect(pointInsidePolygon(Point(6, 3), polygon), true);
      expect(pointInsidePolygon(Point(5, 7), polygon), false);
      expect(pointInsidePolygon(Point(4, 5), polygon), true);
      expect(pointInsidePolygon(Point(3, 4), polygon), false);
    });

    test('Signed Area', () {
      expect(signedArea(polygon), -17.5);
      expect(signedArea(rect), 6);
    });

    group('Union', () {
      test('0 Overlaps', () {
        var box = Polygon(
            points: [Point(1, 3), Point(1, 4), Point(2, 4), Point(2, 3)]);
        expect(union(polygon, box), unorderedEquals([polygon, box]));

        box = Polygon(
            points: [Point(5, 3), Point(5, 4), Point(6, 4), Point(6, 3)]);
        expect(union(polygon, box), orderedEquals([polygon]));
        expect(union(box, polygon), orderedEquals([polygon]));
      });

      test('1 Overlap', () {
        var result = union(upscale(polygon, 100), upscale(rect, 100));
        var expectedPoints = [
          Point(400, 575),
          Point(400, 700),
          Point(200, 700),
          Point(200, 400),
          Point(350, 400),
          Point(400, 300),
          Point(100, 200),
          Point(700, 200),
          Point(700, 800),
        ];

        expect(result.length, 1);
        expect(result.first.points, unorderedEquals(expectedPoints));
      });
      test('1 Overlap (Overlapping Starting Point)', () {
        var rect = Polygon(points: [
          Point(5, 6),
          Point(5, 9),
          Point(8, 9),
          Point(8, 6),
        ]);

        var result = union(upscale(polygon, 100), upscale(rect, 100));
        var expectedPoints = [
          Point(300, 500),
          Point(400, 300),
          Point(100, 200),
          Point(700, 200),
          Point(700, 600),
          Point(800, 600),
          Point(800, 900),
          Point(500, 900),
          Point(500, 650),
        ];

        expect(result.length, 1);
        expect(result.first.points, unorderedEquals(expectedPoints));
      });

      test('2 Overlaps, 0 Holes', () {
        var diagonal = Polygon(
            points: [Point(4, 1), Point(5, 1), Point(8, 4), Point(8, 5)]);

        var result = union(polygon, diagonal);
        var expectedPoints = [
          ...polygon.points,
          ...diagonal.points,
          Point(5, 2),
          Point(6, 2),
          Point(7, 3),
          Point(7, 4),
        ];

        expect(result.length, 1);
        expect(result.first.points, unorderedEquals(expectedPoints));
      });
    });

    test('2 Overlaps, 1 Hole', () {
      var uShape = Polygon(points: [
        Point(6, 3),
        Point(9, 3),
        Point(9, 7),
        Point(6, 7),
        Point(6, 6),
        Point(8, 6),
        Point(8, 4),
        Point(6, 4),
      ]);

      var result = union(polygon, uShape);
      var expectedPoly = [
        ...polygon.points,
        Point(7, 3),
        Point(9, 3),
        Point(9, 7),
        Point(7, 7),
      ];

      var expectedHole = [Point(7, 4), Point(8, 4), Point(8, 6), Point(7, 6)];

      // Convert points to SVG polygon data (debugging)
      print(result.first.points.map((p) => '${p.x},${p.y}').join(' '));

      expect(result.length, 2);
      expect(result.first.points, unorderedEquals(expectedPoly));
      expect(result.last.points, unorderedEquals(expectedHole));
    });
  });
}
