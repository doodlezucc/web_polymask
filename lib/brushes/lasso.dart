import 'dart:math';

import 'package:web_polymask/brushes/tool.dart';
import 'package:web_polymask/math/polygon.dart';

import '../math/polymath.dart';

class LassoBrush extends PolygonTool {
  static const toolId = 'lasso';

  const LassoBrush() : super(toolId, employClickEvent: true);

  @override
  ToolPath createNewPath(PolyMaker maker) => LassoPath(maker, this);
}

class LassoPath extends ToolPath {
  int minDistance = 4;
  Polygon polygon;
  int _safelySimple = 0;

  LassoPath(PolyMaker maker, PolygonTool brush) : super(maker, brush) {
    final unsquared = (minDistance * maker.movementScale);
    minDistance = (unsquared * unsquared).round();
  }

  @override
  void handleStart(Point<int> p) {
    polygon = maker.newPoly([p]);
  }

  @override
  void handleMouseMove(Point<int> p) {
    if (maker.isClicked) return maker.updatePreview([...polygon.points, p]);

    _addSinglePoint(p, updatePreview: true);
  }

  @override
  void handleMouseClick(Point<int> p) {
    _addSinglePoint(p);
  }

  @override
  void handleEnd(Point<int> p) {
    maker.instantiate();
  }

  void _addSinglePoint(Point<int> p, {bool updatePreview = false}) {
    if (p.squaredDistanceTo(polygon.points.last) > minDistance) {
      polygon.points.add(p);
      if (updatePreview) {
        maker.updatePreview(polygon.points);
      }
    }
  }

  @override
  bool isValid([Point<int> extraPoint]) =>
      isSimple(maker.isClicked ? extraPoint : null);

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
