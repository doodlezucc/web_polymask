import 'dart:math';

import '../math/polygon.dart';
import 'lasso.dart';

abstract class PolygonBrush {
  const PolygonBrush();

  static const lasso = PolygonLassoBrush();

  BrushPath createNewPath();
}

abstract class BrushPath {
  Polygon polygon;

  bool handleMouseMove(Point<int> p);
  bool isValid([Point<int> extra]) => true;
}
