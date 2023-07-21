import 'dart:math';

import 'package:grid_space/grid_space.dart';
import 'package:web_polymask/math/point_convert.dart';
import 'package:web_polymask/math/polygon.dart';
import 'package:web_polymask/math/polygon_state.dart';

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
Point<double>? segmentIntersect(Point a, Point b, Point u, Point v,
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

  return pointInsidePolygonPoints(p, polygon.points, allowEdges: allowEdges);
}

/// Checks if `p` is inside `poly`.
bool pointInsidePolygonPoints(Point p, List<Point> poly,
    {bool allowEdges = true}) {
  var inside = false;
  var nvert = poly.length;

  for (var i = 0, j = nvert - 1; i < nvert; j = i++) {
    var a = poly[i];
    var b = poly[j];

    bool swch;
    if (allowEdges) {
      if (a.y == p.y && p.y == b.y) {
        if (p.x == a.x || ((p.x > a.x) != (p.x > b.x))) return true;
        continue;
      }
      if (a.x == p.x && p.x == b.x) {
        if (p.y == a.y || ((p.y > a.y) != (p.y > b.y))) return true;
        continue;
      }

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
OperationResult union(Polygon a, Polygon b) {
  return _operation(a, b, true);
}

/// Calculates the intersection of `a` and `b` (A ∩ B).
/// If they intersect, all returned polygons share the pole of `a`.
OperationResult intersection(Polygon a, Polygon b) {
  return _operation(a, b, false);
}

const double _noiseA = 2.8710980267e-05;

/// Using a "switch approach": Start at the first intersection, trace B
/// until meeting another one. Switch to A and trace its points until traversing
/// back into B. If this next intersection is not what we started
/// from, continue switching. If it is, a path is finished. Repeat until there
/// are no unvisited intersections left.
///
/// When compared to existing polygon clipping algorithms, the
/// [Greiner-Hormann algorithm](https://dl.acm.org/doi/10.1145/274363.274364)
/// seems to be very similar to what I've come up with.
OperationResult _operation(Polygon? a, Polygon? b, bool union) {
  if (a == null && b == null) return OperationResultAbort(const []);
  if (identical(a, b) || b == null) return OperationResultAbort([a!]);
  if (a == null) return OperationResultAbort([b]);

  if (!a.boundingBox.intersects(b.boundingBox)) {
    return OperationResultNoOverlap(union ? [a, b] : []);
  }

  // Always handle intersection operation as same pole
  final samePole = !union || a.positive == b.positive;

  forceClockwise(a);
  forceClockwise(b);

  var bPoints = b.points.map((e) => e.cast<double>()).toList(growable: false);
  var bSortedIsects = <Intersection>[];

  var nvert = bPoints.length;
  _dilate(b.points, bPoints, nvert - 2, samePole);
  _dilate(b.points, bPoints, nvert - 1, samePole);
  for (var i1 = 0, j1 = nvert - 1; i1 < nvert; j1 = i1++) {
    // Dilate next segment
    if (i1 < nvert - 2) _dilate(b.points, bPoints, i1, samePole);

    var v = bPoints[i1];
    var u = bPoints[j1];
    var rect = Rectangle.fromPoints(u, v);

    // Iterate through segments if (u -> v) is in other polygon's bounding box
    if (a.boundingBox.intersects(rect)) {
      var nIsects = <Intersection>[];

      var nvert = a.points.length;
      for (var i2 = 0, j2 = nvert - 1; i2 < nvert; j2 = i2++) {
        var e = a.points[j2];
        var f = a.points[i2];

        var intersection = segmentIntersect(u, v, e, f);
        if (intersection != null) {
          // Check if intersection already exists
          if (!nIsects.any((any) => any.intersect == intersection) &&
              !bSortedIsects.any((any) => any.intersect == intersection)) {
            nIsects.add(Intersection(j2, j1, intersection));
          }
        }
      }

      // Sort new intersections by distance to segment start
      if (nIsects.isNotEmpty) {
        var uAsDouble = forceDoublePoint(u);

        nIsects.sort((isect1, isect2) => isect1.intersect
            .squaredDistanceTo(uAsDouble)
            .compareTo(isect2.intersect.squaredDistanceTo(uAsDouble)));
        bSortedIsects.addAll(nIsects);
      }
    }
  }

  var p1 = bPoints.last;
  var firstIsectExitsA = pointInsidePolygon(p1, a, allowEdges: false);
  var nisect = bSortedIsects.length;
  var overlaps = nisect ~/ 2;

  // The simple cases
  if (overlaps == 0) {
    if (firstIsectExitsA) {
      // A contains B
      if (!union) return OperationResultContain([b], b);

      return OperationResultContain(samePole ? [a] : [b, a], a);
    }

    if (pointInsidePolygonPoints(a.points.first, bPoints)) {
      // B contains A
      final container = union ? b : a;
      return OperationResultContain([container], container);
    }

    return OperationResultNoOverlap(union ? [a, b] : []);
  }

  var aSortedIsects = List<Intersection>.from(bSortedIsects)
    ..sort((ia, ib) {
      if (ia.aSegment == ib.aSegment) {
        var segStart = forceDoublePoint(a.points[ia.aSegment]);

        return ia.intersect
            .squaredDistanceTo(segStart)
            .compareTo(ib.intersect.squaredDistanceTo(segStart));
      }
      return ia.aSegment.compareTo(ib.aSegment);
    });

  var outgoings = <Intersection>[];
  var start = (firstIsectExitsA ^ !union) ? 0 : 1; // Fancy XOR operator
  for (var i = start; i < nisect; i += 2) {
    outgoings.add(bSortedIsects[i]);
  }

  var results = <List<Point<int>>>[];

  while (outgoings.isNotEmpty) {
    var initial = outgoings[0];
    var visited = {initial};
    var points = <Point<int>>[];

    var aEnd = initial;

    var aSrc = aSortedIsects.indexOf(aEnd);

    while (true) {
      // Trace B
      var bIndex = bSortedIsects.indexOf(aEnd);
      var bStart = aEnd;
      var bEnd = bSortedIsects[(bIndex + (samePole ? 1 : nisect - 1)) % nisect];

      points.add(forceIntPoint(bStart.intersect));

      var steps = samePole
          ? bEnd.bSegment - bStart.bSegment
          : bStart.bSegment - bEnd.bSegment;

      if (steps == 0 && (samePole ? (bIndex + 1) == nisect : bIndex == 0)) {
        steps = b.points.length;
      } else if (steps < 0) steps += b.points.length;

      for (var i = 0; i < steps; i++) {
        points.add(b.points[
            (bStart.bSegment + (samePole ? i + 1 : -i)) % b.points.length]);
      }

      visited.add(bEnd);

      // Trace A
      var aIndex = aSortedIsects.indexOf(bEnd);
      var aStart = bEnd;
      aEnd = aSortedIsects[(aIndex + 1) % nisect];

      points.add(forceIntPoint(aStart.intersect));

      steps = aEnd.aSegment - aStart.aSegment;
      if (steps == 0) {
        var diff = aIndex - aSrc;
        if (union && (diff == nisect - 1)) {
          steps = a.points.length;
        }
      } else if (steps < 0) steps += a.points.length;

      for (var i = 0; i < steps; i++) {
        points.add(a.points[(aStart.aSegment + i + 1) % a.points.length]);
      }

      if (aEnd != initial) {
        visited.add(aEnd);
      } else {
        final split = _splitSelfIntersections(points);
        results.addAll(split);
        break;
      }
    }

    aSortedIsects.removeWhere((i) => visited.contains(i));
    bSortedIsects.removeWhere((i) => visited.contains(i));
    nisect = bSortedIsects.length;
    outgoings.removeWhere((i) => visited.contains(i));
  }

  results.removeWhere((poly) => poly.length < 3);

  if (union && samePole) {
    // Figure out pole, there can only be one polygon of A's/B's pole.
    var bigBox = pointsToBoundingBox(results.first);
    var firstIsPositive = a.positive;

    var out = <Polygon?>[null];

    for (var i = 1; i < results.length; i++) {
      var poly = results[i];
      var box = pointsToBoundingBox(poly);

      var isContained = box.containsRectangle(bigBox);

      if (isContained) {
        firstIsPositive = !a.positive;
        bigBox = box;
      }

      var polished = withoutDoubles(
          Polygon(points: poly, positive: a.positive == isContained));
      if (polished != null) out.add(polished);
    }

    out[0] = withoutDoubles(
        Polygon(points: results.first, positive: firstIsPositive));

    return OperationResultTransform(out.withoutNulls);
  } else {
    return OperationResultTransform(results
        .map((ps) => withoutDoubles(Polygon(points: ps, positive: a.positive)))
        .withoutNulls);
  }
}

extension NullIterableExtension<T> on Iterable<T?> {
  Iterable<T> get withoutNulls =>
      this.where((element) => element != null) as Iterable<T>;
}

void _dilate(
    List<Point<int>> src, List<Point<double>> dst, int start, bool samePole) {
  final end = (start + 1) % src.length;
  Point<num> u = src[start];
  Point<num> v = src[end];

  var vector = (v - u).cast<double>();
  var ax = vector.x.abs();
  var ay = vector.y.abs();
  var ratio = 1 / max(ax, ay);
  ratio *= 1.29289 - (ax + ay) * ratio * 0.29289;
  vector = vector * (ratio * _noiseA);

  final left = Point(vector.y, -vector.x);
  dst[start] += left;
  dst[end] += left;
}

abstract class OperationResult {
  final List<Polygon> output;

  OperationResult(Iterable<Polygon> output) : this.output = output.toList();

  String get name;

  @override
  String toString() => '"$name" ${output.toList()}';
}

class OperationResultAbort extends OperationResult {
  OperationResultAbort(Iterable<Polygon> result) : super(result);

  @override
  String get name => 'Aborted';
}

class OperationResultNoOverlap extends OperationResult {
  OperationResultNoOverlap(Iterable<Polygon> result) : super(result);

  @override
  String get name => 'No overlap';
}

class OperationResultContain extends OperationResultNoOverlap {
  final Polygon container;

  OperationResultContain(Iterable<Polygon> result, this.container)
      : super(result);

  @override
  String get name =>
      'No overlap (' +
      (container == output.first ? 'A contains B' : 'B contains A') +
      ')';
}

class OperationResultTransform extends OperationResult {
  OperationResultTransform(Iterable<Polygon> result) : super(result);

  @override
  String get name => 'Transform';
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
Polygon? withoutDoubles(Polygon polygon) {
  final points = removeDoubles(polygon.points);
  if (points == null) return null;

  return Polygon(points: points, positive: polygon.positive);
}

/// Returns a copy of `points` where every point preceded by another point with
/// the same coordinates is removed.
List<Point<int>>? removeDoubles(List<Point<int>> points) {
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

  removeDeadEnds(nPoints);
  if (nPoints.isEmpty) return null;

  return nPoints;
}

/// Removes all parts of `points` that would come across infinitely thin
/// when drawn on a canvas.
///
/// Not very efficient, but it work :)
void removeDeadEnds(List<Point<int>> points) {
  var len = points.length;

  int _area(List<Point<int>> points, int off) {
    var a = points[off % len];
    var b = points[(off + 1) % len];
    var c = points[(off + 2) % len];

    return a.x * (c.y - b.y) + b.x * (a.y - c.y) + c.x * (b.y - a.y);
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

class PolygonMerger {
  late Map<Polygon, Polygon?> _parents;
  void Function(Polygon polygon)? onRemove;
  void Function(Polygon polygon, Polygon? parent)? onAdd;
  void Function(Polygon polygon, Polygon? parent)? onUpdateParent;

  PolygonMerger({this.onAdd, this.onRemove, this.onUpdateParent});

  void _remove(Polygon p) {
    _parents.remove(p);
    if (onRemove != null) onRemove!(p);
  }

  void _removeHPoly(HPolygon hp) {
    for (var child in hp.children) {
      _removeHPoly(child);
    }
    _remove(hp.polygon);
  }

  void _setParent(Polygon p, Polygon? parent) {
    _parents[p] = parent;
    if (onUpdateParent != null) onUpdateParent!(p, parent);
  }

  void _add(Polygon p, Polygon? parent) {
    _parents[p] = parent;
    if (onAdd != null) onAdd!(p, parent);
  }

  List<Polygon> _findChildren(Polygon p) {
    return _parents.entries
        .where((e) => e.value == p)
        .map((e) => e.key)
        .toList();
  }

  void _replacePolygon(
    Polygon a,
    Polygon b,
    List<Polygon> aChildren,
    Iterable<List<Polygon>> parentSame,
  ) {
    final parent = _parents[a];

    _add(b, parent);
    for (var polyList in parentSame) {
      final index = polyList.indexOf(a);
      if (index >= 0) {
        polyList[index] = b;
      }
    }
    for (var child in aChildren) {
      _setParent(child, b);
    }
    _remove(a);
  }

  void _replacePolygonWith(
    Polygon a,
    List<Polygon> aChildren,
    Iterable<Polygon> replacement,
    Map<Polygon, List<Polygon>> parentSame,
    Map<Polygon, List<Polygon>> nParentSame,
  ) {
    if (replacement.length == 1) {
      _replacePolygon(a, replacement.first, aChildren,
          parentSame.values.followedBy(nParentSame.values));
    } else {
      // other has been fractured into independent parts,
      // all resulting polygons must be of diff pole
      final children = aChildren;
      for (var poly in replacement) {
        _add(poly, _parents[a]);
        for (var child in children) {
          if (poly.intersects(child)) {
            nParentSame.update(
              child,
              (value) => value..add(poly),
              ifAbsent: () => [poly],
            );
          } else if (poly.contains(child)) {
            // Child is fully contained within a fractured part of this
            // and therefore doesn't have to be checked
            // (could be removed from nextLayer)
            _setParent(child, poly);
          }
        }
      }
      _remove(a);
    }
  }

  void _makeBridge(
    HPolygon other,
    List<Polygon> parents,
    Map<Polygon, List<Polygon>> parentSame,
    Map<Polygon, List<Polygon>> nParentSame,
  ) {
    for (var ch in other.children) {
      _setParent(ch.polygon, _parents[parents[0]]);
    }
    _remove(other.polygon);

    for (var parent in parents) {
      // subtract the original shape from its (diff) parent
      final subtracted = union(parent, other.polygon);
      _replacePolygonWith(parent, _findChildren(parent), subtracted.output,
          parentSame, nParentSame);
    }
  }

  /// Merges `polygon` into `state`. This method operates _in situ_.
  void mergePolygon(PolygonState state, Polygon polygon) {
    _parents = state.parents;
    Set<HPolygon> layer = state.toHierarchy();

    bool samePole = polygon.positive; // Hierarchy roots must be positive
    Map<Polygon, List<Polygon>> parentSame = {};
    HPolygon? parentDiff;
    Polygon? lastContainer;
    bool makeBridge = false;
    bool isectAny = false;
    Polygon layerPoly;

    while (layer.isNotEmpty) {
      layerPoly = polygon;
      Set<HPolygon> nextLayer = {};
      Set<HPolygon> mergeIntoParent = {};
      final nParentSame = <Polygon, List<Polygon>>{};
      Polygon? parent;
      Set<Polygon> nHoles = {};

      for (var other in layer) {
        parent ??= _parents[other.polygon];
        final result = union(other.polygon, layerPoly);
        if (result is OperationResultAbort) continue;

        if (result is OperationResultContain) {
          final merge = result.container;
          if (identical(merge, polygon) ||
              (identical(merge, layerPoly) &&
                  polygon.contains(other.polygon))) {
            // polygon contains other: remove children, replace other with poly
            // continue;
            _removeHPoly(other);
          } else if (identical(merge, other.polygon)) {
            // other contains polygon: result will also be contained here
            lastContainer = other.polygon;

            if (samePole) {
              // (same pole)

              if (other.children.isEmpty) {
                // polygon doesn't change anything
                return;
              }
            } else {
              // (diff pole)
              parentDiff = other;
            }

            // return traverseDown;
            nextLayer.addAll(other.children);
            break;
          }
        } else if (result is OperationResultNoOverlap) {
          if (samePole) {
            final assignedParents = parentSame[other.polygon];
            if (assignedParents != null) {
              _setParent(other.polygon, assignedParents.first);
            }
          }
        } else if (result is OperationResultTransform) {
          isectAny = true;

          // they intersect and transform into a single new shape
          // continue traverseDown;
          nextLayer.addAll(other.children);
          if (samePole) {
            if (makeBridge) {
              final parents = parentSame[other.polygon] ?? [parent!];
              _makeBridge(other, parents, parentSame, nParentSame);

              parent = null;
            } else {
              // other was expanded
              mergeIntoParent.add(other);
              for (var poly in result.output) {
                if (poly.positive == other.polygon.positive) {
                  layerPoly = poly;
                } else {
                  // Union of two same pole polygons lead to new holes
                  nHoles.add(poly);
                }
              }
            }
          } else {
            // other was subtracted from
            makeBridge = true;
            _replacePolygonWith(
              other.polygon,
              other.children.map((e) => e.polygon).toList(),
              result.output,
              parentSame,
              nParentSame,
            );
          }
        }
      }

      if (samePole && !makeBridge && mergeIntoParent.isNotEmpty) {
        _add(layerPoly, parent);

        // shift (diff) children up, remove
        for (var affected in mergeIntoParent) {
          for (var child in affected.children) {
            _setParent(child.polygon, layerPoly);
          }
          _remove(affected.polygon);
        }

        List<HPolygon> holeChildren = [];
        for (var other in layer.difference(mergeIntoParent)) {
          final Map<Polygon, Iterable<Polygon>> holeReplacements = {};
          for (var nHole in nHoles) {
            final split = union(nHole, other.polygon);
            if (split is OperationResultContain) {
              // other is contained inside nHole
              holeChildren.add(other);
              continue;
            } else if (split is OperationResultNoOverlap) {
              continue;
            }

            holeReplacements[nHole] = split.output;
          }
          if (holeReplacements.isNotEmpty) {
            _remove(other.polygon);
            for (var remove in holeReplacements.keys) {
              var add = holeReplacements[remove];
              nHoles.remove(remove);
              nHoles.addAll(add ?? const []);
            }
          }
        }

        for (var hole in nHoles) {
          _add(hole, layerPoly);
        }

        for (var contained in holeChildren) {
          for (var hole in nHoles) {
            if (hole.contains(contained.polygon)) {
              _setParent(contained.polygon, hole);
              break;
            }
          }
        }
      }

      samePole = !samePole;
      layer = nextLayer;
      parentSame = nParentSame;
    }

    if (!isectAny &&
        (lastContainer == null
            ? polygon.positive
            : lastContainer.positive != polygon.positive)) {
      _add(polygon, parentDiff?.polygon);
    }
  }
}

/// Merges `polygon` into `state`.
PolygonState mergePolygon(PolygonState state, Polygon polygon) {
  final out = state.copy();
  PolygonMerger().mergePolygon(out, polygon);
  return out;
}
