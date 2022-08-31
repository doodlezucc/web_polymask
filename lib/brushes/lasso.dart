import 'dart:math';

import 'package:web_polymask/brushes/brush.dart';
import 'package:web_polymask/math/polygon.dart';

import '../math/polymath.dart';

const minDistanceSquared = 10;

class LassoBrush extends PolygonBrush {
  const LassoBrush() : super(employClickEvent: true);

  @override
  BrushPath createNewPath(Point<int> start) => LassoPath([start]);
}

class LassoPath extends BrushPath {
  Polygon polygon;
  int _safelySimple = 0;

  LassoPath(List<Point<int>> points)
      : polygon = Polygon(points: points),
        super(points);

  @override
  bool handleMouseMove(Point<int> p) {
    if (points.isEmpty ||
        p.squaredDistanceTo(points.last) > minDistanceSquared) {
      points.add(p);
      return true;
    }
    return false;
  }

  @override
  bool isValid([Point<int> extraPoint]) => isSimple(extraPoint);

  /// Returns true if this polygon (+ `extraPoint`) doesn't intersect itself.
  bool isSimple([Point<int> extraPoint]) {
    if (polygon.points.length < 3) return true;

    var nvert = polygon.points.length;

    if (extraPoint != null) nvert++;

    Point<int> elem(int i) => (extraPoint != null && i % nvert == nvert - 1)
        ? extraPoint
        : polygon.points[i % nvert];

    for (var i = _safelySimple; i < nvert; i++) {
      var u = elem(i);
      var v = elem(i + 1);

      for (var k = 2; k < nvert - 1; k++) {
        var e = elem(i + k);
        var f = elem(i + k + 1);

        var intersection = segmentIntersect(u, v, e, f);
        if (intersection != null) {
          return false;
        }
      }
    }

    _safelySimple = nvert - 2;
    return true;
  }
}
