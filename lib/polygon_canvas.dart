import 'dart:async';
import 'dart:html';
import 'dart:math';
import 'dart:svg' as svg;

import 'package:web_polygons/offline_canvas.dart';
import 'package:web_polygons/point_convert.dart';

import 'interactive/svg_polygon.dart';

class PolygonCanvas extends OfflinePolygonCanvas {
  final HtmlElement _container;
  final svg.SvgSvgElement root;
  bool captureInput;

  SvgPolygon activePolygon;

  final double _zoomCorrection = 1;

  PolygonCanvas(HtmlElement container, {this.captureInput = true})
      : _container = container,
        root = svg.SvgSvgElement() {
    _initCursorControls();
    _container.append(root);
  }

  void _initCursorControls() {
    StreamController<Point<int>> moveStreamCtrl;

    void listenToCursorEvents<T extends Event>(
      Point Function(T ev) evToPoint,
      Stream<T> startEvent,
      Stream<T> moveEvent,
      Stream<T> endEvent,
    ) {
      Point<int> fixedPoint(T ev) =>
          forceIntPoint(evToPoint(ev) * (1 / _zoomCorrection));

      startEvent.listen((ev) async {
        if (!captureInput || !ev.path.any((e) => e == root)) return;

        ev.preventDefault();
        document.activeElement.blur();
        moveStreamCtrl = StreamController.broadcast();

        var p = fixedPoint(ev);

        if (activePolygon == null) {
          // Start new polygon
          activePolygon = SvgPolygon(this, points: [p]);
          moveStreamCtrl.stream.listen((point) {
            activePolygon.addPoint(point);
          });
        } else {
          // TODO: Add single point to active polygon
        }

        await endEvent.first;
        await moveStreamCtrl.close();
        moveStreamCtrl = null;
        activePolygon = null;
      });

      moveEvent.listen((ev) {
        if (moveStreamCtrl != null) {
          moveStreamCtrl.add(fixedPoint(ev));
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
