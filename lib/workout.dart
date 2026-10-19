import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'art.dart';
import 'db.dart';
import 'push.dart';
import 'theme.dart';

/// Pure workout state. Wall-clock based so it stays correct while the app is backgrounded.
class WorkoutTracker {
  WorkoutTracker(this.exercises, {DateTime Function()? now}) : _now = now ?? DateTime.now {
    start = _now();
  }

  final List<Exercise> exercises;
  final DateTime Function() _now;
  late final DateTime start;
  DateTime? _end, _restStart;
  int ex = 0, restTarget = 0; // ex = the exercise being done now (any order)
  Duration _restTotal = Duration.zero;

  /// Sets finished per exercise.
  late final List<int> done = List.filled(exercises.length, 0);

  /// What was actually done, one entry per completed set (reps/weight as they were at that moment).
  final log = <Json>[];

  bool get finished => _end != null;
  bool get resting => _restStart != null;
  Exercise get current => exercises[ex];
  int get totalSets => exercises.fold(0, (a, e) => a + e.sets);
  int get setIdx => done[ex]; // sets done in the current exercise = index of the next one
  int get doneSets => done.fold(0, (a, n) => a + n);
  bool isDone(int i) => done[i] >= exercises[i].sets;
  bool get complete => [for (var i = 0; i < exercises.length; i++) isDone(i)].every((d) => d);
  int get elapsedSec => (_end ?? _now()).difference(start).inSeconds;

  /// Saved workout time: the clock, or the logged cardio minutes if more
  /// (a run done first and ticked off afterwards still counts its 30 minutes).
  int get totalSec {
    final cardio = log.fold(0, (a, e) {
      final m = RegExp(r'^(\d+)분$').firstMatch('${e['reps']}');
      return a + (m == null ? 0 : int.parse(m[1]!));
    });
    return elapsedSec > cardio * 60 ? elapsedSec : cardio * 60;
  }

  int get restLeft => resting ? restTarget - _now().difference(_restStart!).inSeconds : 0;
  int get restSec => (_restTotal + (resting ? _now().difference(_restStart!) : Duration.zero)).inSeconds;
  DateTime? get restEnd => resting ? _restStart!.add(Duration(seconds: restTarget)) : null;

  /// State before each completed set (or early finish), so mistakes can be undone one at a time.
  final _undo =
      <
        ({int ex, List<int> done, int restTarget, DateTime? restStart, Duration restTotal, DateTime? end, bool logged})
      >[];
  void _snap(bool logged) => _undo.add((
    ex: ex,
    done: [...done],
    restTarget: restTarget,
    restStart: _restStart,
    restTotal: _restTotal,
    end: _end,
    logged: logged,
  ));
  bool get canUndo => _undo.isNotEmpty;

  /// Back to just before the last completed set (its log entry and the rest after it are dropped),
  /// or un-finish an early "여기까지 저장". The overall clock keeps running.
  void undo() {
    if (_undo.isEmpty) return;
    final u = _undo.removeLast();
    ex = u.ex;
    done.setAll(0, u.done);
    restTarget = u.restTarget;
    _restStart = u.restStart;
    _restTotal = u.restTotal;
    _end = u.end;
    if (u.logged) log.removeLast();
  }

  /// Sets of exercise [i] ±1: at least 1, and never below what's done (+ the one in progress).
  /// Adding a set to a finished exercise reopens it.
  void stepSets(int i, int dir) {
    final e = exercises[i];
    final min = i == ex ? done[i] + 1 : (done[i] < 1 ? 1 : done[i]);
    e.sets = (e.sets + dir).clamp(min, 20);
  }

  /// Do exercise [i] next instead of the listed order (a running rest keeps going).
  void select(int i) {
    if (!finished && !isDone(i)) ex = i;
  }

