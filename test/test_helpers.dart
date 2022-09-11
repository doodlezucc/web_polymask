import 'dart:math';

import 'package:test/test.dart';
import 'package:web_polymask/math/polygon.dart';
import 'package:web_polymask/math/polygon_state.dart';
import 'package:web_polymask/math/polymath.dart';
import 'package:web_polymask/math/ring_search.dart';

Polygon fromRect(Rectangle<int> rect, {bool positive = true}) {
  return Polygon(positive: positive, points: [
    rect.bottomLeft,
    rect.bottomRight,
    rect.topRight,
    rect.topLeft,
  ]);
}

/// Prints a list of polygons as SVG polygon data (debugging).
void printPolys(Iterable<Polygon> result) {
  for (var poly in result) {
    print(poly.points.map((p) => '${p.x},${p.y}').join(' '));
  }
}

/// Parses a list of 2D points in SVG polygon data format.
List<Point<int>> parse(String s) {
  return s.split(' ').map((co) {
    var parts = co.split(',');
    return Point(int.parse(parts[0]), int.parse(parts[1]));
  }).toList();
}

void expectUnion(
  Polygon a,
  Polygon b,
  Iterable<Polygon> expected, {
  bool bidirectional = true,
  bool checkPointsInOrder = true,
}) {
  final matcher =
      PolygonOperationMatcher(expected, checkOrder: checkPointsInOrder);

  expect(union(a, b), matcher);
  if (bidirectional) expect(union(b, a), matcher);
}

Iterable<Polygon> expectUnionEqual(Polygon a, Polygon b) {
  var result1 = union(a, b);
  final matcher = unorderedEquals(
      result1.map((e) => polygonMatch(e.points, positive: e.positive)));

  expect(union(b, a), matcher);
  return result1;
}

void expectMergeHierarchy(
    PolygonState state, Polygon polygon, Set<HPolygon> expected) {
  expect(
    mergePolygon(state, polygon),
    TypeMatcher<PolygonState>().having(
      (state) => state.toHierarchy(),
      'Hierarchy',
      hierarchyMatch(expected),
    ),
  );
}

Matcher hierarchyMatch(Set<HPolygon> expected) {
  return unorderedMatches(expected.map(hpolyMatch));
}

Matcher parentsMatch(Map<Polygon, Polygon> expected) {
  return unorderedMatches(expected.entries.map((ex) =>
      TypeMatcher<MapEntry<Polygon, Polygon>>()
          .having((m) => m.key, 'Key', polygonMatchInstance(ex.key))
          .having((m) => m.value, 'Value', polygonMatchInstance(ex.value))));
}

Matcher hpolyMatch(HPolygon expected) {
  return isA<HPolygon>()
      .having(
          (hp) => hp.polygon,
          'Polygon',
          polygonMatch(
            expected.polygon.points,
            positive: expected.polygon.positive,
            requireSimple: false,
          ))
      .having(
          (hp) => hp.children, 'Children', hierarchyMatch(expected.children));
}

void expectMerge(PolygonState state, Polygon polygon, PolygonState expected) {
  final matcher = stateMatch(expected);
  expect(mergePolygon(state, polygon), matcher);
}

Matcher stateMatch(PolygonState expected) {
  return isA<PolygonState>()
      .having((state) => state.isValid(), 'Validity', isTrue)
      .having((state) => state.toHierarchy(), 'Hierarchy',
          StateMatcher(expected.toHierarchy()));
}

abstract class HierarchyMatcher<T, M> extends Matcher {
  final Iterable<T> expected;

  HierarchyMatcher(this.expected);

  Matcher matchFeature(M feature);
  String describeFeature(M feature);
  M getFeature(T instance);
  Iterable<T> getChildren(T instance);

  String _depth(Iterable<T> siblings, int depth, Iterable<T> missing) {
    String out = '';
    String d = '  ' * depth;
    for (var t in siblings) {
      out += '\n$d- ' + describeFeature(getFeature(t));
      if (missing.contains(t)) {
        out += ' <-- MISSING';
      }
      out += _depth(getChildren(t), depth + 1, missing);
    }
    return out;
  }

  @override
  Description describe(Description description) =>
      description.add(_depth(expected, 0, []));

