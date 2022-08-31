import 'dart:math';

import '../math/polygon.dart';
import '../math/polymath.dart';
import 'brush.dart';

const int resolution = 15;
final List<Point<double>> unitCircle = computeUnitCircle(resolution);

class StrokeBrush extends PolygonBrush {
  const StrokeBrush();

  @override
  BrushPath createNewPath(Point<int> start) => StrokePath([start]);
}

class StrokePath extends BrushPath {
  double radius = 50;
  Polygon polygon;
  bool breakNow = false;

  final List<Point<int>> path;

  StrokePath(this.path) : super([]) {
    _update();
  }

  @override
  bool handleMouseMove(Point<int> p) {
    if (path.isEmpty || p.squaredDistanceTo(path.last) > 20) {
      path.add(p);
      _update();
      return true;
    }
    return false;
  }

  void _update() {
    if (breakNow) return;
    points.clear();

    var circ = Polygon(points: makeCircle(path.last, radius));

    if (polygon == null) {
      polygon = circ;
      points.addAll(polygon.points);
    } else {
      try {
        // Doesn't work if union returns two separate polygons
        var nPoly = union(polygon, circ).firstWhere((poly) => poly.positive);
        polygon = nPoly..mergeByDistance(4);
      } finally {
        points.addAll(polygon.points);
      }
    }
  }
}

List<Point<int>> makeCircle(Point<int> center, double radius) {
  return unitCircle.map((p) {
    return Point(
      center.x + (p.x * radius).round(),
      center.y + (p.y * radius).round(),
    );
  }).toList(growable: false);
}

List<Point<double>> computeUnitCircle(int resolution) {
  return List.generate(resolution, (i) {
    var t = 2 * pi * i / resolution;
    return Point(sin(t), cos(t));
  });
}
