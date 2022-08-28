import 'dart:async';
import 'dart:html';
import 'dart:svg' as svg;

import 'package:web_polymask/math/polymath.dart';
import 'package:web_polymask/math/point_convert.dart';
import 'package:web_polymask/math/polygon.dart';
import 'package:web_polymask/polygon_canvas_data.dart';

import 'binary.dart';
import 'interactive/svg_polygon.dart';

class PolygonCanvas with CanvasLoader {
  final _polygons = <SvgPolygon>[];
  final svg.SvgSvgElement root;
  final svg.SvgElement polypos;
  final svg.SvgElement polyneg;
  final svg.SvgElement polyprev;
  void Function() onChange;
  void Function(dynamic error, StackTrace stackTrace, String previousData,
      Polygon polygon) debugOnError;
  bool Function(Event ev) acceptStartEvent;
  Point Function(Point p) modifyPoint;
  bool captureInput;
  SvgPolygon activePolygon;
  Point<int> currentP;
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
  })  : polypos = root.querySelector('#polypos'),
        polyneg = root.querySelector('#polyneg'),
        polyprev = root.querySelector('#polyprev') {
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

  @override
  String toData() => canvasToData(_polygons);

  static bool _isInput(Element e) => e is InputElement || e is TextAreaElement;

  void instantiateActivePolygon({bool includeCursorPoint = true}) {
    if (activePolygon != null) {
      if (currentP != null) activePolygon..addPoint(currentP);

      addPolygon(activePolygon..refreshSvg());
      activePolygon = null;
    }
  }

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

  void _hidePreview() => polyprev.setAttribute('points', '');

  void _drawPreview([Point<int> extra]) {
    polyprev.setAttribute('points', activePolygon.el.getAttribute('points'));
    polyprev.classes.toggle('poly-invalid', !activePolygon.isSimple(extra));
  }

  Element getPoleParent(bool positive) => positive ? polypos : polyneg;

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

        currentP = fixedPoint(ev);
        var createNew = activePolygon == null;
        var click = true;

        if (ev is MouseEvent && ev.button == 2 && activePolygon != null) {
          return instantiateActivePolygon();
        }

        if (createNew) {
          // Start new polygon
          var pole = !(ev as dynamic).shiftKey;

          polyprev.classes.toggle('positive-pole', pole);

          activePolygon = SvgPolygon(
            getPoleParent(pole),
            points: [currentP],
            positive: pole,
          );
          moveStreamCtrl = StreamController();
          moveStreamCtrl.stream.listen((point) {
            // Polygon could have been cancelled by user
            if (activePolygon != null) {
              activePolygon.addPoint(point);
              _drawPreview();
              click = false;
            }
          });
        } else {
          // Add single point to active polygon
          activePolygon.addPoint(currentP);
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
          currentP = fixedPoint(ev);
          activePolygon.refreshSvg(currentP);
          _drawPreview(currentP);
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
    var previousData = debugOnError != null ? toData() : null;
    _hidePreview();

    try {
      if (polygon.points.length >= 3 && polygon.isSimple()) {
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
    } catch (e, stack) {
      if (debugOnError != null) debugOnError(e, stack, previousData, polygon);
      rethrow;
    } finally {
      polygon.dispose();
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
