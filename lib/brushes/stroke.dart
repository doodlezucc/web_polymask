import 'dart:math';

import 'tool.dart';

const shapeCircle = 'circle';
const shapeSquare = 'square';

const resolution = 15;
final unitCircle = computeUnitCircle(resolution);

const _squarePoints = [Point(-1, -1), Point(1, -1), Point(1, 1), Point(-1, 1)];
const _squareAngles = [0.0, pi / 2, pi, -pi / 2];
final unitSquare = AngleShape(_squarePoints, _squareAngles);

class StrokeBrush extends PolygonTool {
  static const toolId = 'stroke';

  AngleShape _shape;
  String _shapeId;
  String get shape => _shapeId;
  set shape(String shapeId) {
    _shapeId = shapeId;
    _shape = shapeFromId(shapeId);
  }

  double radius = 2;
  double get radiusScaled => exp(radius) * 5;

  StrokeBrush() : super(toolId) {
    shape = shapeCircle;
  }

  @override
  ToolPath createNewPath(PolyMaker maker) => StrokePath(maker, this);

  @override
  List<Point<int>> drawCursor(Point<int> p, [List<Point<int>> override]) =>
      override ?? makeAngleShape(_shape, p, radiusScaled).points;

  @override
  bool handleMouseWheel(int amount) {
    final nRadius = radius - 0.2 * amount;
    if (nRadius <= 0) return false;

    radius = nRadius;
    return true;
  }

  static AngleShape shapeFromId(String shapeId) {
    switch (shapeId) {
      case shapeCircle:
        return unitCircle;
      case shapeSquare:
        return unitSquare;
    }
    return null;
  }

  @override
  Map<String, dynamic> toJson() => {
        'shape': shape,
        'radius': radius,
      };

  @override
  void fromJson(Map<String, dynamic> json) {
    shape = json['shape'] ?? shape;
    radius = json['radius'] ?? radius;
  }
}

class StrokePath extends ToolPath<StrokeBrush> {
  Point<int> last;
  AngleShape circle;

  StrokePath(PolyMaker maker, StrokeBrush brush) : super(maker, brush);

  @override
  void handleStart(Point<int> p) {
    circle = makeAngleShape(tool._shape, p, tool.radiusScaled);
    maker.updatePreview(tool.drawCursor(p, circle.points));
    _update(p);
  }

  @override
  void handleMouseMove(Point<int> p) {
    circle = makeAngleShape(tool._shape, p, tool.radiusScaled);
    maker.updatePreview(tool.drawCursor(p, circle.points));
    if (p.squaredDistanceTo(last) > 50) {
      _update(p);
    }
  }

  void _update(Point<int> p) {
    maker.newPoly(dragPolygon(circle, last ?? p, p));
    maker.instantiate();
    last = p;
  }
}

class AngleShape<T extends num> {
  final List<Point<T>> points;
  final List<double> angles;

  int get length => angles.length;

  AngleShape(this.points, this.angles);
}

AngleShape<int> makeAngleShape(
  AngleShape shape,
  Point<int> center,
  double radius,
) {
  return AngleShape(
    shape.points.map((p) {
      return Point(
        center.x + (p.x * radius).round(),
        center.y + (p.y * radius).round(),
      );
    }).toList(),
    shape.angles,
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
