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

  void refreshSvg([Point<int> extraPoint]) =>
      el.setAttribute('points', polygon.toSvgData(extraPoint));

  SvgPolygon copy() => SvgPolygon(el.parent, polygon.copy());
  SvgPolygon disposeAndCopy() {
    var result = copy();
    dispose();
    return result;
  }
}
