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
Point<double> segmentIntersect(Point a, Point b, Point u, Point v) {
  if (!segmentRoughIntersect(a, b, u, v)) return null;

  var s1 = forceDoublePoint(b - a);
  var s2 = forceDoublePoint(v - u);

  var div = -s2.x * s1.y + s1.x * s2.y;
  if (div == 0) return null;

  var s = (-s1.y * (a.x - u.x) + s1.x * (a.y - u.y)) / div;

  if (s >= 0 && s <= 1) {
    var t = (s2.x * (a.y - u.y) - s2.y * (a.x - u.x)) / div;

    if (t >= 0 && t <= 1) {
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

  var nvert = polygon.points.length;
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
bool pointInsidePolygon(Point p, Polygon polygon) {
  if (!polygon.boundingBox.containsPoint(p)) return false;

  var inside = false;
  var nvert = polygon.points.length;

  var poly = polygon.points;

  for (var i = 0, j = nvert - 1; i < nvert; j = i++) {
    var a = poly[i];
    var b = poly[j];

    if (((a.y > p.y) != (b.y > p.y)) &&
        (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x)) {
      inside = !inside;
    }
  }

  return inside;
}

/// Calculates the union of `a` and `b`.
Iterable<Polygon> union(Polygon a, Polygon b) {
  if (!a.boundingBox.intersects(b.boundingBox)) return [a, b];

  forceClockwise(a);
  forceClockwise(b);

  var p1 = a.points.last;
  var inside = pointInsidePolygon(p1, b);
  var firstIsectExits = inside;
  var overlaps = 0;

  // var points = <Point<int>>[];
  var intersects = <Intersection>[];

  var nvert = a.points.length;
  for (var i1 = 0, j1 = nvert - 1; i1 < nvert; j1 = i1++) {
    var u = a.points.elementAt(j1);
    var v = a.points.elementAt(i1);

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
          nIsects.add(Intersection(j1, j2, intersection));

          inside = !inside;

          if (!inside) {
            overlaps++;
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

  if (overlaps == 0) {
    if (inside) return [b]; // B contains A

    if (pointInsidePolygon(b.points.first, a)) return [a]; // A contains B

    return [a, b];
  }

  // Using a "switch approach": Start at the first intersection, trace B
  // until meeting another one. Switch to A and trace its points until meeting
  // the next intersection. If this next intersection is not what we started
  // from, continue switching. If it is, a path is finished. Repeat until there
  // are no unvisited intersections left.

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
  var start = firstIsectExits ? 1 : 0;
  for (var i = start; i < intersects.length; i += 2) {
    outgoings.add(intersects[i]);
  }

  var results = <List<Point<int>>>[];

  while (intersects.isNotEmpty) {
    var initial = outgoings[0];
    var visited = {initial};
    var points = <Point<int>>[];

    var aEnd = initial;

    var aSrc = intersects.indexOf(aEnd);

    while (true) {
      // Trace B
      var bIndex = bSortedIsects.indexOf(aEnd);
      var bStart = aEnd;
      var bEnd = bSortedIsects[(bIndex + 1) % intersects.length];

      points.add(forceIntPoint(bStart.intersect));

      var steps = bEnd.bSegment - bStart.bSegment;
      if (steps == 0 && bIndex + 1 == intersects.length) {
        steps = b.points.length;
      } else if (steps < 0) steps += b.points.length;

      for (var i = 0; i < steps; i++) {
        points.add(b.points[(bStart.bSegment + i + 1) % b.points.length]);
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
        if (diff != -1) {
          steps = a.points.length;
        }
      } else if (steps < 0) steps += a.points.length;

      for (var i = 0; i < steps; i++) {
        points.add(a.points[(aStart.aSegment + i + 1) % a.points.length]);
      }

      if (aEnd != initial) {
        visited.add(aEnd);
      } else {
        results.add(points);
        break;
      }
    }

    intersects.removeWhere((i) => visited.contains(i));
    bSortedIsects.removeWhere((i) => visited.contains(i));
    outgoings.removeWhere((i) => visited.contains(i));
  }

  // Figure out polarity, there can only be one positive polygon.
  var bigBox = pointsToBoundingBox(results.first);
  var firstIsPositive = true;

  var out = List<Polygon>.filled(results.length, null);

  for (var i = 1; i < results.length; i++) {
    var poly = results[i];
    var box = pointsToBoundingBox(poly);

    var isPositive = box.containsRectangle(bigBox);

    if (isPositive) {
      firstIsPositive = false;
      bigBox = box;
    }

    out[i] = Polygon(points: poly, positive: isPositive);
  }

  out[0] = Polygon(points: results.first, positive: firstIsPositive);

  return out;
}

Polygon upscale(Polygon poly, int m) {
  return Polygon(
    points: poly.points.map((p) => p * m).toList(),
    positive: poly.positive,
  );
}

class Intersection {
  final int aSegment;
  final int bSegment;
  final Point<double> intersect;

  Intersection(this.aSegment, this.bSegment, this.intersect);
}
