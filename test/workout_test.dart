import 'package:couple_fit/db.dart';
import 'package:couple_fit/demo.dart';
import 'package:couple_fit/workout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sets advance, rest counts down / extends / skips, ends after last set', () {
    var now = DateTime(2026, 10, 13, 9);
    void wait(int s) => now = now.add(Duration(seconds: s));
    final t = WorkoutTracker([
      Exercise(name: 'squat', sets: 2, restSec: 90),
      Exercise(name: 'plank', sets: 1, restSec: 30),
    ], now: () => now);

    wait(40);
    t.completeSet(); // squat 1/2
    expect((t.resting, t.setIdx, t.restTarget), (true, 1, 90));
    wait(20);
    t.addRest(15);
    expect(t.restLeft, 85);
    expect(t.restEnd, DateTime(2026, 10, 13, 9, 0, 40 + 105)); // lock-screen countdown target
    t.completeSet(); // ignored while resting
    expect(t.doneSets, 1);
    wait(30);
    t.endRest(); // skipped after 50s

    wait(40);
    t.completeSet(); // squat 2/2 -> plank, rest uses squat's 90s
    expect((t.current.name, t.restTarget, t.resting), ('plank', 90, true));
    wait(95);
    expect(t.tick(), true); // auto-ends, counts the planned 90s
    expect((t.tick(), t.resting), (false, false));

    wait(30);
    t.completeSet(); // plank 1/1 -> done, no rest
    expect((t.finished, t.complete, t.doneSets, t.totalSets), (true, true, 3, 3));
    wait(100); // time stops once finished
    expect((t.elapsedSec, t.restSec), (255, 140));
  });

  test('finishNow keeps partial progress', () {
    var now = DateTime(2026, 10, 13, 9);
    final t = WorkoutTracker([Exercise(sets: 3, restSec: 60)], now: () => now);
    t.completeSet();
    now = now.add(const Duration(seconds: 20));
    t.finishNow();
    expect((t.finished, t.complete, t.doneSets, t.restSec), (true, false, 1, 20));
  });

  test('set log keeps reps/weight as edited mid-workout', () {
    var now = DateTime(2026, 10, 13, 9);
    final t = WorkoutTracker([Exercise(name: 'bench', sets: 3, reps: '10', weight: '40kg', restSec: 0)], now: () => now);
    t.completeSet();
    t.tick();
    t.current
      ..weight = '45kg'
      ..reps = '8';
    t.completeSet();
    t.tick();
    t.completeSet();
    expect(t.log.map((e) => '${e['weight']}x${e['reps']}'), ['40kgx10', '45kgx8', '45kgx8']);
    expect(logLines(t.log), ['bench · 40kg × 10, 45kg × 8, 45kg × 8']);
    expect(logLines([
      {'ex': 'squat', 'reps': '8', 'weight': '60kg'},
      {'ex': 'squat', 'reps': '6', 'weight': '60kg'},
      {'ex': 'plank', 'reps': '40초', 'weight': ''},
    ]), ['squat · 60kg × 8·6', 'plank · 40초']);
    expect(logLines(null), isEmpty);
  });

  test('arrow steps for reps and weight', () {
    expect([stepReps('10', 1), stepReps('10', -1), stepReps('1', -1)], ['11', '9', '1']);
    expect([stepReps('40초', 1), stepReps('5초', -1)], ['45초', '5초']);
    expect([stepWeight('40kg', 1), stepWeight('40kg', -1), stepWeight('20kg', -1), stepWeight('22.5kg', -1)],
        ['42.5kg', '37.5kg', '19kg', '20kg']);
    expect([stepWeight('6kg', 1), stepWeight('19kg', 1), stepWeight('1kg', -1)], ['7kg', '20kg', '맨몸']);
    expect([stepWeight('맨몸', 1), stepWeight('맨몸', -1), stepWeight('', 1)], ['1kg', '맨몸', '1kg']);
  });

  test('body metrics derive fat mass and BMI; deltas round to 0.1', () {
    final b = {'weight': 72.0, 'height': 175, 'fat': 18.5, 'muscle': 33.1};
    String show(String label) => fmt1(bodyMetrics.firstWhere((m) => m.label == label).of(b)!);
    expect([show('체중'), show('체지방률'), show('골격근량'), show('체지방량'), show('BMI')], ['72', '18.5', '33.1', '13.3', '23.5']);
    expect(bodyMetrics.firstWhere((m) => m.label == '골격근량').of({'weight': 70}), isNull); // optional
    expect(bodyMetrics.firstWhere((m) => m.label == 'BMI').of({'weight': 70}), isNull); // no height
    expect([delta(72.4, 72.0), delta(71.0, 72.2), delta(72.04, 72.0), delta(72, null)], ['▲0.4', '▼1.2', '-', '']);
  });

  test('demo data is shaped like the real thing', () {
    final ses = demoSessions(), body = demoPartnerBody();
    expect(ses.map((x) => x['date']).toList(), [...ses.map((x) => x['date'])]..sort((a, b) => '$b'.compareTo('$a')));
    expect(ses.every((x) => (x['log'] as List).length == x['sets']), isTrue);
    expect(body.map((b) => b['date']).toList(), [...body.map((b) => b['date'])]..sort());
    expect((body.first['weight'], body.last['weight']), (55.2, 53.8));
  });

  test('signed change labels', () {
    expect([signed(0.46), signed(-1.2), signed(0.04), signed(-0.04), signed(2)], ['+0.5', '−1.2', '0', '0', '+2']);
  });
}
