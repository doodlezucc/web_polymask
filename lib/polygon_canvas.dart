import 'dart:async';
import 'dart:html';
import 'dart:svg' as svg;

import 'package:grid/grid.dart';
import 'package:web_polymask/math/rasterize.dart';

import 'binary.dart';
import 'brushes/tool.dart';
import 'brushes/toolbox.dart';
import 'interactive/svg_polygon.dart';
import 'math/point_convert.dart';
import 'math/polygon.dart';
import 'math/polygon_state.dart';
import 'math/polymath.dart';
import 'polygon_canvas_data.dart';

class PolygonCanvas with CanvasLoader, PolygonToolbox {
  Grid grid = Grid.unclamped();
  PolygonState state = PolygonState({});
  PolygonMerger _merger;
  final _svg = <Polygon, SvgPolygon>{};
  final svg.SvgSvgElement root;
  final svg.SvgElement _polyprev;
  final _layersPos = <List<svg.SvgElement>>[];
  final _layersNeg = <List<svg.SvgElement>>[];

  @override
  set activeTool(PolygonTool tool) {
    if (activePath != null) return;
    super.activeTool = tool;

    if (onSettingsChange != null) onSettingsChange();
  }

  bool _captureInput;
  bool get captureInput => _captureInput;
  set captureInput(bool captureInput) {
    _captureInput = captureInput;
    if (!captureInput) {
      if (activePath != null) {
        _cancelActivePath();
      }
      _drawOutline([]);
    } else {
      _drawActiveBrushCursor();
    }
  }

  void Function() onChange;
  void Function() onSettingsChange;
  bool Function(Event ev) acceptStartEvent;
  Point Function(Point p) modifyPoint;
  ToolPath activePath;
  Point<int> _currentP;
  int cropMargin;
  bool _previewPositive = true;
  List<SvgPolygon> _activePreview = [];
  int _maxZ = 0;

  bool get isEmpty => state.parents.isEmpty;
  bool get isNotEmpty => !isEmpty;

