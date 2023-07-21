import 'lasso.dart';
import 'stroke.dart';
import 'tool.dart';

mixin PolygonToolbox {
  final toolBrushStroke = StrokeBrush();
  final toolBrushLasso = LassoBrush();

  Map<String, PolygonTool>? _toolMap;
  Map<String, PolygonTool> get toolMap => _toolMap ??= {
        toolBrushStroke.id: toolBrushStroke,
        toolBrushLasso.id: toolBrushLasso,
      };

  PolygonTool? _activeTool;
  PolygonTool get activeTool => _activeTool ??= toolBrushStroke;
  set activeTool(PolygonTool tool) {
    _activeTool = tool;
  }

  Map<String, dynamic> settingsToJson() => {
        'active': activeTool.id,
        ...Map.fromEntries(toolMap.entries
            .map((e) => MapEntry(e.key, e.value.toJson()))
            .where((e) => e.value.isNotEmpty)),
      };

  void settingsFromJson(Map<String, dynamic> json) {
    activeTool = toolMap[json['active']] ?? activeTool;
    for (var e in toolMap.entries) {
      final toolJ = json[e.key];
      if (toolJ != null) {
        e.value.fromJson(toolJ);
      }
    }
  }
}
