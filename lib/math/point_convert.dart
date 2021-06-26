import 'dart:math';

Point<int> forceIntPoint(Point p) {
  return Point<int>(p.x.toInt(), p.y.toInt());
}

Point<double> forceDoublePoint(Point p) {
  return Point<double>(p.x.toDouble(), p.y.toDouble());
}
