import 'dart:math';

import 'brush.dart';

const resolution = 15;
final unitCircle = computeUnitCircle(resolution);

class StrokeBrush extends PolygonBrush {
  double radius = 80;

  @override
  BrushPath createNewPath(PolyMaker maker) => StrokePath(maker, this);

  @override
  List<Point<int>> drawCursor(Point<int> p, [List<Point<int>> override]) =>
      override ?? makeCircleAngled(p, radius).points;
}

class StrokePath extends BrushPath<StrokeBrush> {
  Point<int> last;
  AngleShape circle;

  StrokePath(PolyMaker maker, StrokeBrush brush) : super(maker, brush);

  @override
  void handleStart(Point<int> p) {
    circle = makeCircleAngled(p, brush.radius);
    maker.updatePreview(brush.drawCursor(p, circle.points));
    _update(p);
  }

  @override
  void handleMouseMove(Point<int> p) {
    circle = makeCircleAngled(p, brush.radius);
    maker.updatePreview(brush.drawCursor(p, circle.points));
    if (p.squaredDistanceTo(last) > 50) {
      _update(p);
    }
  }

  void _update(Point<int> p) {
    maker.newPoly(dragPolygon(circle, last ?? p, p));
    maker.instantiate();
    last = p;
  }

  @override
  void handleEnd(Point<int> p) {}
}

class AngleShape<T extends num> {
  final List<Point<T>> points;
  final List<double> angles;

  int get length => angles.length;

  AngleShape(this.points, this.angles);
}

AngleShape<int> makeCircleAngled(Point<int> center, double radius) {
  return AngleShape(
    unitCircle.points.map((p) {
      return Point(
        center.x + (p.x * radius).round(),
        center.y + (p.y * radius).round(),
      );
    }).toList(),
    unitCircle.angles,
  );
}

AngleShape<double> computeUnitCircle(int resolution) {
  final angleOffset = pi / resolution;

  final points = <Point<double>>[];
  final angles = <double>[];

  for (var i = 0; i < resolution; i++) {
    final t = 2 * pi * i / resolution;
    points.add(Point(sin(t), -cos(t)));
    angles.add((pi + angleOffset + t) % (2 * pi) - pi);
  }

  return AngleShape(points, angles);
}

const tau = 2 * pi;

bool isAngleBetween(double angle, double a, double b) {
  if (a < b) {
    return a <= angle && angle <= b;
  }
  return a <= angle || angle <= b;
}

List<Point<int>> dragPolygon(
  AngleShape<int> shapeAtB,
  Point<int> centerA,
  Point<int> centerB,
) {
  final offset = centerA - centerB;
  if (offset == const Point(0, 0)) return shapeAtB.points;

  final angle = atan2(offset.y, offset.x);
  final invAngle = (angle + tau) % tau - pi;

  List<Point<int>> out = [];

  final npoint = shapeAtB.length;
  final firstAngle = shapeAtB.angles.first;
  final firstPoint = shapeAtB.points.first;
  final firstAtA = isAngleBetween(firstAngle, angle, invAngle);

  if (firstAtA) {
    out.add(firstPoint + offset);
  } else {
    out.add(firstPoint);
  }

  bool atA = firstAtA;
  for (var i = 1; i < npoint; i++) {
    final p = shapeAtB.points[i];
    final a = shapeAtB.angles[i];
    final newAtA = isAngleBetween(a, angle, invAngle);
    if (newAtA) {
      if (!atA) {
        out.add(p);
        out.add(p + offset);
      }
    } else {
      if (atA) out.add(p + offset);
      out.add(p);
    }
    atA = newAtA;
  }

  if (atA != firstAtA) {
    if (atA) {
      out.add(firstPoint + offset);
    } else {
      out.add(firstPoint);
    }
  }
  return out;
}
