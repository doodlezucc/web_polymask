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
}
