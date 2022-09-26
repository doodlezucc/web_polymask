import 'dart:math';

import 'package:grid/grid.dart';
import 'package:test/test.dart';
import 'package:web_polymask/math/polygon_state.dart';
import 'package:web_polymask/math/polymath.dart';
import 'package:web_polymask/math/polygon.dart';

import 'test_helpers.dart';

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

      expect(
          union(polygon, cut).output, contains(polygonMatchInstance(polygon)));
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

      final result = union(pA, pB);
      expect(result, isA<OperationResultTransform>());
      expect(result.output, hasLength(1));
      expect(result.output.first.boundingBox, pA.boundingBox);
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
      expect(result, isA<OperationResultNoOverlap>());
      expect(result.output, isEmpty);
    });

    test('One Contains the Other', () {
      var bigSquare = Polygon(points: [
        Point(0, 0),
        Point(10, 0),
        Point(10, 10),
        Point(0, 10),
      ]);

      var result = intersection(bigSquare, polygon);

      expect(result.output, hasLength(1));
      expect(result.output.first.positive, isTrue);
      expect(result.output.first.points, ringMatch(polygon.points));
      expect(result.runtimeType, intersection(polygon, bigSquare).runtimeType);
      expect(result.output, intersection(polygon, bigSquare).output);
    });

    test('1 Overlap', () {
      // Intersect with 7,2 -> 7,8
      var rect = Polygon(points: [
        Point(5, 3),
        Point(5, 5),
        Point(9, 5),
        Point(9, 3),
      ]);

      var expected = [Point(5, 3), Point(7, 3), Point(7, 5), Point(5, 5)];

      var result = intersection(rect, polygon);

      expect(result, PolygonOperationMatcher([Polygon(points: expected)]));
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

      expect(result.output, hasLength(1));
      expect(result.output.first.positive, isTrue);
      expect(result.output.first.points, ringMatch(expected));
    });

    test('2 Overlaps, 0 Holes', () {
      var diagonal =
          Polygon(points: [Point(4, 1), Point(5, 1), Point(8, 4), Point(8, 5)]);

      var expectedPoints = [Point(5, 2), Point(6, 2), Point(7, 3), Point(7, 4)];

      var result = intersection(polygon, diagonal);

      expect(result.output, hasLength(1));
      expect(result.output.first.positive, isTrue);
      expect(result.output.first.points, ringMatch(expectedPoints));
    });

    test('2 Overlaps, 1 Hole', () {
      var poly1 = [Point(6, 3), Point(7, 3), Point(7, 4), Point(6, 4)];
      var poly2 = [Point(6, 6), Point(7, 6), Point(7, 7), Point(6, 7)];

      var result = intersection(polygon, uShape);

      expect(
        result,
        PolygonOperationMatcher(
          [Polygon(points: poly1), Polygon(points: poly2)],
        ),
      );
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

    test('Join Double Squares', () {
      expectMerge(
          doubleSquare,
          topVertical,
          PolygonState.assignParents({
            Polygon(points: [
              Point(0, 0),
              Point(7, 0),
              Point(7, -1),
              Point(8, -1),
              Point(8, 0),
              Point(15, 0),
              Point(15, 15),
              Point(0, 15),
            ]),
            Polygon(positive: false, points: [
              Point(1, 1),
              Point(7, 1),
              Point(7, 2),
              Point(2, 2),
              Point(2, 13),
              Point(13, 13),
              Point(13, 2),
              Point(8, 2),
              Point(8, 1),
              Point(14, 1),
              Point(14, 14),
              Point(1, 14),
            ]),
            Polygon(positive: false, points: [
              Point(3, 3),
              Point(7, 3),
              Point(7, 4),
              Point(8, 4),
              Point(8, 3),
              Point(12, 3),
              Point(12, 12),
              Point(3, 12),
            ]),
          }));
    });

    test('Simple Root Union', () {
      expectMerge(
          PolygonState({polygon: null}),
          uShape,
          PolygonState.assignParents({
            Polygon(points: parse('3,5 4,3 1,2 7,2 7,3 9,3 9,7 7,7 7,8')),
            Polygon(positive: false, points: parse('7,4 8,4 8,6 7,6')),
          }));
    });

    test('Join Solid and Hollow Square', () {
      expectMerge(
          PolygonState.assignParents({
            // Hollow square
            fromRect(Rectangle(0, 0, 5, 5)),
            fromRect(Rectangle(1, 1, 3, 3), positive: false),

            // Solid square
            fromRect(Rectangle(6, 0, 5, 5)),
          }),
          // Bridge
          fromRect(Rectangle(2, 2, 7, 1)),
          PolygonState.assignParents({
            Polygon(
              points: parse(
                '0,0 5,0 5,2 6,2 6,0 11,0 11,5 6,5 6,3 5,3 5,5 0,5',
              ),
            ),
            Polygon(
              positive: false,
              points: parse('1,1 4,1 4,2 2,2 2,3 4,3 4,4 1,4'),
            ),
          }));
    });

    test('Double Square Split', () {
      expectMerge(
          PolygonState.assignParents({
            fromRect(Rectangle(0, 0, 7, 7)),
            fromRect(Rectangle(1, 1, 5, 5), positive: false),
            fromRect(Rectangle(2, 2, 3, 3)),
          }),
          // Bridge
          Polygon(points: parse('3,-1 4,-1 4,4 -1,4 -1,3 3,3')),
          PolygonState.assignParents({
            Polygon(
              points: parse(
                '0,0 3,0 3,-1 4,-1 4,0 7,0 7,7 0,7 0,4 -1,4 -1,3 0,3',
              ),
            ),
            Polygon(
              positive: false,
              points: parse('2,2 2,3 1,3 1,1 3,1 3,2'),
            ),
            Polygon(
              positive: false,
              points: parse('2,5 5,5 5,2 4,2 4,1 6,1 6,6 1,6 1,4 2,4'),
            ),
          }));
    });

    test('All Possible Fracture Overlaps', () {
      expectMerge(
          PolygonState.assignParents({
            fromRect(Rectangle(1, 1, 7, 6)),
            fromRect(Rectangle(2, 2, 1, 1), positive: false),
            fromRect(Rectangle(2, 4, 1, 1), positive: false),
            fromRect(Rectangle(5, 2, 1, 1), positive: false),
            fromRect(Rectangle(5, 4, 1, 2), positive: false),
          }),
          Polygon(
            points: parse('0,4 4,4 4,0 7,0 7,4 9,4 9,5 0,5'),
            positive: false,
          ),
          PolygonState.assignParents({
            fromRect(Rectangle(1, 1, 3, 3)),
            fromRect(Rectangle(7, 1, 1, 3)),
            Polygon(points: parse('1,5 5,5 5,6 6,6 6,5 8,5 8,7 1,7')),
            fromRect(Rectangle(2, 2, 1, 1), positive: false),
          }));
    });

    test('Redundant Addition Next to Hole', () {
      final state = PolygonState.assignParents({
        fromRect(Rectangle(0, 0, 7, 7)),
        fromRect(Rectangle(5, 1, 1, 5), positive: false),
      });
      expectMerge(state, fromRect(Rectangle(1, 1, 1, 1)), state);
    });

    test('Encase Island', () {
      expectMerge(
        PolygonState.assignParents({
          Polygon(
            points: parse('0,0 7,0 7,7 0,7 0,3 1,3 1,6 6,6 6,1 1,1 1,2 0,2'),
          ),
          fromRect(Rectangle(2, 2, 3, 3)),
          fromRect(Rectangle(3, 3, 1, 1), positive: false),
        }),
        fromRect(Rectangle(0, 1, 1, 3)),
        PolygonState.assignParents({
          fromRect(Rectangle(0, 0, 7, 7)),
          fromRect(Rectangle(1, 1, 5, 5), positive: false),
          fromRect(Rectangle(2, 2, 3, 3)),
          fromRect(Rectangle(3, 3, 1, 1), positive: false),
        }),
      );
    });

    test('Join + Encase', () {
      expectMerge(
        PolygonState.assignParents({
          // Bracket Left
          Polygon(points: parse('0,2 2,2 2,3 1,3 1,6 2,6 2,7 0,7')),
          // Bracket Right
          Polygon(points: parse('3,2 5,2 5,7 3,7 3,6 4,6 4,3 3,3')),
          // Centered Dot
          fromRect(Rectangle(2, 4, 1, 1)),
        }),
        Polygon(
          points: parse('1,0 7,0 7,9 1,9 1,6 4,6 4,8 6,8 6,1 4,1 4,3 1,3'),
        ),
        PolygonState.assignParents({
          Polygon(points: parse('0,2 1,2 1,0 7,0 7,9 1,9 1,7 0,7')),
          Polygon(
            points: parse('4,1 6,1 6,8 4,8 4,7 5,7 5,2 4,2'),
            positive: false,
          ),
          fromRect(Rectangle(1, 3, 3, 3), positive: false),
          fromRect(Rectangle(2, 4, 1, 1)),
        }),
      );
    });

    test('Encase Parallel Lines + Island', () {
      final island = fromRect(Rectangle(8, 3, 1, 1));
      expectMerge(
        PolygonState.assignParents({
          fromRect(Rectangle(0, 1, 1, 5)),
          fromRect(Rectangle(4, 1, 1, 5)),
          fromRect(Rectangle(2, 1, 1, 5)),
          fromRect(Rectangle(6, 1, 1, 5)),
          island,
        }),
        Polygon(
          points: parse('0,0 12,0 12,7 0,7 0,5 10,5 10,2 0,2'),
        ),
        PolygonState.assignParents({
          fromRect(Rectangle(0, 0, 12, 7)),
          fromRect(Rectangle(1, 2, 1, 3), positive: false),
          fromRect(Rectangle(3, 2, 1, 3), positive: false),
          fromRect(Rectangle(5, 2, 1, 3), positive: false),
          fromRect(Rectangle(7, 2, 3, 3), positive: false),
          island,
        }),
      );
    });

    test('Make Advanced Bridge', () {
      final square = fromRect(Rectangle(0, 0, 9, 9));
      expectMerge(
        PolygonState.assignParents({
          square,
          fromRect(Rectangle(1, 1, 7, 7), positive: false),
          Polygon(
            points: parse('2,2 4,2 4,3 3,3 3,6 6,6 6,3 5,3 5,2 7,2 7,7 2,7'),
          ),
        }),
        fromRect(Rectangle(3, 0, 3, 3)),
        PolygonState.assignParents({
          square,
          Polygon(
            points: parse('1,1 3,1 3,2 2,2 2,7 7,7 7,2 6,2 6,1 8,1 8,8 1,8'),
            positive: false,
          ),
          fromRect(Rectangle(3, 3, 3, 3), positive: false),
        }),
      );
    });

    test('Fracture + Make Advanced Bridge', () {
      final square = fromRect(Rectangle(0, 0, 9, 9));
      expectMerge(
        PolygonState.assignParents({
          square,
          fromRect(Rectangle(1, 1, 7, 7), positive: false),
          Polygon(
            points: parse('2,2 4,2 4,3 3,3 3,6 6,6 6,3 5,3 5,2 7,2 7,7 2,7'),
          ),
        }),
        fromRect(Rectangle(4, 0, 1, 9)),
        PolygonState.assignParents({
          square,
          // Bracket Left
          Polygon(
            points: parse('1,1 4,1 4,2 2,2 2,7 4,7 4,8 1,8'),
            positive: false,
          ),
          // Bracket Right
          Polygon(
            points: parse('5,1 8,1 8,8 5,8 5,7 7,7 7,2 5,2'),
            positive: false,
          ),
          fromRect(Rectangle(3, 3, 1, 3), positive: false),
          fromRect(Rectangle(5, 3, 1, 3), positive: false),
        }),
      );
    });
  });

  group('Rasterization', () {
    final grid = Grid.square(1);

    test('Rectangle', () {
      final rect = fromRect(Rectangle(2, 1, 3, 4));
      expectRaster(rect, grid, [rect]);
    });

    test('Single Bitmap Field', () {
      final rect = fromRect(Rectangle(0, 0, 1, 1));
      expectRaster(rect, grid, [rect]);
    });

    test('Multiple Results', () {
      final polygon = Polygon(points: parse('0,4 6,9 4,6 6,0'));
      expectRaster(polygon, grid, [
        fromRect(Rectangle(5, 0, 1, 1)),
        Polygon(
            points: parse(
                '4,2 4,1 5,1 5,4 4,4 4,7 3,7 3,6 2,6 2,5 1,5 1,3 2,3 2,2')),
        fromRect(Rectangle(4, 7, 1, 1)),
        fromRect(Rectangle(5, 8, 1, 1)),
      ]);
    });

    test('Multiple Results (Variation)', () {
      final polygon = Polygon(points: parse('0,4 6,9 4,3 6,0'));
      expectRaster(polygon, grid, [
        fromRect(Rectangle(5, 0, 1, 1)),
        fromRect(Rectangle(4, 1, 1, 1)),
        Polygon(
            points: parse(
                '2,3 2,2 4,2 4,5 5,5 5,8 4,8 4,7 3,7 3,6 2,6 2,5 1,5 1,3')),
        fromRect(Rectangle(5, 8, 1, 1)),
      ]);
    });
  });
}
