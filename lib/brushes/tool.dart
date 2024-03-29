import 'dart:math';

import '../math/polygon.dart';

abstract class PolygonTool {
  final String id;
  final bool employClickEvent;
  final bool employMouseWheel;

  const PolygonTool(
    this.id, {
    this.employClickEvent = false,
    this.employMouseWheel = false,
  });

  ToolPath createNewPath(PolyMaker maker);
  List<Point<int>> drawCursor(Point<int> p) => [p];
  bool handleMouseWheel(num amount) => false;

  Map<String, dynamic> toJson() => const {};
  void fromJson(Map<String, dynamic> json) {}
}

abstract class ToolPath<T extends PolygonTool> {
  final PolyMaker maker;
  final T tool;

  ToolPath(this.maker, this.tool);

  void handleStart(Point<int> p);
  void handleMouseMove(Point<int> p);
  void handleMouseClick(Point<int> p) {}
  void handleEnd(Point<int> p) {}
  bool isValid([Point<int>? extra]) => true;
}

class PolyMaker {
  final Polygon Function(List<Point<int>> points) newPoly;
  final void Function() instantiate;
  final void Function(Iterable<Point<int>> points) updatePreview;
  bool isClicked = false;
  double movementScale = 1;

  PolyMaker(this.newPoly, this.instantiate, this.updatePreview);
}
