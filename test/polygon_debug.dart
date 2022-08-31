import 'dart:math';

import 'package:web_polymask/math/polygon.dart';
import 'package:web_polymask/math/polymath.dart';

void main() {
  final a =
      parse('228,289 224,293 174,243 224,193 240,209 244,205 294,255 244,305');
  final b = parse('158,227 208,177 258,227 208,277');

  final out = union(Polygon(points: a), Polygon(points: b));
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
