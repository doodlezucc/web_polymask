import 'dart:async';
import 'dart:html';
import 'dart:svg' as svg;

import 'binary.dart';
import 'brushes/brush.dart';
import 'interactive/svg_polygon.dart';
import 'math/point_convert.dart';
import 'math/polygon.dart';
import 'math/polymath.dart';
import 'polygon_canvas_data.dart';

typedef DebugErrorFn = void Function(
  dynamic error,
  StackTrace stackTrace,
  String previousData,
  Polygon polygon,
);

class PolygonCanvas with CanvasLoader {
  final _polygons = <SvgPolygon>{};
  final svg.SvgSvgElement root;
  final svg.SvgElement _polypos;
  final svg.SvgElement _polyneg;
  final svg.SvgElement _polyprev;

  void Function() onChange;
  DebugErrorFn debugOnError;
  PolygonBrush brush = PolygonBrush.stroke;

  bool Function(Event ev) acceptStartEvent;
  Point Function(Point p) modifyPoint;
  bool captureInput;
  BrushPath activePath;
  SvgPolygon activePolygon;
  Point<int> _currentP;
  int cropMargin;

  bool get isEmpty => _polygons.isEmpty;
  bool get isNotEmpty => !isEmpty;

  PolygonCanvas(
    this.root, {
    this.captureInput = true,
    this.onChange,
    this.acceptStartEvent,
    this.modifyPoint,
    this.cropMargin = 2,
  })  : _polypos = root.querySelector('#polypos'),
        _polyneg = root.querySelector('#polyneg'),
        _polyprev = root.querySelector('#polyprev') {
    _initKeyListener();
    _initCursorControls();
    // addPolygon(SvgPolygon(getPoleParent(true), points: ))
  }

  void clear({bool triggerChangeEvent = true}) {
    _polygons.forEach((element) => element.dispose());
    _polygons.clear();
    if (triggerChangeEvent) _triggerOnChange();
  }

  @override
  void fromData(String base64) {
    clear(triggerChangeEvent: false);
    canvasFromData(
      base64,
      (positive, points) => _polygons.add(SvgPolygon.from(
        getPoleParent(positive),
        positive: positive,
        points: points,
      )),
    );
  }

  void fromPolygons(Iterable<SvgPolygon> polygons) {
    // Avoid recursion
    if (polygons == _polygons) return;

    clear(triggerChangeEvent: false);
    for (var src in polygons) {
      _polygons
          .add(SvgPolygon(getPoleParent(src.polygon.positive), src.polygon));
    }
  }

  @override
  String toData() => canvasToData(_polygons.map((e) => e.polygon).toList());

  static bool _isInput(Element e) => e is InputElement || e is TextAreaElement;

  void instantiateActivePolygon({bool includeCursorPoint = true}) {
    if (activePath != null) {
      if (includeCursorPoint && _currentP != null) {
        activePath..handleMouseMove(_currentP);
      }

      try {
        addPolygon(activePolygon..refreshSvg());
      } finally {
        activePolygon = null;
        activePath = null;
      }
    }
  }

  void _initKeyListener() {
    window.onKeyDown.listen((ev) {
      if (captureInput && !_isInput(ev.target)) {
        switch (ev.keyCode) {
          case 24: // Delete
          case 8: // Backspace
          case 27: // Escape
            if (activePath != null) {
              activePolygon.dispose();
              activePath = null;
              activePolygon = null;
              _hidePreview();
              ev.preventDefault();
            }
            return;

          case 13: // Enter
          case 32: // Space
            instantiateActivePolygon();
            ev.preventDefault();
            return;
        }
      }
    });
  }

  void _hidePreview() => _polyprev.setAttribute('points', '');

  void _drawPreview([Point<int> extra]) {
    _polyprev.setAttribute('points', activePolygon.el.getAttribute('points'));
    _polyprev.classes.toggle('poly-invalid', !activePath.isValid(extra));
  }

  Element getPoleParent(bool positive) => positive ? _polypos : _polyneg;

