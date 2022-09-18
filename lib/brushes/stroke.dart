import 'dart:math';

import '../math/polygon.dart';
import 'brush.dart';

const int resolution = 3;
final List<AngledPoint> unitCircle = computeUnitCircle(resolution);

class StrokeBrush extends PolygonBrush {
  const StrokeBrush();

  @override
  BrushPath createNewPath(Point<int> start) => StrokePath(start);
}

class StrokePath extends BrushPath {
  double radius = 50;
  Polygon polygon;
  Point<int> last;

  StrokePath(Point<int> start) : super([]) {
    _update(start);
  }

  @override
  bool handleMouseMove(Point<int> p) {
    if (last == null || p.squaredDistanceTo(last) > 200) {
      _update(p);
      return true;
    }
    return false;
  }

  void _update(Point<int> p) {
    points.clear();

    final circ = makeCircle(p, radius);
    points.addAll(dragPolygon(circ, last ?? p, p));
    last = p;

    // points.clear();

    // var circ = Polygon(points: makeCircle(path.last, radius));

    // if (polygon == null) {
    //   polygon = circ;
    //   points.addAll(polygon.points);
    // } else {
    //   try {
    //     // Doesn't work if union returns two separate polygons
    //     var nPoly = union(polygon, circ).firstWhere((poly) => poly.positive);
    //     polygon = nPoly..mergeByDistance(4);
    //   } finally {
    //     points.addAll(polygon.points);
    //   }
    // }
  }
}

class AngledPoint<T extends num> {
  final Point<T> point;
  final double angle;

  AngledPoint(this.point, this.angle);

  @override
  String toString() {
    final deg = (angle * 180 / pi).toStringAsFixed(1);
    return '$point at $deg°';
  }
}

List<AngledPoint<int>> makeCircle(Point<int> center, double radius) {
  return unitCircle.map((p) {
    return AngledPoint(
      Point(
        center.x + (p.point.x * radius).round(),
        center.y + (p.point.y * radius).round(),
      ),
      p.angle,
    );
  }).toList(growable: false);
}

List<AngledPoint<double>> computeUnitCircle(int resolution) {
  final angleOffset = pi / resolution;
  return List.generate(resolution, (i) {
    var t = 2 * pi * i / resolution;
    return AngledPoint(
        Point(sin(t), -cos(t)), (pi + angleOffset + t) % (2 * pi) - pi);
  });
}

const tau = 2 * pi;

bool isAngleBetween(double angle, double a, double b) {
  if (a < b) {
    return a <= angle && angle <= b;
  }
  return a <= angle || angle <= b;
}

List<Point<int>> dragPolygon(
  List<AngledPoint<int>> shapeAtB,
  Point<int> centerA,
  Point<int> centerB,
) {
  final offset = centerA - centerB;
  if (offset == const Point(0, 0)) return shapeAtB.map((e) => e.point).toList();

  final angle = atan2(offset.y, offset.x);
  final invAngle = (angle + tau) % tau - pi;

  List<Point<int>> out = [];

  final npoint = shapeAtB.length;
  final first = shapeAtB.first;
  final firstAtA = isAngleBetween(first.angle, angle, invAngle);

  if (firstAtA) {
    out.add(first.point + offset);
  } else {
    out.add(first.point);
  }

  bool atA = firstAtA;
  for (var i = 1; i < npoint; i++) {
    final s = shapeAtB[i];
    final newAtA = isAngleBetween(s.angle, angle, invAngle);
    if (newAtA) {
      if (!atA) out.add(s.point);
      out.add(s.point + offset);
    } else {
      if (atA) out.add(s.point + offset);
      out.add(s.point);
    }
    atA = newAtA;
  }

  if (atA != firstAtA) {
    if (atA) {
      out.add(first.point + offset);
    } else {
      out.add(first.point);
    }
  }
  return out;
}
