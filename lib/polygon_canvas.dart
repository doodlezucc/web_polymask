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
  final _polygons = <SvgPolygon>[];
  final svg.SvgSvgElement root;
  final svg.SvgElement _polypos;
  final svg.SvgElement _polyneg;
  final svg.SvgElement _polyprev;

  void Function() onChange;
  DebugErrorFn debugOnError;
  PolygonBrush brush = PolygonBrush.lasso;

  bool Function(Event ev) acceptStartEvent;
  Point Function(Point p) modifyPoint;
  bool captureInput;
  BrushPath activePath;
  SvgPolygon get activePolygon => activePath?.polygon;
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
      (positive, points) => _polygons.add(SvgPolygon(
        getPoleParent(positive),
        positive: positive,
        points: points,
      )),
    );
  }

  void fromPolygons(List<Polygon> polygons) {
    // Avoid recursion
    if (polygons == _polygons) return;

    clear(triggerChangeEvent: false);
    for (var src in polygons) {
      _polygons.add(SvgPolygon.copy(getPoleParent(src.positive), src));
    }
  }

  @override
  String toData() => canvasToData(_polygons);

  static bool _isInput(Element e) => e is InputElement || e is TextAreaElement;

  void instantiateActivePolygon({bool includeCursorPoint = true}) {
    if (activePath != null) {
      if (includeCursorPoint && _currentP != null) {
        activePath..handleMouseMove(_currentP);
      }

      addPolygon(activePolygon..refreshSvg());
      activePath = null;
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
        var click = true;

        if (ev is MouseEvent && ev.button == 2 && activePolygon != null) {
          return instantiateActivePolygon();
        }

        if (createNew) {
          // Start new polygon
          var pole = !(ev as dynamic).shiftKey;

          _polyprev.classes.toggle('positive-pole', pole);

          activePath = brush.createNewPath()
            ..polygon = SvgPolygon(
              getPoleParent(pole),
              points: [_currentP],
              positive: pole,
            );

          moveStreamCtrl = StreamController();
          moveStreamCtrl.stream.listen((point) {
            // Polygon could have been cancelled by user
            if (activePath != null) {
              if (activePath.handleMouseMove(point)) {
                _drawPreview();
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

        var poly = activePolygon;
        if (createNew && !click && poly != null) {
          activePath = null;
          addPolygon(poly);
        }
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

  void addPolygon(SvgPolygon polygon) {
    var polyState = _polygons.toList(growable: false);
    _hidePreview();

    try {
      _addPolygon(polygon);
    } catch (e, stack) {
      if (debugOnError != null) {
        debugOnError(e, stack, canvasToData(polyState), polygon);
      }

      fromPolygons(polyState);
      if (debugOnError == null) rethrow;
    } finally {
      if (polygon == activePolygon) activePath = null;

      polygon.dispose();
    }
  }

  void _addPolygon(SvgPolygon polygon) {
    if (polygon.points.length >= 3 && activePath.isValid()) {
      if (polygon.positive) {
        var cropped = _cropPolygon(polygon);
        for (var poly in cropped) {
          _mergePolygon(poly);
        }
      } else {
        // No need to crop negative polygons
        _mergePolygon(polygon);
      }
    }
  }

  void _mergePolygon(Polygon polygon) {
    var pole = polygon.positive;
    var affected = <SvgPolygon>{};
    var nPolys = <Polygon>[];
    var removeMerge = false;
    var inside = false;

    void equalPole() {
      // Merge all equally polarized polygons
      for (var other in _polygons.where((p) => p.positive == pole)) {
        var united = union(polygon, other);
        if (united.length == 1) {
          var merge = united.first;
          if (merge != other) {
            affected.add(other);

            if (merge != polygon) {
              // There's one big shape now
              polygon = merge;
            }
          } else {
            removeMerge = true;
          }
        } else if (united.length == 2 && united.first == polygon) {
          // No overlapping
        } else {
          // Wow, cool new shape with holes and stuff
          affected.add(other);
          polygon = united.firstWhere((p) => p.positive);
          nPolys.addAll(united.where((p) => !p.positive));
        }
      }
    }

    void diffPole() {
      // Subtract big poly from other poles
      for (var other in _polygons.where((p) => p.positive != pole)) {
        var united = union(other, polygon);
        if (united.length == 1 && united.first.positive == pole) {
          // This opposite pole is now gone
          affected.add(other);
        } else if (united.length == 2 && united.any((p) => p == polygon)) {
          // No overlapping
          if (united.first == polygon) {
            // A contains B
            inside = true;
          }
        } else {
          // Opposite pole gets transformed, maybe split into multiple
          affected.add(other);
          removeMerge = !pole;
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
      removeMerge = true;
    }

    for (var aff in affected) {
      _polygons.remove(aff..dispose());
    }
    _polygons.addAll(
        nPolys.map((p) => SvgPolygon.copy(getPoleParent(p.positive), p)));

    if (!removeMerge) {
      _polygons.add(SvgPolygon.copy(getPoleParent(polygon.positive), polygon));
    }

    if (affected.isNotEmpty || nPolys.isNotEmpty || !removeMerge) {
      _triggerOnChange();
    }
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
    addPolygon(SvgPolygon.copy(getPoleParent(true), makeCropRect()));
  }
}