  void _initCursorControls() {
    StreamController<Point<int>> moveStreamCtrl;

    void listenToCursorEvents<T extends Event>(
      Point Function(T ev) evToPoint,
      Stream<T> startEvent,
      Stream<T> moveEvent,
      Stream<T> endEvent,
    ) {
      Point<int> fixedPoint(T ev) {
        var p = evToPoint(ev);
        if (modifyPoint != null) p = modifyPoint(p);
        return forceIntPoint(p);
      }

      startEvent.listen((ev) async {
        if (!captureInput ||
            (acceptStartEvent != null && !acceptStartEvent(ev)) ||
            !ev.path.any((e) => e == root)) return;

        ev.preventDefault();
        document.activeElement.blur();

        _currentP = fixedPoint(ev);
        var createNew = activePolygon == null;
        var click = brush.employClickEvent;

        if (ev is MouseEvent && ev.button == 2 && activePolygon != null) {
          return instantiateActivePolygon();
        }

        if (createNew) {
          // Start new polygon
          var pole = !(ev as dynamic).shiftKey;

          _polyprev.classes.toggle('positive-pole', pole);

          activePath = brush.startPath(_currentP);
          activePolygon = SvgPolygon.from(
            getPoleParent(pole),
            points: activePath.points,
            positive: pole,
          );
          _drawPreview();

          if (!activePath.brush.employClickEvent) {
            addPolygon(activePolygon);
          }

          moveStreamCtrl = StreamController();
          moveStreamCtrl.stream.listen((point) {
            return;
            // Polygon could have been cancelled by user
            if (activePath != null) {
              if (activePath.handleMouseMove(point)) {
                activePolygon.refreshSvg();
                _drawPreview();
                if (!activePath.brush.employClickEvent) {
                  addPolygon(activePolygon);
                }
              }
              click = false;
            }
          });
        } else {
          // Add single point to active polygon
          activePath.handleMouseMove(_currentP);
        }

        await endEvent.first;
        if (moveStreamCtrl != null) {
          await moveStreamCtrl.close();
          moveStreamCtrl = null;
        }

        if (createNew &&
            !click &&
            activePath != null &&
            activePath.brush.employClickEvent) {
          addPolygon(activePolygon);
        }
        activePath = null;
        activePolygon.dispose();
        activePolygon = null;
      });

      moveEvent.listen((ev) {
        if (moveStreamCtrl != null) {
          moveStreamCtrl.add(fixedPoint(ev));
        } else if (activePolygon != null) {
          _currentP = fixedPoint(ev);
          activePolygon.refreshSvg(_currentP);
          _drawPreview(_currentP);
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

  /// Convert points to SVG polygon data (debugging)
  void printPolys(Iterable<SvgPolygon> result) {
    for (var svg in result) {
      print(svg.polygon.points.map((p) => '${p.x},${p.y}').join(' '));
    }
  }

  void addPolygon(SvgPolygon polygon) {
    var polyState = _polygons.toSet();
    _hidePreview();
    print('ayo');
    printPolys(polyState);
    print('plus this one');
    printPolys([polygon]);

    try {
      _addPolygon(polygon);
      // for (var b in _polygons) {
      //   if (!b.polygon.isSimple()) {
      //     print('ayo');
      //     printPolys(polyState);
      //     print('plus this one');
      //     printPolys([polygon]);
      //     print('makes something unsimple');
      //     break;
      //   }
      // }
    } catch (e, stack) {
      if (debugOnError != null) {
        debugOnError(
            e,
            stack,
            canvasToData(polyState.map((e) => e.polygon).toList()),
            polygon.polygon);
      }

      fromPolygons(polyState);
      if (debugOnError == null) rethrow;
    }
  }

  void _addPolygon(SvgPolygon svg) {
    if (svg.polygon.points.length >= 3 && activePath.isValid()) {
      if (svg.polygon.positive) {
        var cropped = _cropPolygon(svg.polygon);
        for (var poly in cropped) {
          _mergePolygon(poly);
        }
      } else {
        // No need to crop negative polygons
        _mergePolygon(svg.polygon);
      }
    }
  }

  SvgPolygon _makeSvgPoly(Polygon src) =>
      SvgPolygon(getPoleParent(src.positive), src);

  void _mergePolygon(Polygon polygon) {
    final asSvg = Map.fromEntries(_polygons.map((e) => MapEntry(e.polygon, e)));
    final state = asSvg.keys.toSet();
    final result = mergePolygon(state, polygon);
    bool changed = false;

    for (var add in result.difference(state)) {
      print('add');
      _polygons.add(_makeSvgPoly(add));
      changed = true;
    }

    for (var removed in state.difference(result)) {
      print('remove');
      _polygons.remove(asSvg[removed]..dispose());
      changed = true;
    }

    if (changed) _triggerOnChange();
  }

  void _triggerOnChange() {
    if (onChange != null) onChange();
  }

  /// Returns a positive polygon covering the entire canvas.
  Polygon makeCropRect() {
    var w = root.parent.clientWidth - cropMargin;
    var h = root.parent.clientHeight - cropMargin;
    return Polygon(points: [
      Point(cropMargin, cropMargin),
      Point(w, cropMargin),
      Point(w, h),
      Point(cropMargin, h),
    ]);
  }

  Iterable<Polygon> _cropPolygon(Polygon polygon) {
    return intersection(polygon, makeCropRect());
  }

  void fillCanvas() {
    addPolygon(SvgPolygon(getPoleParent(true), makeCropRect()));
  }
}
