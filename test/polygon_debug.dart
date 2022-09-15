import 'package:web_polymask/math/polygon.dart';
import 'package:web_polymask/math/polygon_state.dart';
import 'package:web_polymask/math/polymath.dart';

import 'test_helpers.dart';

void main() {
  final state = parseState('''
- (positive, 875,40 901,86 600,86 601,88 515,88 543,40)
''');

  final polygon = Polygon(points: parse('765,40 779,65 693,65 707,40'));

  final pstate = PolygonState.assignParents(state);
  final merger = PolygonMerger(
    onAdd: (p, parent) {
      print('add $p to $parent');
      if (!p.isSimple()) {
        print('POLYGON IS NOT SIMPLE');
      }
    },
    onRemove: (p) => print('remove $p'),
    onUpdateParent: (p, parent) => print('reappend $p to $parent'),
  );
  merger.mergePolygon(pstate, polygon);
  print(pstate);
  print(pstate.isValid());
}
