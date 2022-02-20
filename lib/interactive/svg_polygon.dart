import 'dart:html';
import 'dart:svg' as svg;

import 'package:web_polymask/math/polygon.dart';
import 'package:web_polymask/math/polymath.dart';

class SvgPolygon extends Polygon {
  static const minDistanceSquared = 10;

  final svg.PolygonElement el;
  int _safelySimple = 0;

  SvgPolygon(
    Element parent, {
    List<Point<int>> points,
    bool positive = true,
  })  : el = svg.PolygonElement(),
        super(points: points, positive: positive) {
    refreshSvg();

    parent.append(el);
  }

  SvgPolygon.copy(Element parent, Polygon other)
      : this(parent, points: other.points, positive: other.positive);

  @override
  void addPoint(Point<int> point) {
    if (points.isEmpty ||
        point.squaredDistanceTo(points.last) > minDistanceSquared) {
      super.addPoint(point);
      refreshSvg();
    }
  }

  void dispose() {
    el.remove();
  }

  /// Returns true if this polygon (+ `extraPoint`) doesn't intersect itself.
  bool isSimple([Point<int> extraPoint]) {
    if (points.length < 3) return true;

    var nvert = points.length;

    if (extraPoint != null) nvert++;

    Point<int> elem(int i) => (extraPoint != null && i % nvert == nvert - 1)
        ? extraPoint
        : points[i % nvert];

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

  String _toSvgData(Point<int> extraPoint) {
    if (points.isEmpty) return '';

    String writePoint(Point<int> p) => '${p.x},${p.y}';

    var s = writePoint(points.first);
    for (var p in points.skip(1)) {
      s += ' ' + writePoint(p);
    }

    if (extraPoint != null) {
      s += ' ' + writePoint(extraPoint);
    }

    return s;
  }

  void refreshSvg([Point<int> extraPoint]) =>
      el.setAttribute('points', _toSvgData(extraPoint));
}
