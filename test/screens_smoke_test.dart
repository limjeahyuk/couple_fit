import 'package:couple_fit/calendar.dart';
import 'package:couple_fit/db.dart';
import 'package:couple_fit/demo.dart';
import 'package:couple_fit/home.dart';
import 'package:couple_fit/records.dart';
import 'package:couple_fit/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

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
}
