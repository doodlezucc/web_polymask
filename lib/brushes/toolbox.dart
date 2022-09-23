import 'lasso.dart';
import 'stroke.dart';
import 'tool.dart';

mixin PolygonToolbox {
  final toolBrushStroke = StrokeBrush();
  final toolBrushLasso = LassoBrush();

  Map<String, PolygonTool> _toolMap;
  Map<String, PolygonTool> get toolMap =>
      _toolMap ??
      {
        toolBrushStroke.id: toolBrushStroke,
        toolBrushLasso.id: toolBrushLasso,
      };

  PolygonTool _activeTool;
  PolygonTool get activeTool => _activeTool ??= toolBrushStroke;
  set activeTool(PolygonTool tool) {
    _activeTool = tool;
  }
}
