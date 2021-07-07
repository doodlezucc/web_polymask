import 'dart:html';
import 'dart:js_util';

import 'package:web_polymask/polygon_canvas.dart';

void main() {
  var canvas = PolygonCanvas(querySelector('svg'));

  window.onKeyDown.listen((ev) {
    if (ev.ctrlKey) {
      // Ctrl + S
      if (ev.keyCode == 83) {
        print(canvas.toData());
        return ev.preventDefault();
      }
      // Ctrl + V
      else if (ev.keyCode == 86) {
        var data = callMethod(window, 'prompt', [
          'Enter some base64-encoded polygon data',
        ]);
        canvas.fromData(data);
        return ev.preventDefault();
      }
    }
  });
}
