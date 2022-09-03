import 'dart:math';

import 'package:web_polymask/math/polygon.dart';
import 'package:web_polymask/math/polymath.dart';

void main() {
  final state = {
    Polygon(
      points: parse(
          '420,236 383,171 469,171 462,184 521,184 478,259 477,258 447,311 404,236'),
    ),
    Polygon(points: parse('465,236 448,207 432,236'), positive: false),
  };

  final a = Polygon(points: parse('484,226 527,151 441,151'));

  final out = mergePolygon(state, a);
  for (var poly in out) {
    debugPoints(poly.points);
  }
}

List<Point<int>> parse(String s) {
  return s.split(' ').map((co) {
    var parts = co.split(',');
    return Point(int.parse(parts[0]), int.parse(parts[1]));
  }).toList();
}

void debugPoints(List<Point<int>> points) {
  print(points.map((e) => '${e.x},${e.y}').join(' '));
}
