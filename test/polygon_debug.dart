import 'dart:math';

import 'package:web_polymask/math/polygon.dart';
import 'package:web_polymask/math/polymath.dart';

void main() {
  final a = parse(
      '360,283 354,288 334,292 314,288 297,275 286,257 284,237 284,233 291,213 305,198 324,189 344,189 358,195 371,189 391,189 410,198 424,213 431,233 429,253 418,271 401,284 381,288 361,284');
  final b = parse(
      '361,284 344,271 333,253 331,233 338,213 352,198 371,189 391,189 410,198 424,213 431,233 429,253 418,271 401,284 381,288');

  final out = union(Polygon(points: b), Polygon(points: a));
  debugPoints(out.first.points);
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
