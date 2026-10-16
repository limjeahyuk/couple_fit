// Renders every exercise illustration (start / end pose) to PNGs for review:
//   ART_OUT=/some/dir flutter test tool/art_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:couple_fit/art.dart';
import 'package:couple_fit/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('render art', () async {
    final out = Platform.environment['ART_OUT'] ?? 'build/art';
    Directory(out).createSync(recursive: true);
    var i = 0;
    for (final MapEntry(key: name, value: art) in arts.entries) {
      for (final (f, t) in [(0, 0.0), (1, 1.0)]) {
        final rec = ui.PictureRecorder();
        final c = ui.Canvas(rec);
        c.drawRect(const ui.Rect.fromLTWH(0, 0, 240, 200), ui.Paint()..color = surf2);
        ArtPainter(art, t).paint(c, const ui.Size(240, 200));
        final img = await rec.endRecording().toImage(240, 200);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/${i.toString().padLeft(2, '0')}_$f.png').writeAsBytesSync(png!.buffer.asUint8List());
      }
      File('$out/${i.toString().padLeft(2, '0')}.txt').writeAsStringSync(name);
      i++;
    }
  });
}
