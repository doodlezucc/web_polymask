import 'dart:math';

import '../math/polygon.dart';
import 'lasso.dart';
import 'stroke.dart';

abstract class PolygonBrush {
  final bool employClickEvent;

  const PolygonBrush({this.employClickEvent = false});

  static const lasso = LassoBrush();
  static const stroke = StrokeBrush();

  BrushPath createNewPath(Point<int> start);
}

abstract class BrushPath {
  Polygon Function() createPolygon;
  final List<Point<int>> points;

  BrushPath(this.points);

  bool handleMouseMove(Point<int> p);
  bool isValid([Point<int> extra]) => true;
}
