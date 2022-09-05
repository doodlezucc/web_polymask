import 'dart:math';

import 'package:web_polymask/math/point_convert.dart';
import 'package:web_polymask/math/polygon.dart';

Rectangle<int> pointsToBoundingBox(List<Point<int>> points) {
  var p1 = points.first;
  var xMin = p1.x;
  var xMax = p1.x;
  var yMin = p1.y;
  var yMax = p1.y;

  for (var i = 1; i < points.length; i++) {
    var p = points[i];
    if (p.x < xMin) {
      xMin = p.x;
    } else if (p.x > xMax) {
      xMax = p.x;
    }

    if (p.y < yMin) {
      yMin = p.y;
    } else if (p.y > yMax) {
      yMax = p.y;
    }
  }

  return Rectangle<int>(xMin, yMin, xMax - xMin, yMax - yMin);
}

bool boxOverlap(Polygon a, Polygon b) {
  return a.boundingBox.intersects(b.boundingBox);
}

/// Returns the point at which two line segments `(a -> b)` and `(u -> v)`
/// intersect.
///
/// Returns `null` if the segments don't intersect.
///
/// Based on André LaMothe's algorithm, as
/// presented on [stackoverflow](https://stackoverflow.com/a/1968345).
Point<double> segmentIntersect(Point a, Point b, Point u, Point v,
    {bool includeEnds = true}) {
  if (!segmentRoughIntersect(a, b, u, v)) return null;

  var s1 = forceDoublePoint(b - a);
  var s2 = forceDoublePoint(v - u);

  var div = -s2.x * s1.y + s1.x * s2.y;
  if (div == 0) return null;

  var s = (-s1.y * (a.x - u.x) + s1.x * (a.y - u.y)) / div;

  if (includeEnds ? (s >= 0 && s <= 1) : (s > 0 && s < 1)) {
    var t = (s2.x * (a.y - u.y) - s2.y * (a.x - u.x)) / div;

    if (t > 0 && (includeEnds ? t <= 1 : t < 1)) {
      // Collision detected
      return forceDoublePoint(a) + s1 * t;
    }
  }

  return null; // No collision
}

/// Checks if the bounding boxes of two line segments overlap.
bool segmentRoughIntersect(Point a, Point b, Point u, Point v) {
  var x1 = a.x < b.x;
  var x2 = u.x < v.x;

  if (!((x2 ? u.x : v.x) > (x1 ? b.x : a.x) ||
      (x2 ? v.x : u.x) < (x1 ? a.x : b.x))) {
    var y1 = a.y < b.y;
    var y2 = u.y < v.y;

    return !((y2 ? u.y : v.y) > (y1 ? b.y : a.y) ||
        (y2 ? v.y : u.y) < (y1 ? a.y : b.y));
  }
  return false;
}

/// Calculates the signed area of `polygon`.
///
/// If the result is negative, `polygon.points` is in clockwise
/// order. If it's positive, the list is counterclockwise.
double signedArea(Polygon polygon) {
  var signedArea = 0;
  var poly = polygon.points;

  var nvert = poly.length;
  for (var i = 0, j = nvert - 1; i < nvert; j = i++) {
    var a = poly[i];
    var b = poly[j];
    signedArea += a.x * b.y - b.x * a.y;
  }

  return signedArea / 2;
}

void forceClockwise(Polygon polygon) {
  if (signedArea(polygon) >= 0) {
    polygon.points.setAll(0, polygon.points.reversed.toList());
  }
}

