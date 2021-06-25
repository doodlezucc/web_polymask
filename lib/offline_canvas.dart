import 'package:web_polymask/polygon.dart';

class OfflinePolygonCanvas {
  final List<Polygon> _polygons = [];
  Iterable<Polygon> get polygons => _polygons;

  void addPolygon(Polygon polygon) {
    _polygons.add(polygon);
  }
}
