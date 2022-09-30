import 'package:web_polymask/math/polygon.dart';
import 'package:web_polymask/math/polygon_state.dart';
import 'package:web_polymask/math/polymath.dart';

import 'test_helpers.dart';

void main() {
  final state = parseState('''
- (positive, 80,56 64,56 64,48 56,48 56,40 40,40 40,48 32,48 32,56 24,56 24,48 16,48 16,32 24,32 24,24 32,24 32,16 56,16 56,8 72,8 72,16 80,16)
  - (negative, 32,32 32,40 24,40 24,32)
  - (negative, 72,40 56,40 56,16 72,16)
''');

  final polygon = Polygon(
    points: parse('64,16 72,16 72,24 64,24'),
    positive: false,
  );

  final pstate = PolygonState.assignParents(state);
  print(pstate.isValid(checkSimplicity: true));
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
  print(pstate.isValid(checkSimplicity: true));
}
