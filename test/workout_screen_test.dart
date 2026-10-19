// A minimal fake Firestore doc for the screen; it never reaches Firestore.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:couple_fit/db.dart';
import 'package:couple_fit/theme.dart';
import 'package:couple_fit/workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Only data() is used while the workout is on screen (saving touches Firestore).
class _Doc implements QueryDocumentSnapshot<Json> {
  _Doc(this._d);
  final Json _d;
  final ref = _Ref();
  @override
  Json data() => _d;
  @override
  DocumentReference<Json> get reference => ref;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Records routine writes (the mid-workout auto-save).
class _Ref implements DocumentReference<Json> {
  final writes = <Json>[];
  @override
  Future<void> update(Map<Object, Object?> data) async => writes.add(data.cast<String, dynamic>());
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Let sheets / dialogs finish animating (the drawings loop forever, so no pumpAndSettle).
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  TestWidgetsFlutterBinding.ensureInitialized();
  AndroidFlutterLocalNotificationsPlugin.registerWith(); // tests run as Android
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('dexterous.com/flutter/local_notifications'),
    (call) async => call.method == 'initialize' ? true : null,
  );

  testWidgets('workout screen on a small phone: steppers, rest bubble + sheet, order list, rest buttons', (t) async {
    t.view.physicalSize = const Size(375 * 3, 667 * 3); // iPhone SE
    t.view.devicePixelRatio = 3;
    final doc = _Doc({
        'name': '상체 푸시',
        'exercises': [
          Exercise(name: '벤치프레스', sets: 4, reps: '10', weight: '102.5kg', restSec: 90).toMap(),
          Exercise(name: '러닝', sets: 1, reps: '30분', restSec: 0).toMap(),
        ],
      });
    final s = WorkoutSession(doc, null)..adjusting = true;
    await t.pumpWidget(MaterialApp(theme: appTheme(), home: Scaffold(body: WorkoutView(s: s, onDone: () {}))));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('다음 휴식'), findsOneWidget); // rest bubble next to 세트 완료
    expect(t.takeException(), isNull);

    // Bubble → sheet → 2:00 preset: the rest changes and is written into the routine.
    await t.ensureVisible(find.text('다음 휴식'));
    await t.pump();
    await t.tap(find.text('다음 휴식'));
    await settle(t);
    await t.tap(find.text('2:00').last);
    await t.pump(const Duration(seconds: 1));
    expect(s.t.current.restSec, 120);
    expect(((doc.ref.writes.last['exercises'] as List).first as Map)['restSec'], 120);
    await t.tap(find.text('완료').last);
    await settle(t);
    expect(t.takeException(), isNull);

    // Tap 러닝 in the order list → "지금 하기" makes it the current exercise.
    await t.scrollUntilVisible(find.text('러닝'), 200);
    await t.tap(find.text('러닝').last);
    await settle(t);
    await t.tap(find.text('지금 하기'));
    await settle(t);
    expect(s.t.current.name, '러닝');
    s.act(() => s.t.select(0));

    s.act(s.t.completeSet); // → resting
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('−15초'), findsOneWidget);
    expect(t.takeException(), isNull);
    s.end();
  });
}
