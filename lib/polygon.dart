import 'dart:math';

class Polygon {
  final List<Point<int>> points;
  final bool positive;

  bool _boxUpToDate = false;
  Rectangle<int> _boundingBox;
  Rectangle<int> get boundingBox {
    if (!_boxUpToDate) {
      _boundingBox = _getBoundingBox();
      _boxUpToDate = true;
    }

    return _boundingBox;
  }

  Polygon({List<Point<int>> points, this.positive = true})
      : points = points ?? [];

  void addPoint(Point<int> point) {
    points.add(point);
    _boxUpToDate = false;
  }

  Rectangle<int> _getBoundingBox() {
    var p1 = points.first;
    var xMin = p1.x;
    var xMax = p1.x;
    var yMin = p1.y;
    var yMax = p1.y;

    for (var i = 1; i < points.length; i++) {
      var p = points[i];
      if (p.x < xMin) {
        xMin = p.x;
      } else if (p.x > xMax) {
        xMax = p.x;
      }

      if (p.y < yMin) {
        yMin = p.y;
      } else if (p.y > yMax) {
        yMax = p.y;
      }
    }

    return Rectangle<int>(xMin, yMin, xMax - xMin, yMax - yMin);
  }
}
