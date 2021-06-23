import 'dart:html';
import 'dart:math';
import 'dart:svg' as svg;

import 'package:web_polygons/polygon.dart';
import 'package:web_polygons/polygon_canvas.dart';

class SvgPolygon extends Polygon {
  static const minDistanceSquared = 10;

  final PolygonCanvas canvas;
  final svg.PathElement path;

  SvgPolygon(this.canvas, {List<Point<int>> points, bool positive = true})
      : path = svg.PathElement(),
        super(points: points, positive: positive) {
    refreshSvg();
    canvas.root.append(path);
  }

  @override
  void addPoint(Point<int> point) {
    if (points.isEmpty ||
        point.squaredDistanceTo(points.last) > minDistanceSquared) {
      super.addPoint(point);
      refreshSvg();
    }
  }

  void dispose() {
    path.remove();
  }

  String _toData(Point<int> extraPoint) {
    if (points.isEmpty) return '';

    String writePoint(Point<int> p) => ' ${p.x} ${p.y}';

    var s = 'M' + writePoint(points.first);
    for (var p in points) {
      s += ' L' + writePoint(p);
    }

    if (extraPoint != null) {
      s += ' L' + writePoint(extraPoint);
    }

    s += ' L' + writePoint(points.first);

    return s;
  }

  void refreshSvg([Point<int> extraPoint]) =>
      path.setAttribute('d', _toData(extraPoint));
}
