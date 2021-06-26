import 'dart:math';

class Polygon {
  final List<Point<int>> _points;
  final bool positive;

  Iterable<Point<int>> get points => _points;

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
      : _points = points ?? [];

  void addPoint(Point<int> point) {
    _points.add(point);
    _boxUpToDate = false;
  }

  Rectangle<int> _getBoundingBox() {
    var p1 = _points.first;
    var xMin = p1.x;
    var xMax = p1.x;
    var yMin = p1.y;
    var yMax = p1.y;

    for (var i = 1; i < _points.length; i++) {
      var p = _points[i];
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
