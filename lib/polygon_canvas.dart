import 'dart:async';
import 'dart:html';
import 'dart:math';
import 'dart:svg' as svg;

import 'package:web_polymask/math/polymath.dart';
import 'package:web_polymask/math/point_convert.dart';
import 'package:web_polymask/math/polygon.dart';

import 'interactive/svg_polygon.dart';

class PolygonCanvas {
  final _polygons = <SvgPolygon>[];
  final svg.SvgSvgElement root;
  final polypos = svg.ClipPathElement();
  final polyneg = svg.GElement();
  bool captureInput;

  SvgPolygon activePolygon;

  PolygonCanvas(this.root, {this.captureInput = true}) {
    _initKeyListener();
    _initCursorControls();

    root
      ..setAttribute('width', '100%')
      ..setAttribute('height', '100%')
      ..append(polypos..id = 'polypos');
    root.append(polyneg..id = 'polyneg');
  }

  static bool _isInput(Element e) => e is InputElement || e is TextAreaElement;

  void _initKeyListener() {
    window.onKeyDown.listen((ev) {
      if (captureInput && !_isInput(ev.target)) {
        switch (ev.keyCode) {
          case 24: // Delete
          case 8: // Backspace
          case 27: // Escape
            if (activePolygon != null) {
              activePolygon.dispose();
              activePolygon = null;
            }
            return;

          case 13: // Enter
            if (activePolygon != null) {
              addPolygon(activePolygon..refreshSvg());
              activePolygon = null;
            }
            return;
        }
      }
    });
  }

  void _initCursorControls() {
    StreamController<Point<int>> moveStreamCtrl;

    void listenToCursorEvents<T extends Event>(
      Point Function(T ev) evToPoint,
      Stream<T> startEvent,
      Stream<T> moveEvent,
      Stream<T> endEvent,
    ) {
      Point<int> fixedPoint(T ev) => forceIntPoint(evToPoint(ev));

      startEvent.listen((ev) async {
        if (!captureInput || !ev.path.any((e) => e == root)) return;

        ev.preventDefault();
        document.activeElement.blur();

        var p = fixedPoint(ev);
        var createNew = activePolygon == null;
        var click = true;

        if (createNew) {
          // Start new polygon
          activePolygon = SvgPolygon(
            this,
            points: [p],
            positive: !(ev as dynamic).shiftKey,
          );
          moveStreamCtrl = StreamController();
          moveStreamCtrl.stream.listen((point) {
            activePolygon.addPoint(point);
            click = false;
          });
        } else {
          // Add single point to active polygon
          activePolygon.addPoint(p);
        }

        await endEvent.first;
        if (moveStreamCtrl != null) {
          await moveStreamCtrl.close();
          moveStreamCtrl = null;
        }

        if (createNew && !click && activePolygon != null) {
          addPolygon(activePolygon);
          activePolygon = null;
        }
      });

      moveEvent.listen((ev) {
        if (moveStreamCtrl != null) {
          moveStreamCtrl.add(fixedPoint(ev));
        } else if (activePolygon != null) {
          activePolygon.refreshSvg(fixedPoint(ev));
        }
      });
    }

    listenToCursorEvents<MouseEvent>(
        (ev) => ev.page - root.getBoundingClientRect().topLeft,
        root.onMouseDown,
        window.onMouseMove,
        window.onMouseUp);

    listenToCursorEvents<TouchEvent>(
        (ev) => ev.targetTouches[0].page - root.getBoundingClientRect().topLeft,
        root.onTouchStart,
        window.onTouchMove,
        window.onTouchEnd);
  }

  void addPolygon(SvgPolygon polygon) {
    if (polygon.points.length < 3) {
      polygon.dispose();
    } else {
      var pole = polygon.positive;
      var affected = <SvgPolygon>{};
      var nPolys = <Polygon>[];
      Polygon bigPoly = polygon;
      var removeSrc = false;
      var removeBig = false;
      var inside = false;

      void equalPole() {
        // Merge all equally polarized polygons
        for (var other in _polygons.where((p) => p.positive == pole)) {
          var united = union(bigPoly, other);
          print('Union made ${united.length} polygons');
          if (united.length == 1) {
            var merge = united.first;
            if (merge != other) {
              affected.add(other);

              if (merge != bigPoly) {
                // There's one big shape now
                removeSrc = true;
                bigPoly = merge;
              }
            } else {
              removeSrc = true;
            }
          } else if (united.length == 2 && united.first == bigPoly) {
            // No overlapping
          } else {
            // Wow, cool new shape with holes and stuff
            affected.add(other);
            removeSrc = true;
            bigPoly = united.firstWhere((p) => p.positive);
            nPolys.addAll(united.where((p) => !p.positive));
          }
        }
      }

      void diffPole() {
        // Subtract big poly from other poles
        for (var other in _polygons.where((p) => p.positive != pole)) {
          var united = union(other, bigPoly);
          print('Difference made ${united.length} polygons');
          if (united.length == 1 && united.first.positive == pole) {
            // This opposite pole is now gone
            affected.add(other);
          } else if (united.length == 2 && united.any((p) => p == bigPoly)) {
            // No overlapping
            if (united.first == bigPoly) {
              // A contains B
              inside = true;
            }
          } else {
            // Opposite pole gets transformed, maybe split into multiple
            affected.add(other);
            removeBig = !pole;
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
        removeBig = true;
      }

      for (var aff in affected) {
        _polygons.remove(aff..dispose());
      }
      _polygons.addAll(nPolys.map((p) => SvgPolygon.copy(this, p)));

      print('$removeSrc | $removeBig | $inside');

      if (removeSrc || removeBig) {
        polygon.dispose();
        if (bigPoly != polygon && (inside || !removeBig)) {
          _polygons.add(SvgPolygon.copy(this, bigPoly));
        }
      } else {
        _polygons.add(polygon);
      }

      print(_polygons.length);
    }
  }
}
