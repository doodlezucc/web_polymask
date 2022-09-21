import 'dart:math';

import '../math/polygon.dart';
import 'lasso.dart';
import 'stroke.dart';

abstract class PolygonBrush {
  final bool employClickEvent;

  const PolygonBrush({this.employClickEvent = false});

  static final lasso = LassoBrush();
  static final stroke = StrokeBrush();

  BrushPath createNewPath(PolyMaker maker);
  List<Point<int>> drawCursor(Point<int> p) => [];
}

abstract class BrushPath<B extends PolygonBrush> {
  final PolyMaker maker;
  final B brush;

  BrushPath(this.maker, this.brush);

  void handleStart(Point<int> p);
  void handleMouseMove(Point<int> p);
  void handleMouseClick(Point<int> p) {}
  void handleEnd(Point<int> p) {}
  bool isValid([Point<int> extra]) => true;
}

class PolyMaker {
  final Polygon Function(List<Point<int>> points) newPoly;
  final void Function() instantiate;
  final void Function(Iterable<Point<int>> points) updatePreview;
  bool isClicked = false;

  PolyMaker(this.newPoly, this.instantiate, this.updatePreview);
}
