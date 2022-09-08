import 'package:web_polymask/binary.dart';
import 'package:web_polymask/math/polygon.dart';

class PolygonCanvasData with CanvasLoader {
  final Set<Polygon> polygons = {};

  @override
  void fromData(String base64) {
    polygons.clear();
    polygons.addAll(canvasFromData(base64));
  }

  @override
  String toData() => canvasToData(polygons);
}

mixin CanvasLoader {
  void fromData(String base64);
  String toData();
}
