import 'dart:math';

import 'lasso.dart';
import 'stroke.dart';

abstract class PolygonBrush {
  final bool employClickEvent;

  const PolygonBrush({this.employClickEvent = false});

  static const lasso = LassoBrush();
  static const stroke = StrokeBrush();

  BrushPath startPath(Point<int> start) {
    return createNewPath(start).._brush = this;
  }

  BrushPath createNewPath(Point<int> start);
}

abstract class BrushPath<B extends PolygonBrush> {
  B _brush;
  B get brush => _brush;
  final List<Point<int>> points;

  BrushPath(this.points);

  bool handleMouseMove(Point<int> p);
  bool isValid([Point<int> extra]) => true;
}
