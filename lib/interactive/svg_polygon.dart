import 'dart:html';
import 'dart:math';
import 'dart:svg' as svg;

import 'package:web_polymask/math/polygon.dart';
import 'package:web_polymask/polygon_canvas.dart';

class SvgPolygon extends Polygon {
  static const minDistanceSquared = 10;

  final PolygonCanvas canvas;
  final svg.PolygonElement el;

  SvgPolygon(
    this.canvas, {
    List<Point<int>> points,
    bool positive = true,
  })  : el = svg.PolygonElement(),
        super(points: points, positive: positive) {
    refreshSvg();

    var parent = positive ? canvas.polypos : canvas.polyneg;
    parent.append(el);
  }

  SvgPolygon.copy(PolygonCanvas canvas, Polygon other)
      : this(canvas, points: other.points, positive: other.positive);

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

  String _toData(Point<int> extraPoint) {
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
      el.setAttribute('points', _toData(extraPoint));
}