/// Checks if `p` is inside `polygon`.
///
/// Based on
/// https://wrf.ecse.rpi.edu/Research/Short_Notes/pnpoly.html.
bool pointInsidePolygon(Point p, Polygon polygon, {bool allowEdges = true}) {
  if (!polygon.boundingBox.containsPoint(p)) return false;

  var inside = false;
  var nvert = polygon.points.length;

  var poly = polygon.points;

  for (var i = 0, j = nvert - 1; i < nvert; j = i++) {
    var a = poly[i];
    var b = poly[j];

    bool swch;
    if (allowEdges) {
      swch = ((a.y >= p.y) != (b.y >= p.y)) &&
          (p.x <= (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x);
    } else {
      swch = ((a.y > p.y) != (b.y > p.y)) &&
          (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x);
    }

    if (swch) {
      inside = !inside;
    }
  }

  return inside;
}

class Intersection {
  final int aSegment;
  final int bSegment;
  final Point<double> intersect;

  Intersection(this.aSegment, this.bSegment, this.intersect);
}

/// Calculates the union of `a` and `b` (A ∪ B).
Iterable<Polygon> union(Polygon a, Polygon b) {
  return _operation(a, b, true);
}

/// Calculates the intersection of `a` and `b` (A ∩ B).
/// If they intersect, all returned polygons share the pole of `a`.
Iterable<Polygon> intersection(Polygon a, Polygon b) {
  return _operation(a, b, false);
}

const double _noiseA = 4.57763671875e-05;
const double _noiseB = 3.0517578125e-05;

/// Using a "switch approach": Start at the first intersection, trace B
/// until meeting another one. Switch to A and trace its points until traversing
/// back into B. If this next intersection is not what we started
/// from, continue switching. If it is, a path is finished. Repeat until there
/// are no unvisited intersections left.
///
/// When compared to existing polygon clipping algorithms, the
/// [Greiner-Hormann algorithm](https://dl.acm.org/doi/10.1145/274363.274364)
/// seems to be very similar to what I've come up with.
Iterable<Polygon> _operation(Polygon a, Polygon b, bool union) {
  if (!a.boundingBox.intersects(b.boundingBox)) return union ? [a, b] : [];

  forceClockwise(a);
  forceClockwise(b);

  var aPoints =
      a.points.map((e) => Point(e.x + _noiseA, e.y + _noiseB)).toList();

  var p1 = aPoints.last;
  var inside = pointInsidePolygon(p1, b);

  var firstIsectExits = inside;
  var overlaps = 0;

  var intersects = <Intersection>[];

  var nvert = aPoints.length;
  for (var i1 = 0, j1 = nvert - 1; i1 < nvert; j1 = i1++) {
    var u = aPoints.elementAt(j1);
    var v = aPoints.elementAt(i1);

    var rect = Rectangle.fromPoints(u, v);

    // Iterate through segments if (u -> v) is in other polygon's bounding box
    if (b.boundingBox.intersects(rect)) {
      var nIsects = <Intersection>[];

      var nvert = b.points.length;
      for (var i2 = 0, j2 = nvert - 1; i2 < nvert; j2 = i2++) {
        var e = b.points.elementAt(j2);
        var f = b.points.elementAt(i2);

        var intersection = segmentIntersect(u, v, e, f);
        if (intersection != null) {
          // Check if intersection already exists
          if (!nIsects.any((any) => any.intersect == intersection) &&
              !intersects.any((any) => any.intersect == intersection)) {
            nIsects.add(Intersection(j1, j2, intersection));

            inside = !inside;

            if (!inside) {
              overlaps++;
            }
          }
        }
      }

      // Sort new intersections by distance to segment start
      if (nIsects.isNotEmpty) {
        var uAsDouble = forceDoublePoint(u);

        nIsects.sort((isect1, isect2) => isect1.intersect
            .squaredDistanceTo(uAsDouble)
            .compareTo(isect2.intersect.squaredDistanceTo(uAsDouble)));
        intersects.addAll(nIsects);
      }
    }
  }

  // Always handle intersection operation as same pole
  final samePole = !union || a.positive == b.positive;

  // The simple cases
  if (overlaps == 0) {
    if (firstIsectExits) return [union ? b : a]; // B contains A

    if (pointInsidePolygon(b.points.first, a)) {
      // A contains B
      return union ? (samePole ? [a] : [b, a]) : [b];
    }

    return union ? [a, b] : [];
  }

  var bSortedIsects = List<Intersection>.from(intersects)
    ..sort((ia, ib) {
      if (ia.bSegment == ib.bSegment) {
        var segStart = forceDoublePoint(b.points[ia.bSegment]);

        return ia.intersect
            .squaredDistanceTo(segStart)
            .compareTo(ib.intersect.squaredDistanceTo(segStart));
      }
      return ia.bSegment.compareTo(ib.bSegment);
    });

  var outgoings = <Intersection>[];
  var start = (firstIsectExits ^ !union) ? 1 : 0; // Fancy XOR operator
  for (var i = start; i < intersects.length; i += 2) {
    outgoings.add(intersects[i]);
  }

  var results = <List<Point<int>>>[];

  while (outgoings.isNotEmpty) {
    var initial = outgoings[0];
    var visited = {initial};
    var points = <Point<int>>[];

    var aEnd = initial;

    var aSrc = intersects.indexOf(aEnd);

    while (true) {
      // Trace B
      var bIndex = bSortedIsects.indexOf(aEnd);
      var bStart = aEnd;
      var bEnd = bSortedIsects[
          (bIndex + (samePole ? 1 : intersects.length - 1)) %
              intersects.length];

      points.add(forceIntPoint(bStart.intersect));

      var steps = samePole
          ? bEnd.bSegment - bStart.bSegment
          : bStart.bSegment - bEnd.bSegment;

      if (steps == 0 &&
          (samePole ? (bIndex + 1) == intersects.length : bIndex == 0)) {
        steps = b.points.length;
      } else if (steps < 0) steps += b.points.length;

      for (var i = 0; i < steps; i++) {
        points.add(b.points[
            (bStart.bSegment + (samePole ? i + 1 : -i)) % b.points.length]);
      }

      visited.add(bEnd);

      // Trace A
      var aIndex = intersects.indexOf(bEnd);
      var aStart = bEnd;
      aEnd = intersects[(aIndex + 1) % intersects.length];

      points.add(forceIntPoint(aStart.intersect));

      steps = aEnd.aSegment - aStart.aSegment;
      if (steps == 0) {
        var diff = aIndex - aSrc;
        if (union && (diff == intersects.length - 1)) {
          steps = a.points.length;
        }
      } else if (steps < 0) steps += a.points.length;

      for (var i = 0; i < steps; i++) {
        points.add(a.points[(aStart.aSegment + i + 1) % a.points.length]);
      }

      if (aEnd != initial) {
        visited.add(aEnd);
      } else {
        if (!samePole) {
          final split = _splitSelfIntersections(points);
          results.addAll(split);
        } else {
          results.add(points);
        }
        break;
      }
    }

    intersects.removeWhere((i) => visited.contains(i));
    bSortedIsects.removeWhere((i) => visited.contains(i));
    outgoings.removeWhere((i) => visited.contains(i));
  }

  results.removeWhere((poly) => poly.length < 3);

  if (union && samePole) {
    // Figure out pole, there can only be one polygon of A's/B's pole.
    var bigBox = pointsToBoundingBox(results.first);
    var firstIsPositive = a.positive;

    var out = <Polygon>[null];

    for (var i = 1; i < results.length; i++) {
      var poly = results[i];
      var box = pointsToBoundingBox(poly);

      var isPositive = box.containsRectangle(bigBox);

      if (isPositive) {
        firstIsPositive = !a.positive;
        bigBox = box;
      }

      var polished =
          withoutDoubles(Polygon(points: poly, positive: isPositive));
      if (polished != null) out.add(polished);
    }

    out[0] = withoutDoubles(
        Polygon(points: results.first, positive: firstIsPositive));

    return out..removeWhere((p) => p == null);
  } else {
    return results
        .map((ps) => withoutDoubles(Polygon(points: ps, positive: a.positive)))
        .where((p) => p != null);
  }
}

List<List<Point<int>>> _splitSelfIntersections(List<Point<int>> points) {
  if (points.length < 3) return [points];

  final nvert = points.length;
  final result = [<Point<int>>[]];
  final isects = <Point<int>>[];

  Point<int> elem(int i) => points[i % nvert];

  for (var i = 0; i < nvert; i++) {
    var u = points[i];
    var v = elem(i + 1);

    for (var k = 2; k < nvert - 1; k++) {
      var e = elem(i + k);
      var f = elem(i + k + 1);

      var intersection = segmentIntersect(u, v, e, f, includeEnds: false);
      if (intersection != null) {
        isects.add(forceIntPoint(intersection));
        result.last.add(isects.last);

        // Reuse empty point list
        // if (result.last.isNotEmpty)
        result.add([]);
      }
    }

    result.last.add(v);
  }

  if (result.length == 1) return result;

  result.last.addAll(result.removeAt(0));
  return result;
}

/// Removes every point preceded by another point with the same coordinates
/// and forces `polygon`s list of points not to repeat.
Polygon withoutDoubles(Polygon polygon) {
  final points = removeDoubles(polygon.points);
  if (points == null) return null;

  return Polygon(points: points, positive: polygon.positive);
}

/// Returns a copy of `points` where every point preceded by another point with
/// the same coordinates is removed.
List<Point<int>> removeDoubles(List<Point<int>> points) {
  var first = points.first;
  var second = points.elementAt(1);
  var previous = first;
  var nPoints = <Point<int>>[first];

  for (var i = 1; i < points.length; i++) {
    var p = points[i];
    if (p != previous) {
      // Check if polygon repeats
      if (p == first) {
        var next = points[(i + 1) % points.length];
        if (i == points.length - 1 || next == second) {
          // Points starts repeating at i
          break;
        }
      }

      previous = p;
      nPoints.add(p);
    }
  }

  _removeDeadEnds(nPoints);
  if (nPoints.isEmpty) return null;

  return nPoints;
}

/// Removes all parts of `points` that would come across infinitely thin
/// when drawn on a canvas.
///
/// Not very efficient, but it work :)
void _removeDeadEnds(List<Point<int>> points) {
  var len = points.length;

  int _area(List<Point<int>> points, int off) {
    var signedArea = 0;
    for (var i = 0, j = 2; i < 3; j = i++) {
      var a = points[(i + off) % len];
      var b = points[(j + off) % len];
      signedArea += a.x * b.y - b.x * a.y;
    }
    return signedArea;
  }

  var i = 0;
  while (i < len && len >= 3) {
    var area = _area(points, i);

    if (area == 0) {
      // Found a dead end at i + 1
      points.removeAt((i + 1) % len);
      len--;
      i--;

      if (points[i % len] == points[(i + 1) % len]) {
        points.removeAt(i % len);
        len--;
        i--;
      }
    } else {
      i++;
    }
  }

  if (len < 3) points.clear();
}

/// Returns `poly` with all points multiplied by `m`.
Polygon upscale(Polygon poly, int m) {
  return Polygon(
    points: poly.points.map((p) => p * m).toList(),
    positive: poly.positive,
  );
}

/// Merges `polygon` into `state`.
Set<Polygon> mergePolygon(Iterable<Polygon> state, Polygon polygon) {
  var pole = polygon.positive;
  var affected = <Polygon>{};
  var nPolys = <Polygon>[];
  var removeMerge = false;
  var inside = false;

  void equalPole() {
    // Merge all equally polarized polygons
    for (var other in state.where((p) => p.positive == pole)) {
      var united = union(polygon, other);
      if (united.length == 1) {
        var merge = united.first;
        if (merge != other) {
          affected.add(other);

          if (merge != polygon) {
            // There's one big shape now
            polygon = merge;
          }
        } else {
          removeMerge = true;
        }
      } else if (united.length == 2 && united.first == polygon) {
        // No overlapping
      } else {
        // Wow, cool new shape with holes and stuff
        affected.add(other);
        polygon = united.firstWhere((p) => p.positive);
        nPolys.addAll(united.where((p) => !p.positive));
      }
    }
  }

  void diffPole() {
    // Subtract big poly from other poles
    for (var other in state.where((p) => p.positive != pole)) {
      var united = union(other, polygon);
      if (united.length == 1 && united.first.positive == pole) {
        // This opposite pole is now gone
        affected.add(other);
      } else if (united.length == 2 && united.any((p) => p == polygon)) {
        // No overlapping
        if (united.first == polygon) {
          // A contains B
          inside = true;
        }
      } else {
        // Opposite pole gets transformed, maybe split into multiple
        affected.add(other);
        removeMerge = !pole;
        nPolys.addAll(united);
      }
    }
  }

  if (pole) {
    diffPole();
    equalPole();
  } else {
    equalPole();
    diffPole();
  }

  if (!pole && nPolys.isEmpty && !inside) {
    removeMerge = true;
  }

  final out = state.toSet();

  for (var aff in affected) {
    out.remove(aff);
  }
  out.addAll(nPolys);

  if (!removeMerge) {
    out.add(polygon);
  }

  return out;
}
