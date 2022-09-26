import 'dart:math';

import 'package:grid/grid.dart';

import 'polygon.dart';
import 'polymath.dart';

Iterable<Polygon> rasterize(Polygon polygon, TiledGrid grid) {
  final bitmap = <List<bool>>[];
  final points = polygon.points;
  final nvert = points.length;
  final bbox = polygon.boundingBox;

  final gridBbox = Rectangle.fromPoints(
    grid.worldToGridSpace(bbox.topLeft),
    grid.worldToGridSpace(bbox.bottomRight),
  );

  for (var row = 0; row < gridBbox.height; row++) {
    bitmap.add(List.filled(gridBbox.width.ceil(), false, growable: false));
    final y = bbox.top + (row + 0.5) * grid.tileHeight;
    final intersections = <double>[];
    bool above = points.last.y > y;

    for (var i = 0, j = nvert - 1; i < nvert; j = i++) {
      bool iAbove = points[i].y > y;
      if (above != iAbove) {
        final vector = points[i] - points[j];
        final x = (vector.x * (y - points[j].y) / vector.y) + points[j].x;
        intersections.add(x - bbox.left);
        above = iAbove;
      }
    }

    intersections.sort();
    bool solid = false;
    int x = (gridBbox.left % grid.tileWidth).floor();
    for (var isect in intersections) {
      while (x + 0.5 < isect) {
        if (solid && x < bitmap[row].length) bitmap[row][x] = true;
        x++;
      }
      solid = !solid;
    }
  }

  print(bitmap);
  return squareGridPolyFromBitmap(gridBbox.topLeft.cast(), bitmap, grid);
}

const orientationRight = 0;
const orientationBottom = 1;
const orientationLeft = 2;
const orientationTop = 3;

Iterable<Polygon> squareGridPolyFromBitmap(
  Point<int> mapZero,
  List<List<bool>> solid,
  TiledGrid grid,
) {
  Point<int> initial = findFirstSolid2d(solid);
  if (initial == null) return null;

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

  if (isSolid(initial = (p + Point(-1, 0)))) {
    orientation = orientationLeft;
  } else if (isSolid(initial = (p + Point(0, 1)))) {
    orientation = orientationTop;
  } else if (isSolid(initial = (p + Point(1, 0)))) {
    orientation = orientationRight;
  } else {
    return [
      Polygon.fromRect(Rectangle.fromPoints(
        scale(p),
        scale(p + Point(1, 1)),
      ))
    ];
  }

  int initialOrientation = orientation;
  p = initial;

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

  return [Polygon(points: points)];
}

Point<int> findFirstSolid2d(List<List<bool>> solid) {
  for (var y = 0; y < solid.length; y++) {
    for (var x = 0; x < solid[y].length; x++) {
      if (solid[y][x]) return Point(x, y);
    }
  }

  return null;
}
