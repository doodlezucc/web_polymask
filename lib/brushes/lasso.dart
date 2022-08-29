import 'dart:math';

import 'package:web_polymask/brushes/brush.dart';

import '../math/polymath.dart';

class PolygonLassoBrush extends PolygonBrush {
  const PolygonLassoBrush();

  @override
  BrushPath createNewPath() => LassoBrushPath();
}

class LassoBrushPath extends BrushPath {
  int _safelySimple = 0;

  @override
  bool handleMouseMove(Point<int> p) {
    polygon.addPoint(p);
    return true;
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
