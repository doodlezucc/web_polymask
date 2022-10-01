import 'dart:math';

import 'package:grid/grid.dart';

import 'polygon.dart';
import 'polymath.dart';

List<Polygon> rasterize(Polygon polygon, Grid g) {
  if (g is! TiledGrid) return [polygon];
  TiledGrid grid = g;

  final bitmap = <List<bool>>[];
  final points = polygon.points;
  final nvert = points.length;
  final bbox = polygon.boundingBox;

  final gridBbox = Rectangle.fromPoints(
    grid.worldToGridSpace(bbox.topLeft),
    grid.worldToGridSpace(bbox.bottomRight),
  );
  final gridBounds = Rectangle.fromPoints(
    gridBbox.topLeft.cast<int>(),
    gridBbox.bottomRight.cast<int>() + Point(1, 1),
  );
  final worldBoundsTL = grid.gridToWorldSpace(gridBounds.topLeft).round();

  for (var row = 0; row < gridBounds.height; row++) {
    bitmap.add(List.filled(gridBounds.width, false, growable: false));
    final y = worldBoundsTL.y + (row + 0.5) * grid.tileHeight;
    final intersections = <double>[];
    bool above = points.last.y > y;

    for (var i = 0, j = nvert - 1; i < nvert; j = i++) {
      bool iAbove = points[i].y > y;
      if (above != iAbove) {
        final vector = points[i] - points[j];
        final x = (vector.x * (y - points[j].y) / vector.y) + points[j].x;
        final scaled = (x - bbox.left) / grid.tileWidth;
        intersections.add(scaled + gridBbox.left - gridBounds.left);
        above = iAbove;
      }
    }

    intersections.sort();
    bool solid = false;
    int x = 0;
    for (var isect in intersections) {
      while (x + 0.5 < isect) {
        if (solid && x < bitmap[row].length) bitmap[row][x] = true;
        x++;
      }
      solid = !solid;
    }
  }

  return squareGridPolyFromBitmap(
      gridBounds.topLeft, bitmap, grid, polygon.positive);
}

String bitmapToText(List<List<bool>> bitmap) =>
    bitmap.map((row) => row.map((e) => e ? '1' : '0').join('')).join('\n');

const orientationRight = 0;
const orientationBottom = 1;
const orientationLeft = 2;
const orientationTop = 3;

List<Polygon> squareGridPolyFromBitmap(
  Point<int> mapZero,
  List<List<bool>> solid,
  TiledGrid grid,
  bool positive, [
  Point<int> offset,
  Set<Point<int>> visited,
]) {
  visited ??= {};

  Point<int> initial = findFirstSolid2d(solid, offset, visited);
  if (initial == null) return [];

  Point<int> scale(Point<int> q) {
    return grid.gridToWorldSpace(mapZero + q).cast();
  }

  bool isSolid(Point<int> q) {
    if (q.x < 0 || q.y < 0 || q.y >= solid.length) return false;

    final row = solid[q.y];
    if (q.x >= row.length) return false;

    return row[q.x];
  }

  int orientation;
  Point<int> p = initial;
  final points = <Point<int>>[];

  if (isSolid(initial = (p + Point(0, 1)))) {
    orientation = orientationTop;
  } else if (isSolid(initial = (p + Point(1, 0)))) {
    orientation = orientationRight;
  } else {
    return [
      Polygon.fromRect(
        Rectangle.fromPoints(scale(p), scale(p + Point(1, 1))),
        positive: positive,
      ),
      ...squareGridPolyFromBitmap(
          mapZero, solid, grid, positive, p + Point(2, 0), visited),
    ];
  }

  int initialOrientation = orientation;
  p = initial;
  visited.add(p);

  do {
    for (var i = 0; i < 4; i++) {
      int check = (orientation + i + 3) % 4;
      int x =
          check == orientationLeft ? -1 : (check == orientationRight ? 1 : 0);
      int y =
          check == orientationBottom ? -1 : (check == orientationTop ? 1 : 0);
      final q = p + Point(x, y);

      if (isSolid(q)) {
        // Move to next solid block
        orientation = check;
        p = q;
        visited.add(p);
        break;
      } else {
        // Make line
        switch (check) {
          case orientationLeft:
            points.add(scale(p + Point(0, 1)));
            break;
          case orientationTop:
            points.add(scale(p + Point(1, 1)));
            break;
          case orientationRight:
            points.add(scale(p + Point(1, 0)));
            break;
          case orientationBottom:
            points.add(scale(p + Point(0, 0)));
            break;
        }
      }
    }
  } while (!(p == initial && orientation == initialOrientation));

  removeDeadEnds(points);

  return [
    Polygon(points: points, positive: positive),
    ...squareGridPolyFromBitmap(
        mapZero, solid, grid, positive, initial + Point(1, 0), visited),
  ];
}

Point<int> findFirstSolid2d(
  List<List<bool>> solid, [
  Point<int> start,
  Set<Point<int>> visited,
]) {
  bool inside = start != null;
  int rowStart = start?.x ?? 0;
  for (var y = start?.y ?? 0; y < solid.length; y++) {
    for (var x = rowStart; x < solid[y].length; x++) {
      if (!inside) {
        if (solid[y][x]) {
          final point = Point(x, y);
          if (!visited.contains(point)) {
            return point;
          } else {
            inside = true;
          }
        }
      } else if (!solid[y][x]) {
        inside = false;
      }
    }
    rowStart = 0;
  }

  return null;
}
