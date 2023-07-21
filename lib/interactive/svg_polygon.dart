import 'dart:html';
import 'dart:svg' as svg;

import 'package:web_polymask/math/polygon.dart';

class SvgPolygon {
  final Polygon polygon;
  final svg.PolygonElement _el;

  String get currentSvgData => _el.getAttribute('points') ?? '';

  SvgPolygon(Element parent, this.polygon) : _el = svg.PolygonElement() {
    refreshSvg();
    setParent(parent);
  }

  SvgPolygon.from(
    Element parent, {
    List<Point<int>>? points,
    bool positive = true,
  }) : this(parent, Polygon(points: points, positive: positive));

  void setParent(Element parent) {
    parent.append(_el);
  }

  void dispose() {
    _el.remove();
  }

  void refreshSvg([Point<int>? extraPoint]) =>
      _el.setAttribute('points', polygon.toSvgData(extraPoint));

  SvgPolygon copy() => SvgPolygon(_el.parent!, polygon.copy());
}
