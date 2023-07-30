import 'dart:math';

import 'package:grid_space/grid_space.dart';

import 'polygon.dart';
import 'polymath.dart';

List<Polygon> rasterize(Polygon polygon, Grid g, [int cropMargin = 0]) {
  if (g is! TiledGrid) return [polygon];

  final TiledGrid grid = g;
  final srcZero = grid.zero;

  // Ensure the cropping margin to ALWAYS be undone when returning
  try {
    grid.zero = srcZero.cast<num>() + Point(cropMargin, cropMargin);

    final bbox = polygon.boundingBox;

    final tileShapeWorld = grid.tileShape.points
        .map((p) => (p.cast<double>() * grid.tileWidth))
        .toList();

    Polygon tileToPolygon(Point<double> tileCenter) {
      return Polygon(
        positive: polygon.positive,
        points: tileShapeWorld.map((p) => (tileCenter + p).round()).toList(),
      );
    }

    // Return nearest tile if polygon is smaller than tile size
    if (bbox.width < grid.tileWidth && bbox.height < grid.tileHeight) {
      var pos = (bbox.topLeft + bbox.bottomRight).cast<double>() * 0.5;
      final tileCenter = grid.worldSnapCentered(pos, 1).cast<double>();
      return [tileToPolygon(tileCenter)];
    }

    // Efficient rasterization for square grids
    if (g is SquareGrid) return _rasterizeSquare(polygon, g, cropMargin);

    // General "rasterization" for all tiled grids

    final boundsMin = g.worldToGridSpace(bbox.topLeft).floor() - Point(1, 1);
    final boundsMax =
        g.worldToGridSpace(bbox.bottomRight).floor() + Point(1, 1);

    final result = <Polygon>[];

    for (var x = boundsMin.x; x <= boundsMax.x; x++) {
      for (var y = boundsMin.y; y <= boundsMax.y; y++) {
        final tileCenter = grid.tileCenterInWorld(Point(x, y));
        if (pointInsidePolygon(tileCenter, polygon)) {
          result.add(tileToPolygon(tileCenter));
        }
      }
    }

    return result;
  } finally {
    grid.zero = srcZero; // Undo cropping margin
  }
}

/// A more efficient (?) approach at rasterizing on square grids.
/// Instead of returning a polygon for each contained square cell,
List<Polygon> _rasterizeSquare(Polygon polygon, SquareGrid grid,
    [int cropMargin = 0]) {
  final bbox = polygon.boundingBox;

  final bitmap = <List<bool>>[];
  final points = polygon.points;
  final nvert = points.length;
  final gridBbox = Rectangle.fromPoints(
    grid.worldToGridSpace(bbox.topLeft),
    grid.worldToGridSpace(bbox.bottomRight),
  );
  final gridBounds = Rectangle.fromPoints(
    gridBbox.topLeft.floor(),
    gridBbox.bottomRight.floor() + Point(1, 1),
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

  final result = _squareGridPolyFromBitmap(
      gridBounds.topLeft, bitmap, grid, polygon.positive);
  return result;
}

const orientationRight = 0;
const orientationBottom = 1;
const orientationLeft = 2;
const orientationTop = 3;

List<Polygon> _squareGridPolyFromBitmap(
  Point<int> mapZero,
  List<List<bool>> solid,
  TiledGrid grid,
  bool positive, [
  Point<int>? offset,
  Set<Point<int>>? visited,
]) {
  visited ??= {};

  late Point<int> initial;
  try {
    initial = _findFirstSolid2d(solid, offset, visited);
  } catch (err) {
    return [];
  }

  Point<int> scale(Point<int> q) {
    return grid.gridToWorldSpace(mapZero + q).round();
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
      ..._squareGridPolyFromBitmap(
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
    ..._squareGridPolyFromBitmap(
        mapZero, solid, grid, positive, initial + Point(1, 0), visited),
  ];
}

Point<int> _findFirstSolid2d(
  List<List<bool>> solid, [
  Point<int>? start,
  Set<Point<int>>? visited,
]) {
  bool inside = start != null;
  int rowStart = start?.x ?? 0;
  for (var y = start?.y ?? 0; y < solid.length; y++) {
    for (var x = rowStart; x < solid[y].length; x++) {
      if (!inside) {
        if (solid[y][x]) {
          final point = Point(x, y);
          if (visited != null && !visited.contains(point)) {
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

  throw 'Unable to find any solid cell in grid';
}
