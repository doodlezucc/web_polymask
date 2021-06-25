import 'dart:async';
import 'dart:html';
import 'dart:math';
import 'dart:svg' as svg;

import 'package:web_polymask/offline_canvas.dart';
import 'package:web_polymask/point_convert.dart';
import 'package:web_polymask/polygon.dart';

import 'interactive/svg_polygon.dart';

class PolygonCanvas extends OfflinePolygonCanvas {
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

  @override
  void addPolygon(Polygon polygon) {
    if (polygon.points.length < 3) {
      (polygon as SvgPolygon).dispose();
    } else {
      super.addPolygon(polygon);
    }
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

        if (createNew && !click) {
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
}
