import 'dart:html';
import 'dart:svg' as svg;

import 'package:web_polymask/math/polygon.dart';

class SvgPolygon {
  final Polygon polygon;
  final svg.PolygonElement el;

  SvgPolygon(Element parent, this.polygon) : el = svg.PolygonElement() {
    refreshSvg();
    parent.append(el);
  }

  SvgPolygon.from(
    Element parent, {
    List<Point<int>> points,
    bool positive = true,
  }) : this(parent, Polygon(points: points, positive: positive));

  void dispose() {
    el.remove();
  }

  String _toSvgData(Point<int> extraPoint) {
    if (polygon.points.isEmpty) return '';

    String writePoint(Point<int> p) => '${p.x},${p.y}';

    var s = writePoint(polygon.points.first);
    for (var p in polygon.points.skip(1)) {
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
