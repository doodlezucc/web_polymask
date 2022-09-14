import 'package:web_polymask/math/polygon.dart';
import 'package:web_polymask/math/polygon_state.dart';
import 'package:web_polymask/math/polymath.dart';

import 'test_helpers.dart';

void main() {
  final state = parseState('''
- (positive, 960,40 960,660 40,660 40,40)
  - (negative, 550,234 557,246 560,240 559,240 563,234 590,234 584,244 633,244 625,258 627,258 622,266 597,266 604,278 607,273 614,286 611,291 621,291 612,306 639,306 652,328 652,327 656,335 655,337 638,367 636,363 623,385 620,379 615,387 611,380 605,391 600,391 607,378 594,378 601,366 586,366 591,357 575,357 580,348 564,348 569,339 553,339 558,330 541,330 546,321 530,321 535,313 518,313 522,306 505,306 510,298 493,298 498,290 481,290 487,280 468,280 474,269 455,269 462,257 443,257 450,245 434,245 441,232 488,232 487,230 504,230 503,228 525,228 523,224 529,224 532,229 535,224 537,224 544,237 546,234)
    - (positive, 595,266 593,270 590,266)
    - (positive, 570,240 566,247 562,240)
''');

  final polygon = Polygon(points: parse('561,165 604,240 518,240'));

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
