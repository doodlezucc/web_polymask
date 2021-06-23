import 'dart:async';
import 'dart:html';
import 'dart:math';
import 'dart:svg' as svg;

import 'package:web_polygons/offline_canvas.dart';
import 'package:web_polygons/point_convert.dart';
import 'package:web_polygons/polygon.dart';

import 'interactive/svg_polygon.dart';

class PolygonCanvas extends OfflinePolygonCanvas {
  final HtmlElement _container;
  final svg.SvgSvgElement root;
  bool captureInput;

  SvgPolygon activePolygon;

  PolygonCanvas(HtmlElement container, {this.captureInput = true})
      : _container = container,
        root = svg.SvgSvgElement()
          ..setAttribute('width', '100%')
          ..setAttribute('height', '100%') {
    _initKeyListener();
    _initCursorControls();
    _container.append(root);
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
          activePolygon = SvgPolygon(this, points: [p]);
          moveStreamCtrl = StreamController();
          moveStreamCtrl.stream.listen((point) {
            activePolygon.addPoint(point);
            click = false;
          });
        } else {
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
        (ev) => ev.page - _container.documentOffset,
        root.onMouseDown,
        window.onMouseMove,
        window.onMouseUp);

    listenToCursorEvents<TouchEvent>(
        (ev) => ev.targetTouches[0].page - _container.documentOffset,
        root.onTouchStart,
        window.onTouchMove,
        window.onTouchEnd);
  }
}
