import 'dart:async';
import 'dart:html';
import 'dart:svg' as svg;

import 'package:web_polymask/math/polygon_state.dart';

import 'binary.dart';
import 'brushes/brush.dart';
import 'interactive/svg_polygon.dart';
import 'math/point_convert.dart';
import 'math/polygon.dart';
import 'math/polymath.dart';
import 'polygon_canvas_data.dart';

class PolygonCanvas with CanvasLoader {
  PolygonState state = PolygonState({});
  PolygonMerger _merger;
  final _svg = <Polygon, SvgPolygon>{};
  final svg.SvgSvgElement root;
  final svg.SvgElement _polyprev;
  final _layersPos = <List<svg.SvgElement>>[];
  final _layersNeg = <List<svg.SvgElement>>[];

  void Function() onChange;
  PolygonBrush brush = PolygonBrush.stroke;

  bool Function(Event ev) acceptStartEvent;
  Point Function(Point p) modifyPoint;
  bool captureInput;
  BrushPath activePath;
  SvgPolygon activePolygon;
  Point<int> _currentP;
  int cropMargin;

  bool get isEmpty => state.parents.isEmpty;
  bool get isNotEmpty => !isEmpty;

  PolygonCanvas(
    this.root, {
    this.captureInput = true,
    this.onChange,
    this.acceptStartEvent,
    this.modifyPoint,
    this.cropMargin = 2,
  }) : _polyprev = root.querySelector('#polyprev') {
    _merger = PolygonMerger(
      onAdd: _onAdd,
      onRemove: _onRemove,
      onUpdateParent: _onUpdateParent,
    );
    _layersPos.add(root.querySelectorAll('[polycopy=p]'));
    _layersNeg.add(root.querySelectorAll('[polycopy=n]'));
    _initKeyListener();
    _initCursorControls();
  }

  void _onAdd(Polygon p, Polygon parent) {
    print('add $p to $parent');
    _makeSvgPoly(p);
  }

  void _onRemove(Polygon p) {
    print('remove $p');
    _svg.remove(p).dispose();
  }

  void _onUpdateParent(Polygon p, Polygon parent) {
    print('reappend $p to $parent');
    _svg[p].setParent(_getPoleParent(p.positive, _findZ(p)));
  }

  List<svg.SvgElement> _createLayer(List<svg.SvgElement> tmp, int z) {
    final withAttr = 'polyattr';
    final regId = RegExp(r'#\w+');

    return tmp.map((e) {
      final deep = e.hasAttribute('polydeep');
      final svg.SvgElement copy = e.clone(deep);
      final elems = [copy, ...copy.querySelectorAll('*')];

      // Append `z` to element id and selectors
      for (var elem in elems) {
        final id = elem.id;
        if (id != null && id.isNotEmpty) {
          elem.id = '$id$z';
        }

        final attr = elem.attributes[withAttr];
        if (attr != null) {
          final srcV = elem.attributes[attr];
          final idEnd = regId.firstMatch(srcV).end;
          elem.attributes[attr] =
              srcV.substring(0, idEnd) + '$z' + srcV.substring(idEnd);
        }
      }

      final index = e.parent.children.indexOf(e);
      e.parent.children.insert(index + z, copy);
      return copy;
    }).toList();
  }

  void clear({bool triggerChangeEvent = true}) {
    _svg.forEach((k, svg) => svg.dispose());
    _svg.clear();
    state.parents.clear();
    if (triggerChangeEvent) _triggerOnChange();
  }

  @override
  void fromData(String base64) {
    clear(triggerChangeEvent: false);
    final polygons = canvasFromData(base64);
    state = PolygonState.assignParents(polygons);
    _svg.addAll(
        state.parents.map((key, value) => MapEntry(value, _makeSvgPoly(key))));
  }

  void _fromPolygons(Iterable<SvgPolygon> polygons) {
    clear(triggerChangeEvent: false);
    for (var src in polygons) {
      _makeSvgPoly(src.polygon.copy());
    }
  }

  @override
  String toData() => canvasToData(state.parents.keys);

  static bool _isInput(Element e) => e is InputElement || e is TextAreaElement;

  void instantiateActivePolygon({bool includeCursorPoint = true}) {
    if (activePath != null) {
      if (includeCursorPoint && _currentP != null) {
        activePath..handleMouseMove(_currentP);
      }

      try {
        activePolygon.refreshSvg();
        addPolygon(activePolygon.polygon);
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
    _polyprev.setAttribute('points', activePolygon.currentSvgData);
    _polyprev.classes.toggle('poly-invalid', !activePath.isValid(extra));
  }

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
          activePolygon = _makeSvgPoly(Polygon(
            points: activePath.points,
            positive: pole,
          ));
          _drawPreview();

          if (!activePath.brush.employClickEvent) {
            addPolygon(activePolygon.polygon.copy());
          }

          moveStreamCtrl = StreamController();
          moveStreamCtrl.stream.listen((point) {
            // Polygon could have been cancelled by user
            if (activePath != null) {
              if (activePath.handleMouseMove(point)) {
                activePolygon.refreshSvg();
                _drawPreview();
                if (!activePath.brush.employClickEvent) {
                  addPolygon(activePolygon.polygon.copy());
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
          addPolygon(activePolygon.polygon.copy());
        }
        activePath = null;
        activePolygon.dispose();
        activePolygon = null;
        _hidePreview();
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

  void addPolygon(Polygon polygon) {
    final polyState = _svg.values.toList();
    print('State: ${state}');
    print('Add ${polygon}');

    try {
      _addPolygon(polygon);
    } catch (e) {
      _fromPolygons(polyState);
      rethrow;
    }
  }

  void _addPolygon(Polygon polygon) {
    if (polygon.points.length >= 3) {
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

  Element _getPoleParent(bool positive, int z) {
    final list = positive ? _layersPos : _layersNeg;

    if (z >= list.length) {
      list.add(_createLayer(list[0], z));
    }

    return list[z][0];
  }

  int _findZ(Polygon p) {
    int z = 0;
    Polygon parent = state.parents[p];
    while (parent != null) {
      if (!parent.positive) {
        z++;
      }
      parent = state.parents[parent];
    }

    return z;
  }

  SvgPolygon _makeSvgPoly(Polygon src) {
    final z = _findZ(src);
    final poly = SvgPolygon(_getPoleParent(src.positive, z), src);
    _svg[src] = poly;
    return poly;
  }

  void _mergePolygon(Polygon polygon) {
    _merger.mergePolygon(state, polygon);
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
    addPolygon(makeCropRect());
  }
}
