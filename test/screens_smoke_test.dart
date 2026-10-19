import 'package:couple_fit/calendar.dart';
import 'package:couple_fit/db.dart';
import 'package:couple_fit/demo.dart';
import 'package:couple_fit/home.dart';
import 'package:couple_fit/records.dart';
import 'package:couple_fit/exercises.dart';
import 'package:couple_fit/routines.dart';
import 'package:couple_fit/setup.dart';
import 'package:couple_fit/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fakes.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final today = todayKey();
  final s = {'date': today, 'routine': '상체 푸시', 'totalSec': 2710, 'restSec': 600, 'sets': 16, 'log': [
    for (final w in ['40kg', '40kg', '45kg', '45kg']) {'ex': '인클라인 덤벨 프레스', 'reps': '10', 'weight': w},
    {'ex': '플랭크', 'reps': '40초', 'weight': ''},
  ]};
  final data = [
    AppData(me: {'name': '혁'}),
    AppData(me: {'name': '혁', 'nudgeAt': today}, partner: {'name': '소연', 'uid': 'p', 'nudgeAt': today},
        mySessions: [s], paSessions: [{...s, 'routine': '하체 데이'}],
        myBody: [
          {'date': '2026-09-01', 'height': 175, 'weight': 74.2, 'fat': 21.0, 'muscle': 32.0},
          {'date': today, 'height': 175, 'weight': 72.5, 'fat': 19.4, 'muscle': 32.6},
        ],
        paBody: [{'date': '2026-09-20', 'height': 162, 'weight': 54.1, 'fat': 26.2}]),
    AppData(me: {'name': '혁'}, partner: {'name': '소연', 'uid': 'p', 'nudgeAt': today}, paSessions: [s]),
    // Demo couple: weeks of sessions with set logs, five body measurements each.
    AppData(me: {'name': '혁'}, partner: demoPartnerDoc('me'), mySessions: [s], paSessions: demoSessions(),
        myBody: demoMyBody(), paBody: demoPartnerBody()),
  ];
  for (final d in data) {
    for (final (name, page) in [
      ('home', HomePage(data: d, go: (_) {})),
      ('calendar', CalendarPage(data: d)),
      ('records', RecordsPage(data: d)),
    ]) {
      testWidgets('$name renders without overflow (${d.partner == null ? 'solo' : 'couple'})', (t) async {
        t.view.physicalSize = const Size(390 * 3, 844 * 3);
        t.view.devicePixelRatio = 3;
        await t.pumpWidget(MaterialApp(theme: appTheme(), home: Scaffold(body: page)));
        await t.pump();
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('exercise picker: every body part renders, picks come back with weights', (t) async {
    t.view.physicalSize = const Size(375 * 3, 812 * 3);
    t.view.devicePixelRatio = 3;
    List<Object?>? got;
    await t.pumpWidget(MaterialApp(
      theme: appTheme(),
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () async => got = await showModalBottomSheet(
            context: c,
            isScrollControlled: true,
            builder: (_) => ExercisePicker(person: const {'gender': 'm', 'uid': 'p'}, body: const [{'weight': 72.5}]),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100)); // drawings loop forever, so no pumpAndSettle
    }
    for (final c in catalog.keys) {
      await t.tap(find.text(c).first);
      await t.pump();
      expect(t.takeException(), isNull, reason: c);
    }
    await t.tap(find.text('가슴').first);
    await t.pump();
    await t.tap(find.text('벤치프레스'));
    await t.pump();
    await t.tap(find.text('1개 추가'));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100)); // drawings loop forever, so no pumpAndSettle
    }
    expect(got!.map((e) => (e as dynamic).weight), ['42.5kg']);
  });

  testWidgets('first-run setup renders and asks for gender first', (t) async {
    t.view.physicalSize = const Size(375 * 3, 812 * 3);
    t.view.devicePixelRatio = 3;
    await t.pumpWidget(MaterialApp(theme: appTheme(), home: const ProfileSetup(last: {'height': 175, 'weight': 72.5})));
    expect(find.text('72.5'), findsOneWidget); // prefilled from the latest body record
    await t.tap(find.text('시작하기'));
    await t.pump();
    expect(find.text('성별을 골라주세요'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('calendar: one line per workout, tap opens the set-by-set record', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    await t.pumpWidget(MaterialApp(theme: appTheme(), home: Scaffold(body: CalendarPage(data: data[1]))));
    await t.pump();
    expect(find.text('인클라인 덤벨 프레스'), findsNothing); // details stay out of the calendar
    await t.ensureVisible(find.text('상체 푸시 · 45분'));
    await t.tap(find.text('상체 푸시 · 45분'));
    await t.pumpAndSettle();
    expect(find.text('인클라인 덤벨 프레스'), findsOneWidget);
    expect(find.text('40kg × 10, 40kg × 10, 45kg × 10, 45kg × 10'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('record ≠ routine: overwrite shown, writes the logged sets; same → hidden', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    final sets = [for (final w in ['40kg', '40kg', '45kg', '45kg']) Exercise(name: '인클라인 덤벨 프레스', sets: 1, reps: '10', weight: w)];
    final changed = FakeDoc({'name': '상체 푸시', 'exercises': [sets.first.toMap()]});
    Future<void> open(FakeDoc r) async {
      final d = AppData(me: {'name': '혁'}, mySessions: [s], routines: [r]);
      await t.pumpWidget(MaterialApp(theme: appTheme(), home: Scaffold(body: CalendarPage(data: d))));
      await t.pump();
      await t.ensureVisible(find.text('상체 푸시 · 45분'));
      await t.tap(find.text('상체 푸시 · 45분'));
      await t.pumpAndSettle();
    }

    await open(changed);
    await t.drag(find.text('인클라인 덤벨 프레스').first, const Offset(0, -400));
    await t.pumpAndSettle();
    await t.tap(find.text('상체 푸시 루틴 덮어쓰기'));
    await t.pumpAndSettle();
    await t.tap(find.text('덮어쓰기'));
    await t.pumpAndSettle();
    final written = (changed.ref.writes.single['exercises'] as List).cast<Map<String, dynamic>>();
    expect(Exercise.fromMap(written.first).label, '40kg×10 · 40kg×10 · 45kg×10 · 45kg×10');
    expect(find.text('루틴을 이 기록대로 바꿨어요'), findsOneWidget);

    // Routine already matches the record: no button.
    await open(FakeDoc({'name': '상체 푸시', 'exercises': written}, id: 'r2'));
    expect(find.text('상체 푸시 루틴 덮어쓰기'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