  bool matchLayer(Iterable<T> layer, Iterable<T> expected, Map matchState) {
    bool allMatch = true;
    for (var ex in expected) {
      final matcher = matchFeature(getFeature(ex));
      bool found = false;
      for (var t in layer) {
        if (matcher.matches(getFeature(t), {})) {
          found = true;

          bool childrenMatch = matchLayer(
            getChildren(t),
            getChildren(ex),
            matchState,
          );

          if (!childrenMatch) {
            allMatch = false;
          }
          break;
        }
      }

      if (!found) {
        allMatch = false;
        (matchState['missing'] as List).add(ex);
      }
    }
    return allMatch;
  }

  @override
  bool matches(item, Map matchState) {
    matchState['missing'] = <T>[];
    if (item is Iterable<T>) {
      return matchLayer(item, expected, matchState);
    }

    return false;
  }

  @override
  Description describeMismatch(
      item, Description mismatchDescription, Map matchState, bool verbose) {
    if (item is Iterable<T>) {
      return mismatchDescription
          .add(_depth(expected, 0, matchState['missing']));
    }
    return mismatchDescription
        .add('has invalid iterable subtype ${item.runtimeType}');
  }
}

class StateMatcher extends HierarchyMatcher<HPolygon, Polygon> {
  StateMatcher(Iterable<HPolygon> expected) : super(expected);

  @override
  String describeFeature(Polygon feature) {
    return feature.toString();
  }

  @override
  Iterable<HPolygon> getChildren(HPolygon instance) {
    return instance.children;
  }

  @override
  Matcher matchFeature(Polygon feature) {
    return polygonMatchInstance(feature);
  }

  @override
  Polygon getFeature(HPolygon instance) {
    return instance.polygon;
  }
}

Matcher polygonMatchInstance(
  Polygon expected, {
  bool requireSimple = true,
  bool checkOrder = true,
  Map map,
}) {
  if (expected == null) return isNull;
  forceClockwise(expected);
  return polygonMatch(
    expected.points,
    positive: expected.positive,
    requireSimple: requireSimple,
    checkOrder: checkOrder,
    map: map,
  );
}

Matcher polygonMatch(
  List<Point<int>> points, {
  bool requireSimple = true,
  bool checkOrder = true,
  bool positive,
  Map map,
}) {
  var matcher = TypeMatcher<Polygon>();

  if (positive != null) {
    matcher = matcher.having((p) => p.positive, 'Pole', positive);
  }

  if (requireSimple) {
    matcher = matcher.having((p) => p.isSimple(), 'Simplicity', isTrue);
  }

  return matcher.having((p) {
    forceClockwise(p);
    return p.points;
  }, 'points',
      checkOrder ? ringMatch(points, map: map) : unorderedEquals(points));
}

class PolygonOperationMatcher extends TypeMatcher<Iterable<Polygon>> {
  Matcher _matcher;
  final Iterable<Polygon> expected;
  final Map errorMap = {};

  PolygonOperationMatcher(this.expected, {bool checkOrder = true}) {
    _matcher = unorderedMatches(expected.map((p) => polygonMatch(
          p.points,
          positive: p.positive,
          map: errorMap,
          checkOrder: checkOrder,
        )));
  }

  @override
  bool matches(item, Map matchState) => _matcher.matches(item, matchState);

  @override
  Description describe(Description description) =>
      description.addDescriptionOf(expected);

  @override
  Description describeMismatch(covariant Iterable<Polygon> mismatch,
      Description desc, Map matchState, bool verbose) {
    if (errorMap.isEmpty) {
      for (var i = 0; i < mismatch.length; i++) {
        if (!mismatch.elementAt(i).isSimple()) {
          desc.add('Contains self-intersecting polygon at index $i\n');
        }
      }
    }

    for (List<Point> other in errorMap.keys) {
      final RingSearchError error = errorMap[other];
      final index = error.errorInRing;

      desc.add("Doesn't match index $index:\n");

      for (var i = 0; i < other.length; i++) {
        final r = error.ring[i];
        final pair = other[(i + error.offset) % other.length];

        var s = '  $r | $pair';
        if (i == index) s += ' <---';

        desc.add('$s\n');
      }
    }

    return desc;
  }
}

Matcher ringMatch<S>(List<S> ring, {Map map}) =>
    allOf(hasLength(ring.length), _RingMatcher<S>(ring, map));

class _RingMatcher<S> extends TypeMatcher<List<S>> {
  final Map map;
  final List<S> ring;

  _RingMatcher(this.ring, this.map);

  @override
  bool matches(Object other, Map matchState) {
    if (other is List<S>) {
      final error = ringMismatch(ring, other);
      if (error == null) return true;

      if (map != null) map[other] = error;
    }

    return false;
  }
}
