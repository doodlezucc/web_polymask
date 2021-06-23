import 'dart:svg';

import 'package:web_polygons/offline_canvas.dart';
import 'package:web_polygons/polygon.dart';

class PolygonCanvas extends OfflinePolygonCanvas {
  final SvgSvgElement root;
  bool captureEvents;

  Polygon activePolygon;

  PolygonCanvas(this.root, {this.captureEvents = true}) {
    _initMouseListeners();
  }

  void _initMouseListeners() {
    root.onClick.listen((ev) {
      if (captureEvents) {
        if (activePolygon != null) {
          //
        }
      }
    });
  }
}
