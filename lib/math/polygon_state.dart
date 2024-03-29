import 'polygon.dart';

class PolygonState {
  final Map<Polygon, Polygon?> parents;

  PolygonState(this.parents);

  PolygonState.assignParents(Set<Polygon> state) : parents = {} {
    for (var poly in state) {
      parents[poly] = null;

      for (var other in state) {
        if (other.positive != poly.positive) {
          if (other.contains(poly)) {
            final polyParent = parents[poly];

            if (polyParent == null || polyParent.contains(other)) {
              parents[poly] = other;
            }
          }
        }
      }
    }
  }

  PolygonState.assignChildrenBase(PolygonState base, Set<Polygon> add)
      : this.assignParents({...base.parents.keys, ...add});

  PolygonState.fromHierarchy(Set<HPolygon> hierarchy) : parents = {} {
    for (var root in hierarchy) {
      _assignParent(root, null);
    }
  }

  void _assignParent(HPolygon poly, Polygon? parent) {
    parents[poly.polygon] = parent;
    for (var child in poly.children) {
      _assignParent(child, poly.polygon);
    }
  }

  bool isValid({bool checkSimplicity = false}) {
    if (!parents.entries.every((e) {
      final polygon = e.key;
      final parent = e.value;

      // Roots must be positive
      if (parent == null) return e.key.positive;

      // Parents must be of oppositive pole and fully contain their children.
      return polygon.positive != parent.positive && parent.contains(polygon);
    })) return false;

    if (checkSimplicity) {
      return parents.keys.every((p) => p.isSimple());
    }

    return true;
  }

  Set<HPolygon> toHierarchy() {
    final conv = parents.map((p, _) => MapEntry(p, HPolygon(p, {})));
    final root = <HPolygon>{};

    for (var c in conv.entries) {
      final parent = parents[c.key];
      if (parent == null) {
        root.add(c.value);
      } else {
        conv[parent]!.children.add(c.value);
      }
    }

    return root;
  }

  PolygonState copy() => PolygonState(Map.of(parents));

  @override
  String toString() {
    final hierarchy = toHierarchy();
    final content = _depth(hierarchy, 0);
    return '[$content\n]';
  }

  static String _depth(Iterable<HPolygon> hp, int depth) {
    var out = '';
    final s = '  ' * depth;
    for (var p in hp) {
      out += '\n$s- ${p.polygon}';
      out += _depth(p.children, depth + 1);
    }
    return out;
  }
}

class HPolygon {
  final Polygon polygon;
  final Set<HPolygon> children;

  HPolygon(this.polygon, this.children);

  @override
  String toString() {
    final ch = children.join(', ');
    return '$polygon [$ch]';
  }
}
