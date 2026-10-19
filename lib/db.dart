import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Firestore layout:
//   users/{uid}              {name, code, partnerId?, nudgeAt?, avatar?, gender? (m/f, for default weights)}
//   users/{uid}/routines/*   {name, tag, exercises[], by, createdAt, lastDone?}
//   users/{uid}/sessions/*   {date 'yyyy-MM-dd', routine, totalSec, restSec, sets, exCount, notify, log[], endedAt}
//   users/{uid}/body/{date}  {date, height cm, weight kg, fat %, muscle kg?}  (one measurement per day)
// A couple is linked when both users' partnerId point at each other.

typedef Json = Map<String, dynamic>;

final fs = FirebaseFirestore.instance;
String get myUid => FirebaseAuth.instance.currentUser!.uid;
DocumentReference<Json> userDoc(String uid) => fs.doc('users/$uid');
CollectionReference<Json> routinesOf(String uid) => userDoc(uid).collection('routines');
CollectionReference<Json> sessionsOf(String uid) => userDoc(uid).collection('sessions');
CollectionReference<Json> bodyOf(String uid) => userDoc(uid).collection('body');

String two(int n) => n.toString().padLeft(2, '0');
String dayKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
String todayKey() => dayKey(DateTime.now());
String mmss(int sec) => '${sec ~/ 60}:${two(sec % 60)}';
String hhmm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
String wd(DateTime d) => weekdays[d.weekday % 7];
String dateLabel(DateTime d) => '${d.month}월 ${d.day}일 ${wd(d)}요일';
DateTime prevDay(DateTime d) => DateTime(d.year, d.month, d.day - 1);

String relDay(String key) {
  final n = DateTime.parse(todayKey()).difference(DateTime.parse(key)).inDays;
  return n == 0 ? '오늘' : n == 1 ? '어제' : '$n일 전';
}

/// Arrow buttons: reps ±1, timed "40초" ±5, cardio "30분" ±5.
String stepReps(String reps, int dir) {
  final m = RegExp(r'^(\d+)(.*)$').firstMatch(reps.trim());
  if (m == null) return reps;
  final unit = m[2]!, step = unit.contains('초') || unit.contains('분') ? 5 : 1;
  final next = int.parse(m[1]!) + dir * step;
  return '${next < step ? step : next}$unit';
}

/// Weight ±2.5 from 20 up, ±1 below; 0 or less is bodyweight ("맨몸").
String stepWeight(String weight, int dir) {
  final m = RegExp(r'^(\d+(?:\.\d+)?)\s*(.*)$').firstMatch(weight.trim());
  final n = m == null ? 0.0 : double.parse(m[1]!);
  final unit = m == null || m[2]!.isEmpty ? 'kg' : m[2]!;
  final big = dir > 0 ? n >= 20 : n > 20; // 20kg itself steps down by 1 so 20 → 19, up by 2.5
  final next = n + dir * (big ? 2.5 : 1.0);
  if (next <= 0) return '맨몸';
  return '${next == next.roundToDouble() ? next.toInt() : next}$unit';
}

/// Body measurement figures. Stored: weight, height, fat (%), muscle; derived: fat mass, BMI.
typedef Metric = ({String label, String unit, double? Function(Map b) of});

double? _d(Object? v) => v is num ? v.toDouble() : null;

final List<Metric> bodyMetrics = [
  (label: '체중', unit: 'kg', of: (b) => _d(b['weight'])),
  (label: '체지방률', unit: '%', of: (b) => _d(b['fat'])),
  (label: '골격근량', unit: 'kg', of: (b) => _d(b['muscle'])),
  (label: '체지방량', unit: 'kg', of: (b) {
    final w = _d(b['weight']), f = _d(b['fat']);
    return w == null || f == null ? null : w * f / 100;
  }),
  (label: 'BMI', unit: '', of: (b) {
    final w = _d(b['weight']), h = _d(b['height']);
    return w == null || h == null || h <= 0 ? null : w / ((h / 100) * (h / 100));
  }),
];

