// Renders the workout screen (set card + rest bubble) to a PNG for a visual check (macOS fonts):
//   flutter test tool/workout_preview_test.dart --update-goldens   → tool/workout_preview.png
// ignore_for_file: subtype_of_sealed_class
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:couple_fit/db.dart';
import 'package:couple_fit/theme.dart';
import 'package:couple_fit/workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _Doc implements QueryDocumentSnapshot<Json> {
  _Doc(this._d);
  final Json _d;
  @override
  Json data() => _d;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _font(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  await (FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  TestWidgetsFlutterBinding.ensureInitialized();
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('dexterous.com/flutter/local_notifications'),
    (call) async => call.method == 'initialize' ? true : null,
  );

  testWidgets('workout preview', (t) async {
    // Real glyphs instead of test boxes (macOS system Korean font for everything).
    const kr = '/System/Library/Fonts/Supplemental/AppleGothic.ttf';
    const weights = ['regular', '100', '200', '300', '400', '500', '600', '700', '800', '900'];
    for (final f in [
      'FlutterTest',
      'Roboto',
      for (final w in weights) ...['SpaceGrotesk_$w', 'IBMPlexSansKR_$w'],
    ]) {
      await t.runAsync(() => _font(f, kr));
    }
    await t.runAsync(
      () => _font('MaterialIcons', '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'),
    );
    t.view.physicalSize = const Size(390 * 2, 844 * 2);
    t.view.devicePixelRatio = 2;
    final s = WorkoutSession(
      _Doc({
        'name': '하체 데이',
        'exercises': [
          Exercise(name: '바벨 스쿼트', sets: 4, reps: '8', weight: '60kg', restSec: 120).toMap(),
          Exercise(name: '레그 프레스', sets: 3, reps: '12', weight: '100kg', restSec: 90).toMap(),
        ],
      }),
      null,
    )..adjusting = true;
    s.t.done[0] = 1;
    await t.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: Scaffold(body: WorkoutView(s: s, onDone: () {})),
    ));
    await t.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('workout_preview.png'));
    s.end();
  });
}
