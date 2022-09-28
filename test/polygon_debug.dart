import 'package:web_polymask/math/polygon.dart';
import 'package:web_polymask/math/polygon_state.dart';
import 'package:web_polymask/math/polymath.dart';

import 'test_helpers.dart';

void main() {
  final state = parseState('''
- (positive, 160,160 80,160 80,80 160,80)
- (positive, 880,320 960,320 960,480 880,480 880,560 800,560 800,640 640,640 640,660 400,660 400,640 240,640 240,560 160,560 160,480 80,480 80,320 160,320 160,400 400,400 400,480 480,480 480,560 720,560 720,400 880,400)
- (positive, 800,160 800,80 880,80 880,160)
- (positive, 560,80 640,80 640,160 560,160)
- (positive, 400,160 480,160 480,240 400,240)
- (positive, 240,160 240,80 320,80 320,160)
''');

  final polygon = Polygon(
    points: parse(
        '240,240 400,240 400,320 560,320 560,240 720,240 720,160 800,160 800,80 160,80 160,160 240,160'),
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