  PolygonCanvas(
    this.root, {
    bool captureInput = true,
    this.onChange,
    this.onSettingsChange,
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
    this.captureInput = captureInput;
  }

  void _onAdd(Polygon p, Polygon parent) {
    // print('add $p to $parent');
    _makeSvgPoly(p);
  }

  void _onRemove(Polygon p) {
    // print('remove $p');
    _svg.remove(p).dispose();
  }

  void _onUpdateParent(Polygon p, Polygon parent) {
    // print('reappend $p to $parent');
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

  void _fromPolygons(Iterable<SvgPolygon> polygons) {
    clear(triggerChangeEvent: false);
    for (var src in polygons) {
      _makeSvgPoly(src.polygon.copy());
    }
  }

  @override
  void fromData(String base64) {
    clear(triggerChangeEvent: false);
    final polygons = canvasFromData(base64);
    state = PolygonState.assignParents(polygons);
    _svg.addAll(
        state.parents.map((key, value) => MapEntry(key, _makeSvgPoly(key))));
  }

  @override
  String toData() => canvasToData(state.parents.keys);

  static bool _isInput(Element e) => e is InputElement || e is TextAreaElement;

  void _setPrevPole(bool positive) {
    if (positive != _previewPositive) {
      _previewPositive = positive;
      if (activePath == null) {
        _drawActiveBrushCursor();
      }
    }
  }

  void instantiateActivePolygon({bool includeCursorPoint = true}) {
    if (activePath != null) {
      if (includeCursorPoint && _currentP != null) {
        if (activePath.maker.isClicked) {
          activePath.handleMouseClick(_currentP);
        } else {
          activePath.handleMouseMove(_currentP);
        }
      }

      _sendPathEnd();
    }
  }

  void _cancelActivePath() {
    _drawActiveBrushCursor();
    activePath = null;
  }

  void _sendPathEnd() {
    if (!activePath.isValid()) {
      return _cancelActivePath();
    }
    activePath.handleEnd(_currentP);
    _drawActiveBrushCursor();
    activePath = null;
  }

  void _drawActiveBrushCursor() {
    if (_currentP == null) return;
    _drawOutline((activePath?.tool ?? activeTool).drawCursor(_currentP));
  }

  void _initKeyListener() {
    window.onKeyDown.listen((ev) {
      if (captureInput && !_isInput(ev.target)) {
        switch (ev.keyCode) {
          case 16: // Shift
            _setPrevPole(false);
            return;

          case 24: // Delete
          case 8: // Backspace
          case 27: // Escape
            if (activePath != null) {
              _cancelActivePath();
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
    window.onKeyUp.listen((ev) {
      if (captureInput && ev.keyCode == 16) _setPrevPole(true);
    });
  }

  List<SvgPolygon> _updateRasteredPreview(Iterable<Point<int>> outline) {
    for (var active in _activePreview) {
      active.dispose();
    }

    final pole = _previewPositive;
    int z = _maxZ;
    if (pole) z++;

    final islands = rasterize(Polygon(points: outline, positive: pole), grid);
    return _activePreview =
        islands.map((i) => SvgPolygon(_getPoleParent(pole, z), i)).toList();
  }

  void _drawOutline(Iterable<Point<int>> points, [Point<int> extra]) {
    final pointsPlus = [...points, if (extra != null) extra];
    _polyprev.setAttribute(
      'points',
      pointsToSvg(pointsPlus),
    );
    _polyprev.classes.toggle(
      'poly-invalid',
      activePath != null && !activePath.isValid(extra),
    );
    _updateRasteredPreview(pointsPlus);
  }

  void updatePreview() {
    if (activePath == null) {
      _drawOutline(activeTool.drawCursor(_currentP));
    }
  }

  void _initCursorControls() {
    window.onMouseWheel.listen((ev) {
      if (activePath != null) return;

      if (activeTool.handleMouseWheel(ev.deltaY.sign)) {
        updatePreview();
        if (onSettingsChange != null) onSettingsChange();
      }
    });

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
        var createNew = activePath == null;
        var click = activeTool.employClickEvent;
        var clickedOnce = false;

        if (ev is MouseEvent && ev.button == 2 && activePath != null) {
          return instantiateActivePolygon();
        }

        if (createNew) {
          // Start new polygon
          var pole = !(ev as dynamic).shiftKey;
          _setPrevPole(pole);

          Polygon activePolygon;
          final maker = PolyMaker(
            (points) => activePolygon = Polygon(points: points, positive: pole),
            () => addPolygon(activePolygon),
            (points) => _drawOutline(
              points,
              activePath.maker.isClicked ? _currentP : null,
            ),
          );
          maker.isClicked = click;

          activePath = activeTool.createNewPath(maker);
          activePath.handleStart(_currentP);

          moveStreamCtrl = StreamController();
          moveStreamCtrl.stream.listen((point) async {
            // Polygon could have been cancelled by user
            if (activePath != null) {
              if (!clickedOnce) {
                click = false;
                maker.isClicked = false;
              }
              activePath.handleMouseMove(point);
            } else {
              await moveStreamCtrl.close();
              moveStreamCtrl = null;
            }
          });
        } else {
          // Add single point to active polygon
          activePath.handleMouseClick(_currentP);
        }

        await endEvent.first;
        clickedOnce = true;
        if (!click && moveStreamCtrl != null) {
          await moveStreamCtrl.close();
          moveStreamCtrl = null;
        }

        if (activePath != null && (!activeTool.employClickEvent || !click)) {
          _sendPathEnd();
        }
      });

      moveEvent.listen((ev) {
        if (captureInput) {
          _currentP = fixedPoint(ev);
          if (moveStreamCtrl != null) {
            moveStreamCtrl.add(_currentP);
          } else {
            _drawOutline(
                (activePath?.tool ?? activeTool).drawCursor(_currentP));
          }
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
    // print('State: ${state}');

    try {
      final rasterized = rasterize(polygon, grid);
      for (var poly in rasterized) {
        _addPolygon(poly);
      }
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
          // print('Add ${poly}');
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
    if (z > _maxZ) _maxZ = z;

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
    return intersection(polygon, makeCropRect()).output;
  }

  void fillCanvas() {
    addPolygon(makeCropRect());
  }
}