  void completeSet() {
    if (finished || resting) return;
    _snap(true);
    log.add({'ex': current.name, 'reps': current.repsAt(setIdx), 'weight': current.weightAt(setIdx)});
    restTarget = current.restSec;
    done[ex]++;
    if (isDone(ex)) {
      // Next unfinished exercise after this one (wrapping around: skipped ones come back).
      final n = exercises.length;
      final next = [for (var k = 1; k <= n; k++) (ex + k) % n].where((i) => !isDone(i)).firstOrNull;
      if (next == null) {
        _end = _now();
        return;
      }
      ex = next;
    }
    if (restTarget > 0) _restStart = _now(); // 0s rest (e.g. cardio): straight on, no "rest over" buzz
  }

  /// ±sec on the current rest; shortening below what's already rested ends it on the next tick.
  void addRest(int sec) {
    if (!resting) return;
    final rested = _now().difference(_restStart!).inSeconds;
    restTarget = (restTarget + sec).clamp(rested, 3600);
  }

  void endRest() {
    if (!resting) return;
    _restTotal += _now().difference(_restStart!);
    _restStart = null;
  }

  /// Call every second. Ends the rest when its time is up; true when it just did.
  bool tick() {
    if (!resting || restLeft > 0) return false;
    _restTotal += Duration(seconds: restTarget);
    _restStart = null;
    return true;
  }

  void finishNow() {
    if (finished) return;
    _snap(false);
    endRest();
    _end = _now();
  }
}

/// iOS lock-screen / Dynamic Island timer (ios/Runner/WorkoutLiveActivity.swift).
const _live = MethodChannel('couplefit/live_activity');

Future<void> _liveCall(String method, [Map<String, Object?>? args]) async {
  if (defaultTargetPlatform != TargetPlatform.iOS) return;
  try {
    await _live.invokeMethod(method, args);
  } on PlatformException catch (_) {} // Live Activities off or unsupported: the in-app timer still works
}

Map<String, Object?> _liveState(WorkoutTracker t) {
  final e = t.current;
  return {
    'title': e.name,
    'detail': t.resting
        ? '다음: ${e.name} ${t.setIdx + 1}세트'
        : '세트 ${t.setIdx + 1} / ${e.sets} · ${e.repsAt(t.setIdx)}${e.timed ? '' : '회'}'
              '${e.weightAt(t.setIdx).isEmpty ? '' : ' · ${e.weightAt(t.setIdx)}'}',
    'restEnd': t.restEnd?.millisecondsSinceEpoch,
    'doneSets': t.doneSets,
    'totalSets': t.totalSets,
  };
}

/// The one running workout. Lives above the tabs so the bottom bar stays usable mid-workout.
final activeWorkout = ValueNotifier<WorkoutSession?>(null);

/// Starts a workout unless one is already running (then that one keeps going).
void startWorkout(QueryDocumentSnapshot<Json> routine, String? partnerName) =>
    activeWorkout.value ??= WorkoutSession(routine, partnerName);