/// One decimal, no trailing ".0": 72.0 → "72", 18.46 → "18.5".
String fmt1(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// Signed change for the "처음 대비" chart: "+0.5", "−1.2" (true minus sign), "0".
String signed(double v) {
  final r = double.parse(v.toStringAsFixed(1));
  return r == 0 ? '0' : '${r > 0 ? '+' : '−'}${fmt1(r.abs())}';
}

/// Change vs the previous measurement, e.g. "▲0.4" / "▼1.2" / "-" (no previous or no change).
String delta(double? now, double? before) {
  if (now == null || before == null) return '';
  final d = double.parse((now - before).toStringAsFixed(1));
  return d == 0 ? '-' : '${d > 0 ? '▲' : '▼'}${fmt1(d.abs())}';
}

/// Per-exercise lines from a session's set log, e.g. "벤치프레스 · 40kg × 10·10·8".
List<String> logLines(List? log) {
  final groups = <String, List<Map>>{}; // insertion-ordered
  for (final e in log ?? const []) {
    (groups['${e['ex']}'] ??= []).add(e as Map);
  }
  return [
    for (final MapEntry(key: name, value: sets) in groups.entries)
      if (sets.every((s) => s['weight'] == sets.first['weight']))
        '$name · ${'${sets.first['weight'] ?? ''}'.isEmpty ? '' : '${sets.first['weight']} × '}${sets.map((s) => s['reps']).join('·')}'
      else
        '$name · ${sets.map((s) => '${s['weight']} × ${s['reps']}').join(', ')}',
  ];
}

/// [routine] with each exercise's sets as actually done in [log] (per-set reps/weights).
/// Exercises not in the log stay as they are; logged ones the routine lacks are added at the end.
List<Exercise> routineFromLog(List<Exercise> routine, List? log) {
  final done = <String, List<Map>>{}; // insertion-ordered
  for (final e in log ?? const []) {
    (done['${e['ex']}'] ??= []).add(e as Map);
  }
  Exercise from(String name, List<Map> sets, int rest) => Exercise(
    name: name,
    sets: sets.length,
    restSec: rest,
    setReps: [for (final s in sets) '${s['reps']}'],
    setWeights: [for (final s in sets) '${s['weight'] ?? ''}'],
  );
  return [
    for (final e in routine) done.containsKey(e.name) ? from(e.name, done.remove(e.name)!, e.restSec) : e,
    for (final MapEntry(:key, :value) in done.entries) from(key, value, 60),
  ];
}

String summary(Json s) => '${s['routine']} · ${((s['totalSec'] ?? 0) / 60).round()}분';

class Exercise {
  Exercise({
    this.name = '',
    int sets = 3,
    String reps = '10',
    String weight = '',
    this.restSec = 60,
    List<String>? setReps,
    List<String>? setWeights,
  }) : _r = _fit(setReps, sets, reps),
       _w = _fit(setWeights, sets, weight);

  String name;
  int restSec;

  /// Reps / weight of each set (a pyramid like 10 → 12 → 14kg is just different values).
  /// reps may be time, e.g. '40초' / '30분'.
  final List<String> _r, _w;

  static List<String> _fit(List<String>? per, int sets, String fill) {
    final n = sets < 1 ? 1 : sets;
    final l = per != null && per.isNotEmpty ? per.toList() : <String>[fill];
    while (l.length < n) {
      l.add(l.last);
    }
    return l.sublist(0, n);
  }

  int get sets => _r.length;

  /// Adding sets repeats the last set's values; removing drops from the end.
  set sets(int n) {
    final f = _fit(_r, n, ''), g = _fit(_w, n, '');
    _r
      ..clear()
      ..addAll(f);
    _w
      ..clear()
      ..addAll(g);
  }

  String repsAt(int i) => _r[i.clamp(0, sets - 1)];
  String weightAt(int i) => _w[i.clamp(0, sets - 1)];
  void setRepsAt(int i, String v) => _r[i] = v;
  void setWeightAt(int i, String v) => _w[i] = v;

  /// First set's values; setting one makes every set the same.
  String get reps => _r.first;
  set reps(String v) => _r.fillRange(0, sets, v);
  String get weight => _w.first;
  set weight(String v) => _w.fillRange(0, sets, v);

  bool get uniform => _r.every((v) => v == _r.first) && _w.every((v) => v == _w.first);

  /// Mid-workout arrows: shift set [from] and every later set, so a pyramid keeps its shape.
  void stepRepsFrom(int from, int dir) {
    for (var i = from; i < sets; i++) {
      _r[i] = stepReps(_r[i], dir);
    }
  }

  void stepWeightFrom(int from, int dir) {
    for (var i = from; i < sets; i++) {
      _w[i] = stepWeight(_w[i], dir);
    }
  }

  bool get timed => reps.contains('초') || cardio;

  /// Running, swimming, hiking...: one entry of N minutes, no sets/weight/rest.
  bool get cardio => reps.endsWith('분');

  /// "3세트 × 10회 · 40kg", or per set "40kg×10 · 45kg×8 · 50kg×6".
  String get label {
    String r(String v) => '$v${timed ? '' : '회'}';
    if (uniform) return '$sets세트 × ${r(reps)}${weight.isEmpty ? '' : ' · $weight'}';
    return [for (var i = 0; i < sets; i++) _w[i].isEmpty ? r(_r[i]) : '${_w[i]}×${_r[i]}'].join(' · ');
  }

  factory Exercise.fromMap(Json m) => Exercise(
    name: m['name'] ?? '',
    sets: m['sets'] ?? 3,
    reps: '${m['reps'] ?? 10}',
    weight: m['weight'] ?? '',
    restSec: m['restSec'] ?? 60,
    setReps: (m['setReps'] as List?)?.map((e) => '$e').toList(),
    setWeights: (m['setWeights'] as List?)?.map((e) => '$e').toList(),
  );

  // reps/weight stay for older app versions; per-set lists only when the sets differ.
  Json toMap() => {
    'name': name,
    'sets': sets,
    'reps': reps,
    'weight': weight,
    'restSec': restSec,
    if (!uniform) ...{'setReps': [..._r], 'setWeights': [..._w]},
  };
}

List<Exercise> exercisesOf(Json routine) =>
    [for (final e in (routine['exercises'] as List? ?? [])) Exercise.fromMap(Json.from(e))];

/// ~1 min per set plus planned rest; cardio counts its minutes.
int estMins(List<Exercise> ex) =>
    (ex.fold(0, (a, e) => a + (e.cardio ? e.sets * 60 * (int.tryParse(e.reps.replaceAll('분', '')) ?? 0) : e.sets * (60 + e.restSec))) / 60)
        .round();

String routineMeta(Json r) {
  final ex = exercisesOf(r);
  final tag = (r['tag'] as String?)?.trim() ?? '';
  return '${tag.isEmpty ? '' : '$tag · '}${ex.length}종목 · 약 ${estMins(ex)}분';
}

/// Everything the tabs render, gathered by the shell's subscriptions.
class AppData {
  AppData({required this.me, this.partner, this.mySessions = const [], this.paSessions = const [],
      this.routines = const [], this.myBody = const [], this.paBody = const []});

  final Json me;
  final Json? partner; // linked partner doc + 'uid'
  final List<Json> mySessions, paSessions; // newest first
  final List<QueryDocumentSnapshot<Json>> routines;
  final List<Json> myBody, paBody; // body measurements, oldest first

  String get myName => me['name'] ?? '나';
  String get paName => partner?['name'] ?? '짝꿍';

  List<Json> mineOn(String k) => mySessions.where((s) => s['date'] == k).toList();
  bool get doneToday => mineOn(todayKey()).isNotEmpty;

  /// Partner's today stays hidden until I finish my own workout.
  bool get locked => !doneToday;
  List<Json> partnerOn(String k) =>
      k == todayKey() && locked ? [] : paSessions.where((s) => s['date'] == k).toList();
  Json? get partnerLast => paSessions.where((s) => !(locked && s['date'] == todayKey())).firstOrNull;
  bool get partnerNotifiedToday => paSessions.any((s) => s['date'] == todayKey() && s['notify'] == true);
  bool get partnerNudgedToday => partner?['nudgeAt'] == todayKey();
  bool get nudgedToday => me['nudgeAt'] == todayKey();

  bool both(String k) => mineOn(k).isNotEmpty && partnerOn(k).isNotEmpty;
  int get streak {
    var d = DateTime.now();
    if (!both(dayKey(d))) d = prevDay(d);
    var n = 0;
    for (; both(dayKey(d)); d = prevDay(d)) {
      n++;
    }
    return n;
  }

  /// The routine a session of mine came from (by id; older sessions only stored the name).
  QueryDocumentSnapshot<Json>? routineOf(Json session) =>
      routines.where((r) => r.id == session['routineId']).firstOrNull ??
      routines.where((r) => r.data()['name'] == session['routine']).firstOrNull;

  /// Recommend the routine done longest ago (never-done first, then creation order).
  QueryDocumentSnapshot<Json>? get todayRoutine {
    // Plain loop: Firestore's list is a narrower runtime type, so reduce() with a wider closure throws.
    String last(QueryDocumentSnapshot<Json> r) => '${r.data()['lastDone'] ?? ''}';
    QueryDocumentSnapshot<Json>? best;
    for (final r in routines) {
      if (best == null || last(r).compareTo(last(best)) < 0) best = r;
    }
    return best;
  }
}

/// Starter routines written on sign-up.
List<Json> sampleRoutines(String by) {
  Json e(String n, int s, String r, String w, int rest) => Exercise(name: n, sets: s, reps: r, weight: w, restSec: rest).toMap();
  Json r(String name, String tag, List<Json> ex) => {'name': name, 'tag': tag, 'exercises': ex, 'by': by};
  return [
    r('상체 푸시', '가슴·어깨·삼두', [
      e('벤치프레스', 4, '10', '40kg', 90), e('인클라인 덤벨 프레스', 3, '12', '14kg', 75),
      e('덤벨 숄더 프레스', 3, '12', '12kg', 75), e('사이드 레터럴 레이즈', 3, '15', '6kg', 60),
      e('케이블 푸시다운', 3, '15', '20kg', 60)]),
    r('하체 데이', '허벅지·둔근·종아리', [
      e('바벨 스쿼트', 4, '8', '60kg', 120), e('루마니안 데드리프트', 3, '10', '40kg', 90),
      e('레그 프레스', 3, '12', '100kg', 90), e('워킹 런지', 3, '12', '맨몸', 60), e('카프 레이즈', 4, '20', '맨몸', 45)]),
    r('등·이두', '광배·승모·이두', [
      e('랫풀다운', 4, '10', '45kg', 90), e('바벨 로우', 3, '10', '40kg', 90), e('시티드 케이블 로우', 3, '12', '40kg', 75),
      e('페이스 풀', 3, '15', '15kg', 60), e('덤벨 컬', 3, '12', '8kg', 60)]),
    r('커플 서킷', '둘이 함께 하는 전신', [
      e('버피', 3, '15', '맨몸', 45), e('파트너 메디신볼 패스', 3, '20', '4kg', 45), e('플랭크 하이파이브', 3, '40초', '맨몸', 30),
      e('점프 스쿼트', 3, '15', '맨몸', 45), e('마운틴 클라이머', 3, '30', '맨몸', 30)]),
  ];
}
