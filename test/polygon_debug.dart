import 'package:web_polymask/math/polygon.dart';
import 'package:web_polymask/math/polygon_state.dart';
import 'package:web_polymask/math/polymath.dart';

import 'test_helpers.dart';

void main() {
  final state = parseState('''
- (positive, 40,40 960,40 960,660 40,660)
  - (negative, 511,533 432,533 424,519 338,519 323,520 303,520 285,521 273,521 272,519 255,520 239,521 230,522 224,522 213,524 181,468 166,465 113,465 113,464 110,449 108,433 102,388 99,374 97,359 88,317 86,302 83,287 83,239 84,224 86,209 89,164 89,118 92,104 99,81 318,81 296,120 382,120 397,118 413,115 428,113 445,111 463,109 480,106 497,104 512,103 525,102 524,104 640,104 685,101 755,86 771,83 782,83 763,117 841,117 833,122 816,151 790,197 804,201 819,205 835,206 873,206 871,216 871,327 872,345 872,364 873,379 874,397 875,412 876,429 868,415 851,444 825,490 826,505 826,520 829,535 830,550 832,565 834,581 837,597 839,613 843,629 825,629 783,627 764,626 741,625 723,625 709,601 692,599 549,599)
''');

  final polygon = Polygon(
    points: parse('511,533 554,608 537,610 451,610 494,535'),
  );

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
