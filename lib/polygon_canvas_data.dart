import 'package:web_polymask/binary.dart';
import 'package:web_polymask/math/polygon.dart';

class PolygonCanvasData with CanvasLoader {
  final List<Polygon> polygons = [];

  @override
  void fromData(String base64) {
    polygons.clear();
    canvasFromData(
      base64,
      (positive, points) => polygons.add(Polygon(
        positive: positive,
        points: points,
      )),
    );
  }

  @override
  String toData() => canvasToData(polygons);
}

mixin CanvasLoader {
  void fromData(String base64);
  String toData();
}
