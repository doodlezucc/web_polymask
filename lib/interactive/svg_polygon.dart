import 'dart:html';
import 'dart:math';
import 'dart:svg' as svg;

import 'package:web_polygons/polygon.dart';
import 'package:web_polygons/polygon_canvas.dart';

class SvgPolygon extends Polygon {
  final PolygonCanvas canvas;
  final svg.PathElement path;
  Point<int> extraPoint;

  SvgPolygon(this.canvas, {List<Point<int>> points, bool positive = true})
      : path = svg.PathElement(),
        super(points: points, positive: positive) {
    refreshSvg();
    canvas.root.append(path);
  }

  @override
  void addPoint(Point<int> point) {
    super.addPoint(point);
    refreshSvg();
  }

  String _toData() {
    if (points.isEmpty) return '';

    String writePoint(Point<int> p) => ' ${p.x} ${p.y}';

    var s = 'M' + writePoint(points.first);
    for (var p in points) {
      s += ' L' + writePoint(p);
    }

    return s;
  }

  void refreshSvg() => path.setAttribute('d', _toData());
}
