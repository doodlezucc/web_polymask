import 'dart:math';

import 'package:web_polymask/brushes/brush.dart';
import 'package:web_polymask/math/polygon.dart';

import '../math/polymath.dart';

const minDistanceSquared = 10;

class LassoBrush extends PolygonBrush {
  const LassoBrush() : super(employClickEvent: true);

  @override
  BrushPath createNewPath(PolyMaker maker) => LassoPath(maker, this);
}

class LassoPath extends BrushPath {
  Polygon polygon;
  int _safelySimple = 0;

  LassoPath(PolyMaker maker, PolygonBrush brush) : super(maker, brush);

  @override
  void handleStart(Point<int> p) {
    polygon = maker.newPoly([p]);
  }

  @override
  void handleMouseMove(Point<int> p) {
    if (p.squaredDistanceTo(polygon.points.last) > minDistanceSquared) {
      polygon.points.add(p);
      maker.updatePreview(polygon.points);
    }
  }

  @override
  void handleEnd(Point<int> p) {
    maker.instantiate();
  }

  @override
  bool isValid() => isSimple();

  /// Returns true if this polygon (+ `extraPoint`) doesn't intersect itself.
  bool isSimple() {
    if (polygon.points.length < 3) return true;

    var nvert = polygon.points.length;

    Point<int> elem(int i) => polygon.points[i % nvert];

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
