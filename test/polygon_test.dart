import 'dart:math';

import 'package:test/test.dart';
import 'package:web_polymask/math/polymath.dart';
import 'package:web_polymask/math/polygon.dart';

void main() {
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
      var box =
          Polygon(points: [Point(1, 3), Point(1, 4), Point(2, 4), Point(2, 3)]);
      expect(union(polygon, box), unorderedEquals([polygon, box]));

      box =
          Polygon(points: [Point(5, 3), Point(5, 4), Point(6, 4), Point(6, 3)]);
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
      var diagonal =
          Polygon(points: [Point(4, 1), Point(5, 1), Point(8, 4), Point(8, 5)]);

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

    test('2 Overlaps, 1 Hole', () {
      var expectedPoly = [
        ...polygon.points,
        Point(7, 3),
        Point(9, 3),
        Point(9, 7),
        Point(7, 7),
      ];
      var expectedHole = [Point(7, 4), Point(8, 4), Point(8, 6), Point(7, 6)];

      void _test2overlaps1hole(Polygon a, Polygon b) {
        var result = union(a, b);

        expect(result.length, 2);

        expect(result.first.positive, true);
        expect(result.first.points, unorderedEquals(expectedPoly));

        expect(result.last.positive, false);
        expect(result.last.points, unorderedEquals(expectedHole));
      }

      _test2overlaps1hole(polygon, uShape);
      _test2overlaps1hole(uShape, polygon);
    });

    test('2 Overlaps, 1 Hole (Overlapping Starting Point)', () {
      // Rounding makes the order of polygons matter in case of an intersection
      // located exactly in the middle of two integers. Because this isn't a
      // relevant problem in real applications, this case is consciously being
      // avoided here.
      var uShape2 = Polygon(points: [
        Point(6, 3),
        Point(9, 3),
        Point(9, 10),
        Point(4, 10),
        Point(4, 5),
        Point(6, 5), // previously 5,5
        Point(6, 9), // previously 5,9
        Point(8, 9),
        Point(8, 4),
        Point(6, 4),
      ]);

      var expectedPoly = [
        ...polygon.points.take(polygon.points.length - 1),
        Point(7, 3),
        Point(9, 3),
        Point(9, 10),
        Point(4, 10),
        Point(4, 6),
      ];
      var expectedHole = [
        Point(7, 4),
        Point(8, 4),
        Point(8, 9),
        Point(6, 9), // previously 5,9
        Point(6, 7), // previously 5,7
        Point(7, 8),
      ];

      void _test2overlaps1hole(Polygon a, Polygon b, bool order) {
        var result = union(a, b);

        expect(result.length, 2);

        expect(result.last.positive, order);
        expect(result.last.points,
            unorderedEquals(order ? expectedPoly : expectedHole));

        expect(result.first.positive, !order);
        expect(result.first.points,
            unorderedEquals(order ? expectedHole : expectedPoly));
      }

      _test2overlaps1hole(polygon, uShape2, true);
      _test2overlaps1hole(uShape2, polygon, false);
    });

    test('2 Holes', () {
      var polyUp = upscale(polygon, 100);
      var uShape = Polygon(points: [
        Point(600, 300),
        Point(900, 300),
        Point(900, 1000),
        Point(400, 1000),
        Point(400, 500),
        Point(500, 500),
        Point(500, 700),
        Point(800, 700),
        Point(800, 400),
        Point(600, 400),
      ]);

      var expectedPoly = [
        ...polyUp.points.take(polyUp.points.length - 1),
        Point(700, 300),
        Point(900, 300),
        Point(900, 1000),
        Point(400, 1000),
        Point(400, 575),
      ];
      var expectedHole1 = [
        Point(700, 400),
        Point(800, 400),
        Point(800, 700),
        Point(700, 700),
      ];
      var expectedHole2 = [
        Point(500, 650),
        Point(500, 700),
        Point(567, 700),
      ];

      void _test2overlaps1hole(Polygon a, Polygon b, bool order) {
        var result = union(a, b);

        expect(result.length, 3);

        expect(result.first.points,
            unorderedEquals(order ? expectedHole2 : expectedPoly));
        expect(result.elementAt(1).points,
            unorderedEquals(order ? expectedPoly : expectedHole2));
        expect(result.last.points, unorderedEquals(expectedHole1));

        expect(result.first.positive, !order);
        expect(result.elementAt(1).positive, order);
        expect(result.last.positive, false);
      }

      _test2overlaps1hole(polyUp, uShape, true);
      _test2overlaps1hole(uShape, polyUp, false);
    });

    test('Dealing with Duplicates', () {
      var rect = Polygon(points: [
        Point(3, 5),
        Point(3, 8),
        Point(7, 8),
        Point(7, 5),
      ]);

      var expectedPoly = [
        ...polygon.points,
        Point(3, 8),
      ];

      void _testDoubles(Polygon a, Polygon b, bool order) {
        var result = union(a, b);

        expect(result.length, 1);
        expect(result.first.positive, true);
        expect(result.first.points, containsAll(expectedPoly));
      }

      _testDoubles(polygon, rect, true);
      _testDoubles(rect, polygon, false);
    });

    test('Create Hole Inside Polygon', () {
      var holeInside = Polygon(points: [
        Point(6, 3),
        Point(6, 7),
        Point(4, 4),
      ], positive: false);

      var polyAndHole = union(polygon, holeInside);
      expect(polyAndHole, [holeInside, polygon]);
    });

    test('Remove from Positive', () {
      var uShape = Polygon(points: [
        Point(6, 3),
        Point(9, 3),
        Point(9, 7),
        Point(6, 7),
        Point(6, 6),
        Point(8, 6),
        Point(8, 4),
        Point(6, 4),
      ], positive: false);

      var expectedPoly = [
        ...polygon.points,
        Point(7, 3), // Cut 1
        Point(6, 3),
        Point(6, 4),
        Point(7, 4),
        Point(7, 6), // Cut 2
        Point(6, 6),
        Point(6, 7),
        Point(7, 7),
      ];

      var result = union(polygon, uShape);

      expect(result.length, 1);
      expect(result.first.positive, true);
      expect(result.first.points, unorderedEquals(expectedPoly));
    });

    test('Remove More from Positive (Edge)', () {
      var uShape = Polygon(points: [
        Point(5, 3),
        Point(8, 3),
        Point(8, 4),
        Point(6, 4),
        Point(6, 5),
        Point(8, 5),
        Point(8, 6),
        Point(5, 6),
      ], positive: false);

      var expectedPoly = [
        ...polygon.points,
        Point(7, 3),
        Point(5, 3),
        Point(5, 6),
        Point(7, 6),
      ];

      var expectedRect = [
        Point(6, 4),
        Point(7, 4),
        Point(7, 5),
        Point(6, 5),
      ];

      var result = union(polygon, uShape);

      expect(result.length, 2);
      expect(result.map((e) => e.positive), [true, true]);
      expect(result.first.points, unorderedEquals(expectedPoly));
      expect(result.last.points, unorderedEquals(expectedRect));
    });

    test('Remove from Positive (Duplicates)', () {
      var rect = Polygon(points: [
        Point(3, 5),
        Point(3, 8),
        Point(7, 8),
        Point(7, 5),
      ], positive: false);

      var expectedPoly = [
        ...polygon.points.take(polygon.points.length - 1),
        Point(7, 5),
      ];

      var result = union(polygon, rect);

      expect(result.length, 1);
      expect(result.first.positive, true);
      expect(result.first.points, unorderedEquals(expectedPoly));
    });

    test('Remove Nothing at Corners', () {
      var cut = Polygon(points: [
        Point(1, 2),
        Point(3, 5),
        Point(7, 8),
        Point(1, 8),
      ], positive: false);

      var result = union(polygon, cut);

      expect(result.length, 2);
      expect(result, anyElement(polygon));
      expect(result, anyElement(cut));
    });

    test('Remove at Corners', () {
      var cut = Polygon(points: [
        Point(1, 2),
        Point(3, 5),
        Point(7, 8),
        Point(6, 3),
      ], positive: false);

      var expectedPoly = [
        Point(1, 2),
        Point(7, 2),
        Point(7, 8),
        Point(6, 3),
      ];

      var result = union(polygon, cut);

      expect(result.length, 1);
      expect(result.first.positive, true);
      expect(result.first.points, unorderedEquals(expectedPoly));
    });

    test('Cut Through Polygon', () {
      var diagonal = Polygon(
          points: [Point(4, 1), Point(5, 1), Point(8, 4), Point(8, 5)],
          positive: false);

      var poly1 = [
        Point(3, 5),
        Point(4, 3),
        Point(1, 2),
        Point(5, 2),
        Point(7, 4),
        Point(7, 8),
      ];
      var poly2 = [Point(6, 2), Point(7, 2), Point(7, 3)];

      var result = union(polygon, diagonal);

      expect(result.length, 2);
      expect(result.first.positive, true);
      expect(result.first.points, unorderedEquals(poly1));
      expect(result.last.positive, true);
      expect(result.last.points, unorderedEquals(poly2));
    });

    test('Multiple Cuts Through Polygon', () {
      var cut = Polygon(
          points: [Point(5, 8), Point(5, 1), Point(8, 4), Point(8, 5)],
          positive: false);

      var poly1 = [Point(6, 7), Point(7, 6), Point(7, 8)];
      var poly2 = [
        Point(3, 5),
        Point(4, 3),
        Point(1, 2),
        Point(5, 2),
        Point(5, 6)
      ];
      var poly3 = [Point(6, 2), Point(7, 2), Point(7, 3)];

      var result = union(polygon, cut);

      expect(result.length, 3);
      expect(result.every((p) => p.positive), true);

      expect(result.first.points, unorderedEquals(poly1));
      expect(result.elementAt(1).points, unorderedEquals(poly2));
      expect(result.last.points, unorderedEquals(poly3));
    });

    test('Remove Single Overlap, Single A-Segment', () {
      var positive = Polygon(
        points: [Point(1, 4), Point(1, 1), Point(6, 1), Point(6, 4)],
      );

      var cut = Polygon(
          points: [Point(5, 5), Point(2, 5), Point(2, 2), Point(5, 2)],
          positive: false);

      var poly = [
        Point(1, 1),
        Point(6, 1),
        Point(6, 4),
        Point(5, 4),
        Point(5, 2),
        Point(2, 2),
        Point(2, 4),
        Point(1, 4),
      ];

      var result = union(positive, cut);

      expect(result.length, 1);
      expect(result.first.positive, true);
      expect(result.first.points, unorderedEquals(poly));
    });

    test('Duplicate Intersections (Noise Edge Case)', () {
      final a = parse(
          '360,283 354,288 334,292 314,288 297,275 286,257 284,237 284,233 291,213 305,198 324,189 344,189 358,195 371,189 391,189 410,198 424,213 431,233 429,253 418,271 401,284 381,288 361,284');
      final b = parse(
          '361,284 344,271 333,253 331,233 338,213 352,198 371,189 391,189 410,198 424,213 431,233 429,253 418,271 401,284 381,288');

      final pA = Polygon(points: a);
      final pB = Polygon(points: b);

      final out = union(pA, pB);
      final out2 = union(pB, pA);

      expect(out.length, 1);
      expect(out2.length, 1);
      expect(out.first.boundingBox, pA.boundingBox);
      expect(out2.first.boundingBox, pA.boundingBox);

      expect(out.first.points, unorderedEquals(out2.first.points));
    });
  });

  group('Intersection', () {
    test('0 Overlaps', () {
      var smallSquare = Polygon(points: [
        Point(0, 0),
        Point(1, 0),
        Point(1, 1),
        Point(0, 1),
      ]);

      var result = intersection(smallSquare, polygon);
      expect(result.length, 0);
    });

    test('One Contains the Other', () {
      var bigSquare = Polygon(points: [
        Point(0, 0),
        Point(10, 0),
        Point(10, 10),
        Point(0, 10),
      ]);

      var result = intersection(bigSquare, polygon);

      expect(result.length, 1);
      expect(result.first.positive, true);
      expect(result.first.points, unorderedEquals(polygon.points));
      expect(result, intersection(polygon, bigSquare));
    });

    test('1 Overlap', () {
      // Intersect with 7,2 -> 7,8
      var rect = Polygon(points: [
        Point(5, 3),
        Point(5, 5),
        Point(9, 5),
        Point(9, 3),
      ]);

      var expected = [Point(5, 3), Point(5, 5), Point(7, 5), Point(7, 3)];

      var result = intersection(rect, polygon);

      expect(result.length, 1);
      expect(result.first.positive, true);
      expect(result.first.points, unorderedEquals(expected));
      expect(
          intersection(polygon, rect).first.points, unorderedEquals(expected));
    });

    test('Handle Corners', () {
      var rect = Polygon(points: [
        Point(7, 8),
        Point(3, 8),
        Point(3, 5),
        Point(7, 5),
      ]);

      var expected = [Point(7, 8), Point(3, 5), Point(7, 5)];

      var result = intersection(rect, polygon);

      expect(result.length, 1);
      expect(result.first.positive, true);
      expect(result.first.points, unorderedEquals(expected));
    });

    test('2 Overlaps, 0 Holes', () {
      var diagonal =
          Polygon(points: [Point(4, 1), Point(5, 1), Point(8, 4), Point(8, 5)]);

      var expectedPoints = [Point(5, 2), Point(6, 2), Point(7, 3), Point(7, 4)];

      var result = intersection(polygon, diagonal);

      expect(result.length, 1);
      expect(result.first.positive, true);
      expect(result.first.points, unorderedEquals(expectedPoints));
    });

    test('2 Overlaps, 1 Hole', () {
      var poly1 = [Point(6, 3), Point(7, 3), Point(7, 4), Point(6, 4)];
      var poly2 = [Point(6, 6), Point(7, 6), Point(7, 7), Point(6, 7)];

      var result = intersection(polygon, uShape);

      expect(result.length, 2);
      expect(result.map((e) => e.positive), [true, true]);
      expect(result.first.points, unorderedEquals(poly1));
      expect(result.last.points, unorderedEquals(poly2));
    });
  });
}

/// Prints a list of polygons as SVG polygon data (debugging).
void printPolys(Iterable<Polygon> result) {
  for (var poly in result) {
    print(poly.points.map((p) => '${p.x},${p.y}').join(' '));
  }
}

/// Parses a list of 2D points in SVG polygon data format.
List<Point<int>> parse(String s) {
  return s.split(' ').map((co) {
    var parts = co.split(',');
    return Point(int.parse(parts[0]), int.parse(parts[1]));
  }).toList();
}
