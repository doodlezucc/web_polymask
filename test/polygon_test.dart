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

  group('Utils', () {
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
  });

  group('Union', () {
    test('0 Overlaps', () {
      var box =
          Polygon(points: [Point(1, 3), Point(1, 4), Point(2, 4), Point(2, 3)]);
      expectUnion(polygon, box, [polygon, box]);

      box =
          Polygon(points: [Point(5, 3), Point(5, 4), Point(6, 4), Point(6, 3)]);
      expectUnion(polygon, box, [polygon]);
    });

    test('1 Overlap', () {
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

      expectUnion(upscale(polygon, 100), upscale(rect, 100), [
        Polygon(points: expectedPoints),
      ]);
    });

    test('1 Overlap (Overlapping Starting Point)', () {
      var rect = Polygon(points: [
        Point(5, 6),
        Point(5, 9),
        Point(8, 9),
        Point(8, 6),
      ]);

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

      expectUnion(upscale(polygon, 100), upscale(rect, 100), [
        Polygon(points: expectedPoints),
      ]);
    });

    test('2 Overlaps, 0 Holes', () {
      var diagonal =
          Polygon(points: [Point(4, 1), Point(5, 1), Point(8, 4), Point(8, 5)]);

      var expectedPoints = [
        ...polygon.points,
        ...diagonal.points,
        Point(5, 2),
        Point(6, 2),
        Point(7, 3),
        Point(7, 4),
      ];

      expectUnion(polygon, diagonal, [Polygon(points: expectedPoints)]);
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

      expectUnion(polygon, uShape, [
        Polygon(points: expectedPoly),
        Polygon(points: expectedHole, positive: false),
      ]);
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

      expectUnion(polygon, uShape2, [
        Polygon(points: expectedPoly),
        Polygon(points: expectedHole, positive: false),
      ]);
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

      expectUnion(polyUp, uShape, [
        Polygon(points: expectedPoly),
        Polygon(points: expectedHole1, positive: false),
        Polygon(points: expectedHole2, positive: false),
      ]);
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

      expectUnion(polygon, rect, [Polygon(points: expectedPoly)]);
    });

    test('Create Hole Inside Polygon', () {
      var holeInside = Polygon(points: [
        Point(6, 3),
        Point(6, 7),
        Point(4, 4),
      ], positive: false);

      expectUnion(
        polygon,
        holeInside,
        [polygon, holeInside],
        bidirectional: false,
      );
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

      expectUnion(
        polygon,
        uShape,
        [Polygon(points: expectedPoly)],
        bidirectional: false,
      );
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

      expectUnion(
        polygon,
        uShape,
        [
          Polygon(points: expectedPoly),
          Polygon(points: expectedRect),
        ],
        bidirectional: false,
      );
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

      expectUnion(
        polygon,
        rect,
        [Polygon(points: expectedPoly)],
        bidirectional: false,
      );
    });

    test('Remove Nothing at Corners', () {
      var cut = Polygon(points: [
        Point(1, 2),
        Point(3, 5),
        Point(7, 8),
        Point(1, 8),
      ], positive: false);

      expectUnion(polygon, cut, [polygon, cut], bidirectional: false);
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

      expectUnion(polygon, cut, [Polygon(points: expectedPoly)]);
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

      expectUnion(
        polygon,
        diagonal,
        [Polygon(points: poly1), Polygon(points: poly2)],
        bidirectional: false,
      );
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

      expectUnion(
        polygon,
        cut,
        [
          Polygon(points: poly1),
          Polygon(points: poly2),
          Polygon(points: poly3),
        ],
        bidirectional: false,
      );
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

      expectUnion(
        positive,
        cut,
        [Polygon(points: poly)],
        bidirectional: false,
      );
    });

    test('Duplicate Intersections (Noise Edge Case)', () {
      final a = parse(
          '360,283 354,288 334,292 314,288 297,275 286,257 284,237 284,233 291,213 305,198 324,189 344,189 358,195 371,189 391,189 410,198 424,213 431,233 429,253 418,271 401,284 381,288 361,284');
      final b = parse(
          '361,284 344,271 333,253 331,233 338,213 352,198 371,189 391,189 410,198 424,213 431,233 429,253 418,271 401,284 381,288');

      final pA = Polygon(points: a);
      final pB = Polygon(points: b);

      final result = expectUnionEqual(pA, pB);
      expect(result.length, 1);
      expect(result.first.boundingBox, pA.boundingBox);
    });

    test('Unionize Self', () {
      expectUnion(polygon, polygon, [polygon], bidirectional: false);
    });

    test('Edge Overlap', () {
      final a = parse(
          '183,95 174,79 260,79 235,122 238,122 195,197 171,154 160,173 117,98 159,98 157,95');
      final b = parse('157,95 243,95 200,170');

      final pA = Polygon(points: a);
      final pB = Polygon(points: b);

      expectUnion(pA, pB, [pA]);
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

void expectUnion(Polygon a, Polygon b, List<Polygon> expected,
    {bool bidirectional = true}) {
  final matcher = unorderedMatches(
      expected.map((p) => polygonMatch(p.points, positive: p.positive)));

  expect(union(a, b), matcher);
  if (bidirectional) expect(union(b, a), matcher);
}

Iterable<Polygon> expectUnionEqual(Polygon a, Polygon b) {
  var result1 = union(a, b);
  final matcher = unorderedEquals(
      result1.map((e) => polygonMatch(e.points, positive: e.positive)));

  expect(union(b, a), matcher);
  return result1;
}

Matcher polygonMatch(List<Point<int>> points, {bool positive}) {
  var matcher = TypeMatcher<Polygon>();

  if (positive != null) {
    matcher = matcher.having((p) => p.positive, 'positive', positive);
  }

  return matcher.having(
    (p) => p.points,
    'points',
    ringMatch(points),
  );
}

Matcher ringMatch<S>(List<S> ring) =>
    allOf(hasLength(ring.length), _RingMatcher<S>(ring));

class _RingMatcher<S> extends TypeMatcher<List<S>> {
  final List<S> ring;

  _RingMatcher(this.ring);

  @override
  bool matches(Object other, Map matchState) {
    if (other is List<S>) {
      if (ring.isEmpty) return true;

      final offset = other.indexOf(ring[0]);

      for (var i = 0; i < ring.length; i++) {
        final item = ring[i];
        final pair = other[(i + offset) % ring.length];
        if (item != pair) return false;
      }

      return true;
    }

    return false;
  }
}