class WorkoutSession extends ChangeNotifier {
  WorkoutSession(this.routine, this.partnerName) {
    _liveCall('start', {..._liveState(t), 'routine': r['name'], 'startedAt': t.start.millisecondsSinceEpoch});
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (t.tick()) {
        _buzz();
        showRestAlertNow(_liveState(t)['detail'] as String);
        _liveCall('update', _liveState(t));
      }
      notifyListeners();
    });
  }

  final QueryDocumentSnapshot<Json> routine;
  final String? partnerName; // null = no linked partner
  late final Json r = routine.data();
  late final t = WorkoutTracker(exercisesOf(r));
  late final Timer _tick;
  bool notify = true, saving = false;
  bool adjusting = false; // set card shows ▲▼ after tapping its numbers

  /// Rest is over: three strong buzzes, so it's felt mid-set without looking at the phone.
  static Future<void> _buzz() async {
    for (var i = 0; i < 3; i++) {
      HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 600));
    }
  }

  /// Apply a tracker change, then mirror it to the lock screen and the rest-over alert.
  void act(void Function() change) {
    final wasFinished = t.finished;
    change();
    if (wasFinished && !t.finished) {
      _liveCall('start', {..._liveState(t), 'routine': r['name'], 'startedAt': t.start.millisecondsSinceEpoch});
    }
    _liveCall(t.finished ? 'end' : 'update', t.finished ? null : _liveState(t));
    scheduleRestAlert(t.resting ? t.restEnd : null, t.finished ? '' : _liveState(t)['detail'] as String);
    notifyListeners();
  }

  /// False if the write failed (the session stays open so nothing is lost).
  Future<bool> save() async {
    saving = true;
    notifyListeners();
    try {
      final date = dayKey(t.start);
      await sessionsOf(myUid).add({
        'date': date,
        'routine': r['name'],
        'routineId': routine.id,
        'totalSec': t.totalSec,
        'restSec': t.restSec,
        'sets': t.doneSets,
        'exCount': t.exercises.length,
        'log': t.log,
        'notify': partnerName != null && notify,
        'endedAt': FieldValue.serverTimestamp(),
      });
      await routine.reference.update({'lastDone': date});
      end();
      return true;
    } catch (_) {
      saving = false;
      notifyListeners();
      return false;
    }
  }

  Timer? _persistT;

  /// A sets / reps / weight / rest change: apply it and write it into the routine right away
  /// (debounced so a run of arrow taps is one write; offline, Firestore queues it).
  void edit(void Function() change) {
    act(change);
    _persistT?.cancel();
    _persistT = Timer(const Duration(milliseconds: 800), _persist);
  }

  void _persist() {
    _persistT?.cancel();
    _persistT = null;
    routine.reference.update({'exercises': t.exercises.map((e) => e.toMap()).toList()}).ignore();
  }

  void end() {
    if (_persistT != null) _persist(); // don't lose the last edit
    _tick.cancel();
    _liveCall('end');
    scheduleRestAlert(null, '');
    activeWorkout.value = null;
  }
}

/// Session / rest / finish screen for [s], shown in the 운동 tab.
class WorkoutView extends StatelessWidget {
  const WorkoutView({super.key, required this.s, required this.onDone});
  final WorkoutSession s;
  final VoidCallback onDone; // after saving

  WorkoutTracker get t => s.t;
  Json get r => s.r;

