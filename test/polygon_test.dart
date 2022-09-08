import 'dart:math';

import 'package:test/test.dart';
import 'package:web_polymask/math/polygon_state.dart';
import 'package:web_polymask/math/polymath.dart';
import 'package:web_polymask/math/polygon.dart';
import 'package:web_polymask/math/ring_search.dart';

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

  group('Polygon Simplicity', () {
    test('Test Shape', () {
      expect(polygon.isSimple(), true);
    });

    test('Negative', () {
      final hourglass =
          Polygon(points: [Point(0, 0), Point(1, 0), Point(0, 1), Point(1, 1)]);

      expect(hourglass.isSimple(), false);
    });

    test('Collision at Segment Ends', () {
      final a = Polygon(
          points: parse(
              '202,232 201,233 217,233 212,242 213,242 210,247 202,233 201,235 199,232'));

      expect(a.isSimple(), true);
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

      var expectedPoints =
          parse('5,2 4,1 5,1 6,2 7,2 7,3 8,4 8,5 7,4 7,8 3,5 4,3 1,2');

      expectUnion(polygon, diagonal, [Polygon(points: expectedPoints)]);
    });

    test('2 Overlaps, 1 Hole', () {
      var expectedPoly = parse('7,3 9,3 9,7 7,7 7,8 3,5 4,3 1,2 7,2');
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
        Point(567, 700),
        Point(500, 700),
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

      var expectedPoly =
          parse('7,3 6,3 6,4 7,4 7,6 6,6 6,7 7,7 7,8 3,5 4,3 1,2 7,2');

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

      var expectedPoly = parse('7,3 5,3 5,6 7,6 7,8 3,5 4,3 1,2 7,2');

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

      expectUnion(polygon, cut, [polygon], bidirectional: false);
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

      expectUnion(
        polygon,
        cut,
        [Polygon(points: expectedPoly)],
        bidirectional: false,
      );
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
          points: [Point(4, 8), Point(5, 1), Point(8, 4), Point(8, 5)],
          positive: false);

      var poly1 = [Point(6, 7), Point(7, 6), Point(7, 8)];
      var poly2 = [
        Point(3, 5),
        Point(4, 3),
        Point(1, 2),
        Point(5, 2),
        Point(4, 6)
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

    test('Subtraction Creates Self-Intersection', () {
      var positive = Polygon(
        points: parse('560,317 552,304 554,289 570,289 565,278 581,278'),
      );

      var cut = Polygon(
        points: parse('604,230 647,305 561,305'),
        positive: false,
      );

      var part1 = parse('561,305 566,305 560,317 552,304 554,289 570,289');
      var part2 = parse('565,278 576,278 570,289');

      expectUnion(
        positive,
        cut,
        [Polygon(points: part1), Polygon(points: part2)],
        bidirectional: false,
      );
    });

    test('Addition Creates Self-Intersection', () {
      final a = Polygon(points: parse('359,320 402,395 316,395'));
      final b = Polygon(
          points: parse(
              '500,300 418,394 403,394 410,381 394,381 401,368 386,368 393,355 380,355 387,342'));

      var part1 = parse('401,368 394,381 387,368');
      var part2 = parse(
          '402,395 316,395 359,320 386,368 393,355 380,355 387,342 500,300 418,394 403,394 410,381 394,381');

      expectUnion(
        a,
        b,
        [Polygon(points: part1, positive: false), Polygon(points: part2)],
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

  group('Merge', () {
    final hollowSquare = PolygonState.assignParents({
      fromRect(Rectangle(0, 0, 15, 15)),
      fromRect(Rectangle(1, 1, 13, 13), positive: false),
    });
    final island = fromRect(Rectangle(2, 2, 11, 11));
    final topVertical = fromRect(Rectangle(7, -1, 1, 5));

    final doubleSquare = PolygonState.assignChildrenBase(hollowSquare, {
      island,
      fromRect(Rectangle(3, 3, 9, 9), positive: false),
    });
    final miniIsland = fromRect(Rectangle(4, 4, 7, 7));

    test('Island', () {
      expectMerge(
        hollowSquare,
        island,
        PolygonState.assignChildrenBase(hollowSquare, {island}),
      );
    });

    test('Island inside Island', () {
      expectMerge(
        doubleSquare,
        miniIsland,
        PolygonState.assignChildrenBase(doubleSquare, {miniIsland}),
      );
    });

    test('Break open Hollow Square', () {
      expectMerge(
          hollowSquare,
          topVertical.copy(positive: false),
          PolygonState.assignParents({
            Polygon(points: [
              Point(0, 0),
              Point(7, 0),
              Point(7, 1),
              Point(1, 1),
              Point(1, 14),
              Point(14, 14),
              Point(14, 1),
              Point(8, 1),
              Point(8, 0),
              Point(15, 0),
              Point(15, 15),
              Point(0, 15),
            ]),
          }));
    });

    test('Break open Double Square Islands', () {
      final result =
          mergePolygon(doubleSquare, topVertical.copy(positive: false));

      final hierarchy = result.toHierarchy();

      expect(hierarchy, hasLength(2));
      expect(hierarchy, everyElement((HPolygon p) => p.polygon.positive));
      expect(result.isValid(), isTrue);
      expect(
        hierarchy,
        everyElement(TypeMatcher<HPolygon>()
            .having((p) => p.children, 'Children', isEmpty)
            .having((p) => p.polygon.points, 'Points', hasLength(12))),
      );
    });
  });
}

Polygon fromRect(Rectangle<int> rect, {bool positive = true}) {
  return Polygon(positive: positive, points: [
    rect.bottomLeft,
    rect.bottomRight,
    rect.topRight,
    rect.topLeft,
  ]);
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

void expectUnion(
  Polygon a,
  Polygon b,
  Iterable<Polygon> expected, {
  bool bidirectional = true,
  bool checkPointsInOrder = true,
}) {
  final matcher =
      PolygonOperationMatcher(expected, checkOrder: checkPointsInOrder);

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

void expectMergeHierarchy(
    PolygonState state, Polygon polygon, Set<HPolygon> expected) {
  expect(
    mergePolygon(state, polygon),
    TypeMatcher<PolygonState>().having(
      (state) => state.toHierarchy(),
      'Hierarchy',
      hierarchyMatch(expected),
    ),
  );
}

Matcher hierarchyMatch(Set<HPolygon> expected) {
  return unorderedMatches(expected.map(hpolyMatch));
}

Matcher hpolyMatch(HPolygon expected) {
  return TypeMatcher<HPolygon>()
      .having(
          (hp) => hp.polygon,
          'Polygon',
          polygonMatch(
            expected.polygon.points,
            positive: expected.polygon.positive,
            requireSimple: false,
          ))
      .having(
          (hp) => hp.children, 'Children', hierarchyMatch(expected.children));
}

void expectMerge(PolygonState state, Polygon polygon, PolygonState expected) {
  final matcher = stateMatch(expected);
  expect(mergePolygon(state, polygon), matcher);
}

Matcher stateMatch(PolygonState expected) {
  return TypeMatcher<PolygonState>()
      .having((p0) => p0.isValid(), 'Validity', isTrue)
      .having((state) => state.toHierarchy(), 'Hierarchy',
          hierarchyMatch(expected.toHierarchy()));
}

Matcher polygonMatch(
  List<Point<int>> points, {
  bool requireSimple = true,
  bool checkOrder = true,
  bool positive,
  Map map,
}) {
  var matcher = TypeMatcher<Polygon>();

  if (positive != null) {
    matcher = matcher.having((p) => p.positive, 'Pole', positive);
  }

  if (requireSimple) {
    matcher = matcher.having((p) => p.isSimple(), 'Simplicity', isTrue);
  }

  return matcher.having((p) {
    forceClockwise(p);
    return p.points;
  }, 'points',
      checkOrder ? ringMatch(points, map: map) : unorderedEquals(points));
}

class PolygonOperationMatcher extends TypeMatcher<Iterable<Polygon>> {
  Matcher _matcher;
  final Iterable<Polygon> expected;
  final Map errorMap = {};

  PolygonOperationMatcher(this.expected, {bool checkOrder = true}) {
    _matcher = unorderedMatches(expected.map((p) => polygonMatch(
          p.points,
          positive: p.positive,
          map: errorMap,
          checkOrder: checkOrder,
        )));
  }

  @override
  bool matches(item, Map matchState) => _matcher.matches(item, matchState);

  @override
  Description describe(Description description) =>
      description.addDescriptionOf(expected);

  @override
  Description describeMismatch(covariant Iterable<Polygon> mismatch,
      Description desc, Map matchState, bool verbose) {
    if (errorMap.isEmpty) {
      for (var i = 0; i < mismatch.length; i++) {
        if (!mismatch.elementAt(i).isSimple()) {
          desc.add('Contains self-intersecting polygon at index $i\n');
        }
      }
    }

    for (List<Point> other in errorMap.keys) {
      final RingSearchError error = errorMap[other];
      final index = error.errorInRing;

      desc.add("Doesn't match index $index:\n");

      for (var i = 0; i < other.length; i++) {
        final r = error.ring[i];
        final pair = other[(i + error.offset) % other.length];

        var s = '  $r | $pair';
        if (i == index) s += ' <---';

        desc.add('$s\n');
      }
    }

    return desc;
  }
}

Matcher ringMatch<S>(List<S> ring, {Map map}) =>
    allOf(hasLength(ring.length), _RingMatcher<S>(ring, map));

class _RingMatcher<S> extends TypeMatcher<List<S>> {
  final Map map;
  final List<S> ring;

  _RingMatcher(this.ring, this.map);

  @override
  bool matches(Object other, Map matchState) {
    if (other is List<S>) {
      final error = ringMismatch(ring, other);
      if (error == null) return true;

      if (map != null) map[other] = error;
    }

    return false;
  }
}
