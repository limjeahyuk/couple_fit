import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  int ex = 0, setIdx = 0, restTarget = 0; // setIdx = sets done in the current exercise
  Duration _restTotal = Duration.zero;

  /// What was actually done, one entry per completed set (reps/weight as they were at that moment).
  final log = <Json>[];

  bool get finished => _end != null;
  bool get resting => _restStart != null;
  Exercise get current => exercises[ex];
  int get totalSets => exercises.fold(0, (a, e) => a + e.sets);
  int get doneSets => exercises.take(ex).fold(0, (a, e) => a + e.sets) + setIdx;
  bool get complete => doneSets == totalSets;
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
      <({int ex, int setIdx, int restTarget, DateTime? restStart, Duration restTotal, DateTime? end, bool logged})>[];
  void _snap(bool logged) => _undo.add((
    ex: ex,
    setIdx: setIdx,
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
    setIdx = u.setIdx;
    restTarget = u.restTarget;
    _restStart = u.restStart;
    _restTotal = u.restTotal;
    _end = u.end;
    if (u.logged) log.removeLast();
  }

  /// Sets of exercise [i] ±1: at least 1, and never below what's done (+ the one in progress).
  void stepSets(int i, int dir) {
    final e = exercises[i];
    final min = i == ex ? setIdx + 1 : (i < ex ? e.sets : 1);
    e.sets = (e.sets + dir).clamp(min, 20);
  }

  void completeSet() {
    if (finished || resting) return;
    _snap(true);
    log.add({'ex': current.name, 'reps': current.reps, 'weight': current.weight});
    restTarget = current.restSec;
    final rest = restTarget > 0 ? _now() : null; // 0s rest (e.g. cardio): straight on, no "rest over" buzz
    if (++setIdx < current.sets) {
      _restStart = rest;
    } else if (ex == exercises.length - 1) {
      _end = _now();
    } else {
      ex++;
      setIdx = 0;
      _restStart = rest;
    }
  }

  void addRest(int sec) {
    if (resting) restTarget += sec;
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
        : '세트 ${t.setIdx + 1} / ${e.sets} · ${e.reps}${e.timed ? '' : '회'}${e.weight.isEmpty ? '' : ' · ${e.weight}'}',
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

  bool routineSaved = false;

  /// Sets/reps/weight changed mid-workout vs the routine as saved, e.g. "벤치프레스  40kg × 10회 → 45kg × 8회".
  List<String> get changes {
    final orig = exercisesOf(r);
    String fmt(Exercise e) => '${e.sets}세트 · ${e.weight.isEmpty ? '' : '${e.weight} × '}${e.reps}${e.timed ? '' : '회'}';
    return [
      for (var i = 0; i < t.exercises.length && i < orig.length; i++)
        if (fmt(t.exercises[i]) != fmt(orig[i])) '${orig[i].name}  ${fmt(orig[i])} → ${fmt(t.exercises[i])}',
    ];
  }

  Future<void> saveToRoutine() async {
    await routine.reference.update({'exercises': t.exercises.map((e) => e.toMap()).toList()});
    routineSaved = true;
    notifyListeners();
  }

  void end() {
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

  /// Adjust an upcoming exercise from the order list (same arrows, no keyboard).
  Future<void> _edit(BuildContext context, Exercise e) => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(e.name),
      content: ListenableBuilder(
        listenable: s,
        builder: (_, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (!e.cardio)
              stepper('${e.sets}', '세트', (d) => s.act(() => t.stepSets(t.exercises.indexOf(e), d)), size: 32),
            stepper(e.reps, e.timed ? '시간' : '회', (d) => s.act(() => e.reps = stepReps(e.reps, d)), size: 32),
            if (!e.cardio)
              stepper(
                e.weight.isEmpty ? '-' : e.weight,
                '무게',
                (d) => s.act(() => e.weight = stepWeight(e.weight, d)),
                size: 32,
              ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('완료'))],
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
    final divider = Container(width: 1, height: 44, color: off, margin: const EdgeInsets.symmetric(horizontal: 8));
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
                const SizedBox(height: 18),
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
                                flex: 2,
                                child: stepper(
                                  '${e.sets}',
                                  '세트',
                                  (d) => s.act(() => t.stepSets(t.ex, d)),
                                  size: 40,
                                  arrows: s.adjusting,
                                ),
                              ),
                              divider,
                            ],
                            Expanded(
                              flex: 3,
                              child: stepper(
                                e.reps,
                                e.timed ? '시간' : '회',
                                (d) => s.act(() => e.reps = stepReps(e.reps, d)),
                                size: 40,
                                arrows: s.adjusting,
                              ),
                            ),
                            if (!e.cardio) ...[
                              divider,
                              Expanded(
                                flex: 4,
                                child: stepper(
                                  e.weight.isEmpty ? '-' : e.weight,
                                  '무게',
                                  (d) => s.act(() => e.weight = stepWeight(e.weight, d)),
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
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
                      onPressed: () => s.act(() => t.addRest(15)),
                      style: TextButton.styleFrom(
                        backgroundColor: surf2,
                        foregroundColor: fg,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: const Text('+15초'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => s.act(t.endRest),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: lime,
                        side: const BorderSide(color: lime, width: 1.5),
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('휴식 건너뛰기'),
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
          child: Text('오늘의 순서', style: ts(13, color: muted)),
        ),
        for (var i = 0; i < exs.length; i++) _orderRow(context, i),
      ],
    );
  }

  Widget _orderRow(BuildContext context, int i) {
    final e = t.exercises[i];
    final st = i < t.ex ? 'done' : (i == t.ex ? 'cur' : 'next');
    return GestureDetector(onTap: st == 'done' ? null : () => _edit(context, e), child: _orderRowBody(e, i, st));
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
                Text(
                  '${e.sets}세트 × ${e.reps}${e.timed ? '' : '회'}${e.weight.isEmpty ? '' : ' · ${e.weight}'}',
                  style: ts(12, color: muted),
                ),
              ],
            ),
          ),
          Text(
            st == 'done' ? '완료' : (st == 'cur' ? '${t.setIdx}/${e.sets}세트' : '${e.sets}세트'),
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
                ..._routineChanges(context),
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

  /// Mid-workout edits, with a separate button to write them into the routine.
  List<Widget> _routineChanges(BuildContext context) {
    final ch = s.changes;
    if (ch.isEmpty) return [];
    return [
      const SizedBox(height: 16),
      box(
        r: 20,
        p: const EdgeInsets.all(18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('운동 중에 바꾼 값', style: ts(13, color: muted)),
            const SizedBox(height: 8),
            for (final c in ch)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(c, style: ts(14)),
              ),
            const SizedBox(height: 12),
            if (s.routineSaved)
              Row(
                children: [
                  const Icon(checkIcon, size: 18, color: lime),
                  const SizedBox(width: 6),
                  Text(
                    '루틴에 저장했어요',
                    style: ts(14, color: lime, w: FontWeight.w600),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: () => s.saveToRoutine().catchError((_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('루틴에 저장하지 못했어요')));
                  }
                }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: lime,
                  side: const BorderSide(color: lime, width: 1.5),
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.save_alt, size: 18),
                label: Text('${r['name']} 루틴에 저장'),
              ),
          ],
        ),
      ),
    ];
  }
}
