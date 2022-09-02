import 'dart:math';
import 'package:web_polymask/math/polymath.dart';

class Polygon {
  final List<Point<int>> points;
  final bool positive;

  bool _boxUpToDate = false;
  Rectangle<int> _boundingBox;
  Rectangle<int> get boundingBox {
    if (!_boxUpToDate) {
      _boundingBox = pointsToBoundingBox(points);
      _boxUpToDate = true;
    }

    return _boundingBox;
  }

  Polygon({List<Point<int>> points, this.positive = true})
      : points = points ?? [];

  void addPoint(Point<int> point) {
    points.add(point);
    invalidateBoundingBox();
  }

  void invalidateBoundingBox() {
    _boxUpToDate = false;
  }

  /// Merges consecutive points which are at most `distance` units apart.
  void mergeByDistance(int distance) {
    if (points.isEmpty) return;

    final distSquared = distance * distance;
    var prev = points.last;
    for (var i = 0; i < points.length; i++) {
      var p = points[i];
      var d = p.squaredDistanceTo(prev);
      if (d <= distSquared) {
        points.removeAt(i);
        invalidateBoundingBox();
      } else {
        prev = p;
      }
    }
  }

  /// Performance expensive operation. Only for debugging purposes.
  @deprecated
  bool isSimple([Point<int> extraPoint]) {
    if (points.length < 3) return true;

    var nvert = points.length;

    if (extraPoint != null) nvert++;

    Point<int> elem(int i) => (extraPoint != null && i % nvert == nvert - 1)
        ? extraPoint
        : points[i % nvert];

    for (var i = 0; i < nvert; i++) {
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

    return true;
  }
}