  Future<void> _quit(BuildContext context) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('운동을 그만할까요?'),
        content: Text('지금까지 ${t.doneSets}세트 했어요'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'discard'),
            child: const Text('기록 버리기', style: TextStyle(color: coral)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('계속하기', style: TextStyle(color: sub)),
          ),
          TextButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('여기까지 저장')),
        ],
      ),
    );
    if (choice == 'discard') s.end();
    if (choice == 'save') s.act(t.finishNow);
  }

  /// Planned rest after each set of [e], ±15s (0 – 10 min).
  static void _stepRest(Exercise e, int dir) => e.restSec = (e.restSec + dir * 15).clamp(0, 600);

  /// Exercise [i] from the order list: change its remaining sets, or do it now instead of the listed order.
  Future<void> _edit(BuildContext context, int i) => showDialog<void>(
    context: context,
    builder: (c) => ListenableBuilder(
      listenable: s,
      builder: (_, _) {
        final e = t.exercises[i], from = t.done[i].clamp(0, e.sets - 1);
        Widget col(Widget w) => Expanded(child: w);
        return AlertDialog(
          title: Text(e.name),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (t.done[i] > 0 && !t.isDone(i)) Text('${from + 1}세트부터 바뀌어요', style: ts(12, color: muted)),
                Row(
                  children: [
                    if (!e.cardio) col(stepper('${e.sets}', '세트', (d) => s.edit(() => t.stepSets(i, d)), size: 26)),
                    col(
                      stepper(
                        e.repsAt(from),
                        e.timed ? '시간' : '회',
                        (d) => s.edit(() => e.stepRepsFrom(from, d)),
                        size: 26,
                      ),
                    ),
                    if (!e.cardio) ...[
                      col(
                        stepper(
                          e.weightAt(from).isEmpty ? '-' : e.weightAt(from),
                          '무게',
                          (d) => s.edit(() => e.stepWeightFrom(from, d)),
                          size: 26,
                        ),
                      ),
                      col(stepper('${e.restSec}초', '휴식', (d) => s.edit(() => _stepRest(e, d)), size: 26)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (i != t.ex && !t.isDone(i) && !t.finished)
              TextButton(
                onPressed: () {
                  s.act(() {
                    t.select(i);
                    s.adjusting = false;
                  });
                  Navigator.pop(c);
                },
                child: const Text('지금 하기'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('완료', style: TextStyle(color: sub)),
            ),
          ],
        );
      },
    ),
  );

  /// "다음 휴식 2:00 ⌃" next to 세트 완료: the rest after this set; tap to change it.
  Widget _restBubble(BuildContext context, Exercise e) => Semantics(
    button: true,
    label: '다음 휴식 ${mmss(e.restSec)}, 바꾸기',
    child: GestureDetector(
      onTap: () => _restSheet(context),
      child: CustomPaint(
        painter: _BubbleTail(),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: surf2, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule, size: 13, color: lime),
                  const SizedBox(width: 4),
                  Text(
                    '다음 휴식',
                    style: ts(11, color: sub, w: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(mmss(e.restSec), style: digits(20)),
                  const Icon(Icons.keyboard_arrow_up_rounded, size: 16, color: muted),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _restSheet(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // as tall as its content (the default cap cuts it off on small phones)
    builder: (c) => ListenableBuilder(
      listenable: s,
      builder: (_, _) {
        final e = t.current;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('다음 휴식', style: ts(18, w: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${e.name} 세트 사이 · 루틴에도 저장돼요', style: ts(13, color: muted)),
                const SizedBox(height: 8),
                stepper(mmss(e.restSec), '15초씩', (d) => s.edit(() => _stepRest(e, d)), size: 40),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    for (final sec in [30, 60, 90, 120, 180])
                      pill(mmss(sec), e.restSec == sec, () => s.edit(() => e.restSec = sec)),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(c),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: const Text('완료'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Future<void> _save(BuildContext context) async {
    if (await s.save()) return onDone();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장하지 못했어요. 다시 시도해 주세요')));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: s,
    builder: (context, _) => SafeArea(child: t.finished ? _finish(context) : _session(context)),
  );

  Widget _session(BuildContext context) {
    final e = t.current;
    // Full-height column rules, like the design (taller while the arrows show).
    final divider = Container(
      width: 1,
      height: s.adjusting ? 132 : 52,
      color: off,
      margin: const EdgeInsets.symmetric(horizontal: 6),
    );
    final exs = t.exercises;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => _quit(context),
              tooltip: '운동 그만하기',
              style: IconButton.styleFrom(backgroundColor: surf, fixedSize: const Size(44, 44)),
              icon: const Icon(Icons.close, size: 18),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(r['name'] ?? '', style: ts(15, w: FontWeight.w700)),
                  Text('${t.doneSets} / ${t.totalSets} 세트 · 휴식 ${mmss(t.restSec)}', style: ts(12, color: muted)),
                ],
              ),
            ),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: surf, borderRadius: BorderRadius.circular(22)),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: lime),
                  const SizedBox(width: 6),
                  Text(mmss(t.elapsedSec), style: digits(15)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        bar(t.doneSets / t.totalSets, lime),
        const SizedBox(height: 16),
        if (!t.resting) ...[
          box(
            p: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            r: 28,
            Column(
              children: [
                Text('${t.ex + 1} / ${exs.length} 종목', style: ts(13, color: muted)),
                const SizedBox(height: 14),
                ExerciseArt(e.name, key: ValueKey(e.name), size: 132),
                const SizedBox(height: 14),
                Text(
                  e.name,
                  textAlign: TextAlign.center,
                  style: ts(26, w: FontWeight.w700),
                ),
                const SizedBox(height: 18),
                // Tap the numbers to show ▲▼; tap again (or finish the set) to hide them.
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => s.act(() => s.adjusting = !s.adjusting),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                    child: Column(
                      children: [
                        // Expanded so long weights ("102.5kg") shrink to fit instead of overflowing.
                        Row(
                          children: [
                            if (!e.cardio) ...[
                              Expanded(
                                child: stepper(
                                  '${e.sets}',
                                  '세트',
                                  (d) => s.edit(() => t.stepSets(t.ex, d)),
                                  size: 40,
                                  arrows: s.adjusting,
                                ),
                              ),
                              divider,
                            ],
                            Expanded(
                              child: stepper(
                                e.repsAt(t.setIdx),
                                e.timed ? '시간' : '회',
                                (d) => s.edit(() => e.stepRepsFrom(t.setIdx, d)),
                                size: 40,
                                arrows: s.adjusting,
                              ),
                            ),
                            if (!e.cardio) ...[
                              divider,
                              Expanded(
                                child: stepper(
                                  e.weightAt(t.setIdx).isEmpty ? '-' : e.weightAt(t.setIdx),
                                  '무게',
                                  (d) => s.edit(() => e.stepWeightFrom(t.setIdx, d)),
                                  size: 40,
                                  arrows: s.adjusting,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(s.adjusting ? checkIcon : Icons.edit, size: 12, color: muted),
                            const SizedBox(width: 4),
                            Text(s.adjusting ? '눌러서 완료' : '눌러서 수정', style: ts(11, color: muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var j = 0; j < e.sets; j++)
                      Container(
                        width: 44,
                        height: 8,
                        decoration: BoxDecoration(
                          color: j < t.setIdx ? lime : (j == t.setIdx ? fg : off),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('세트 ${t.setIdx + 1} / ${e.sets}', style: ts(15, w: FontWeight.w600)),
                if (!e.uniform) ...[
                  const SizedBox(height: 6),
                  Text(
                    e.label,
                    textAlign: TextAlign.center,
                    style: ts(12, color: muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => s.act(() {
                    t.completeSet();
                    s.adjusting = false;
                  }),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                    textStyle: ts(18, w: FontWeight.w700),
                  ),
                  child: const Text('세트 완료'),
                ),
              ),
              if (!e.cardio) ...[const SizedBox(width: 12), _restBubble(context, e)],
            ],
          ),
        ] else ...[
          box(
            p: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            r: 28,
            Column(
              children: [
                Text(
                  '휴식 중',
                  style: ts(14, color: muted, w: FontWeight.w600),
                ),
                const SizedBox(height: 18),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ring(232, t.restTarget == 0 ? 0 : t.restLeft / t.restTarget, lime, 12),
                    Column(
                      children: [
                        Text(mmss(t.restLeft.clamp(0, 99999)), style: digits(56)),
                        Text('/ ${mmss(t.restTarget)}', style: ts(13, color: muted)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => s.act(() => t.addRest(-15)),
                      style: TextButton.styleFrom(
                        backgroundColor: surf2,
                        foregroundColor: fg,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Text('−15초'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => s.act(() => t.addRest(15)),
                      style: TextButton.styleFrom(
                        backgroundColor: surf2,
                        foregroundColor: fg,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Text('+15초'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => s.act(t.endRest),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: lime,
                        side: const BorderSide(color: lime, width: 1.5),
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('건너뛰기'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          box(
            r: 20,
            p: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: surf2, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.fitness_center, size: 20, color: lime),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('다음 세트', style: ts(12, color: muted)),
                    Text('${e.name} · ${t.setIdx + 1}세트', style: ts(15, w: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (t.canUndo)
          Center(
            child: TextButton.icon(
              onPressed: () => s.act(() {
                t.undo();
                s.adjusting = false;
              }),
              style: TextButton.styleFrom(foregroundColor: muted, minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: Text(t.resting ? '방금 세트 취소' : '이전 세트 취소'),
            ),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Text('오늘의 순서 · 눌러서 수정하거나 먼저 하기', style: ts(13, color: muted)),
        ),
        for (var i = 0; i < exs.length; i++) _orderRow(context, i),
      ],
    );
  }

  Widget _orderRow(BuildContext context, int i) {
    final e = t.exercises[i];
    final st = t.isDone(i) ? 'done' : (i == t.ex ? 'cur' : 'next');
    return GestureDetector(onTap: () => _edit(context, i), child: _orderRowBody(e, i, st));
  }

  Widget _orderRowBody(Exercise e, int i, String st) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: st == 'cur' ? surf : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: st == 'done' ? lime : (st == 'cur' ? fg : surf2),
            child: Text('${i + 1}', style: digits(13, color: st == 'next' ? muted : ink)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  style: ts(15, w: FontWeight.w600, color: st == 'done' ? muted : (st == 'cur' ? fg : sub)),
                ),
                Text(e.label, style: ts(12, color: muted)),
              ],
            ),
          ),
          Text(
            st == 'done' ? '완료' : (st == 'cur' || t.done[i] > 0 ? '${t.done[i]}/${e.sets}세트' : '${e.sets}세트'),
            style: ts(12, w: FontWeight.w600, color: st == 'done' ? lime : (st == 'cur' ? fg : muted)),
          ),
        ],
      ),
    );
  }

  Widget _finish(BuildContext context) {
    Widget stat(String v, String label) => Expanded(
      child: box(
        r: 18,
        p: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        Column(
          children: [
            Text(v, style: digits(24)),
            const SizedBox(height: 4),
            Text(label, style: ts(12, color: muted)),
          ],
        ),
      ),
    );
    final pa = s.partnerName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 48, bottom: 16),
              children: [
                Center(
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: lime,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: lime.withValues(alpha: 0.12), spreadRadius: 14)],
                    ),
                    child: const Icon(checkIcon, size: 52, color: ink),
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  '운동 완료!',
                  textAlign: TextAlign.center,
                  style: ts(30, w: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Text(
                  t.complete ? '${r['name']} 루틴을 끝까지 해냈어요' : '${r['name']} · ${t.doneSets}세트까지 했어요',
                  textAlign: TextAlign.center,
                  style: ts(15, color: muted),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    stat(mmss(t.elapsedSec), '운동 시간'),
                    const SizedBox(width: 10),
                    stat('${t.doneSets}', '세트'),
                    const SizedBox(width: 10),
                    stat('${t.exercises.length}', '종목'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '휴식 합계 ${mmss(t.restSec)}',
                  textAlign: TextAlign.center,
                  style: ts(13, color: muted),
                ),
                const SizedBox(height: 22),
                if (pa != null)
                  tapBox(
                    () => s.act(() => s.notify = !s.notify),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$pa님에게 완료 알림 보내기', style: ts(15, w: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('저장하면 짝꿍의 오늘 기록도 열려요', style: ts(13, color: muted)),
                            ],
                          ),
                        ),
                        Switch(value: s.notify, onChanged: (v) => s.act(() => s.notify = v)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (t.canUndo && !s.saving)
            TextButton.icon(
              onPressed: () => s.act(t.undo),
              style: TextButton.styleFrom(foregroundColor: muted, minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.undo_rounded, size: 18),
              // Finished with every set done = the last tap was a set; otherwise it was "여기까지 저장".
              label: Text(t.complete ? '마지막 세트 되돌리기' : '운동 이어서 하기'),
            ),
          FilledButton(onPressed: s.saving ? null : () => _save(context), child: const Text('기록 저장하고 홈으로')),
        ],
      ),
    );
  }
}

/// The little point on the left of the rest bubble, aiming at 세트 완료.
class _BubbleTail extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawPath(
      Path()
        ..moveTo(1, y - 7)
        ..lineTo(-6, y)
        ..lineTo(1, y + 7)
        ..close(),
      Paint()..color = surf2,
    );
  }

  @override
  bool shouldRepaint(_BubbleTail old) => false;
}
