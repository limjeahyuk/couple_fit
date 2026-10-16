import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'art.dart';
import 'db.dart';
import 'exercises.dart';
import 'theme.dart';
import 'workout.dart';

/// Routines of [uid]. Mine: start / edit. Partner's ([uid] != me): build routines for them.
class RoutinesPage extends StatelessWidget {
  const RoutinesPage({super.key, required this.data, required this.uid});
  final AppData data;
  final String uid;

  bool get mine => uid == myUid;

  void _edit(BuildContext context, [QueryDocumentSnapshot<Json>? doc]) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RoutineEditor(
        col: routinesOf(uid),
        doc: doc,
        myName: data.myName,
        // Whose body the default weights are based on.
        person: (mine ? data.me : data.partner) ?? const {},
        body: mine ? data.myBody : data.paBody,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pa = data.partner, last = data.partnerLast;
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      children: [
        Row(
          children: [
            Expanded(child: h1(mine ? '운동 루틴' : '${data.paName}님 루틴')),
            IconButton(
              tooltip: '루틴 추가',
              onPressed: () => _edit(context),
              style: IconButton.styleFrom(backgroundColor: surf, fixedSize: const Size(44, 44)),
              icon: const Icon(Icons.add, color: lime),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          mine ? '루틴을 고르면 세트 기록과 휴식 타이머가 앱 안에서 이어서 진행돼요' : '짝꿍의 루틴을 대신 짜주거나 고쳐줄 수 있어요',
          style: ts(14, color: muted, h: 1.5),
        ),
        const SizedBox(height: 16),
        StreamBuilder(
          stream: routinesOf(uid).orderBy('createdAt').snapshots(),
          builder: (context, snap) {
            final docs = snap.data?.docs ?? [];
            if (snap.hasData && docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text('루틴이 없어요. + 로 만들어보세요', style: ts(14, color: muted)),
              );
            }
            return Column(children: [for (final d in docs) _card(context, d)]);
          },
        ),
        if (mine && pa != null) ...[
          if (last != null)
            box(
              r: 20,
              p: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
              Row(
                children: [
                  avatar(data.paName, coral, size: 32, look: pa['avatar']),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: ts(14, color: sub, h: 1.5),
                        children: [
                          TextSpan(text: '${data.paName}님은 ${relDay(last['date'])} '),
                          TextSpan(
                            text: '${last['routine']}',
                            style: ts(14, w: FontWeight.w700),
                          ),
                          TextSpan(text: '를 ${((last['totalSec'] ?? 0) / 60).round()}분 동안 했어요'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RoutinesPage(data: data, uid: pa['uid']),
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: coral,
              side: const BorderSide(color: coral, width: 1.5),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.favorite, size: 18),
            label: Text('${data.paName}님 루틴 짜주기'),
          ),
        ],
      ],
    );
    return Scaffold(
      appBar: mine ? null : AppBar(),
      body: SafeArea(child: list),
    );
  }

  Widget _card(BuildContext context, QueryDocumentSnapshot<Json> d) {
    final r = d.data();
    final today = mine && data.todayRoutine?.id == d.id;
    final gift = r['by'] != null && r['by'] != (mine ? data.myName : data.paName);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: surf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: today ? lime.withValues(alpha: 0.5) : Colors.transparent, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _edit(context, d),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (today)
                            Text(
                              '오늘 추천',
                              style: ts(12, color: lime, w: FontWeight.w700),
                            ),
                          if (gift)
                            Text(
                              '${r['by']}님이 짜준 루틴',
                              style: ts(12, color: coral, w: FontWeight.w700),
                            ),
                          const SizedBox(height: 4),
                          Text(r['name'] ?? '', style: ts(18, w: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(routineMeta(r), style: ts(13, color: muted)),
                        ],
                      ),
                    ),
                    if (mine)
                      FilledButton(
                        onPressed: () => startWorkout(d, data.partner?['name']),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: const StadiumBorder(),
                          textStyle: ts(14, w: FontWeight.w700),
                        ),
                        child: const Text('시작'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(exercisesOf(r).map((e) => e.name).join(' · '), style: ts(13, color: sub, h: 1.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RoutineEditor extends StatefulWidget {
  const RoutineEditor({
    super.key,
    required this.col,
    this.doc,
    required this.myName,
    this.person = const {},
    this.body = const [],
  });
  final CollectionReference<Json> col;
  final QueryDocumentSnapshot<Json>? doc;
  final String myName;
  final Json person; // routine owner's profile ('gender')
  final List<Json> body; // their measurements, oldest first

  @override
  State<RoutineEditor> createState() => _RoutineEditorState();
}

class _RoutineEditorState extends State<RoutineEditor> {
  late String name = widget.doc?.data()['name'] ?? '', tag = widget.doc?.data()['tag'] ?? '';
  late final List<Exercise> items = widget.doc == null ? [] : exercisesOf(widget.doc!.data());

  Future<void> _save() async {
    final ex = items.where((e) => e.name.trim().isNotEmpty && e.sets > 0).toList();
    if (name.trim().isEmpty || ex.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('루틴 이름과 운동을 1개 이상 입력하세요')));
      return;
    }
    // No tag typed: use the picked body parts, e.g. "가슴·삼두".
    final auto = {for (final e in ex) categoryOf(e.name)}..remove('');
    final data = {
      'name': name.trim(),
      'tag': tag.trim().isEmpty ? auto.join('·') : tag.trim(),
      'exercises': ex.map((e) => e.toMap()).toList(),
    };
    await (widget.doc == null
        ? widget.col.add({...data, 'by': widget.myName, 'createdAt': FieldValue.serverTimestamp()})
        : widget.doc!.reference.update(data));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pick() async {
    final picked = await showModalBottomSheet<List<Exercise>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ExercisePicker(person: widget.person, body: widget.body, have: {for (final e in items) e.name}),
    );
    if (picked != null) setState(() => items.addAll(picked));
  }

  /// Type a value instead of stepping (e.g. leg press 100 → 160).
  Future<void> _type(String label, String value, void Function(String) set, {bool number = true}) async {
    final ctl = TextEditingController(text: value == '맨몸' ? '' : value.replaceAll(RegExp(r'[^0-9.]'), ''));
    final v = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('취소', style: TextStyle(color: sub)),
          ),
          TextButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('확인')),
        ],
      ),
    );
    if (v != null) setState(() => set(v.trim()));
  }

  Widget _field(String label, String value, void Function(String) set) => TextFormField(
    initialValue: value,
    decoration: InputDecoration(labelText: label, isDense: true),
    onChanged: set,
  );

  Widget _row(Exercise e) {
    void up(void Function() f) => setState(f);
    return Padding(
      key: ObjectKey(e),
      padding: const EdgeInsets.only(bottom: 12),
      child: box(
        r: 20,
        p: const EdgeInsets.fromLTRB(16, 6, 6, 8),
        Column(
          children: [
            Row(
              children: [
                ExerciseArt(e.name, size: 44, animate: false),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(e.name, style: ts(16, w: FontWeight.w600)),
                ),
                IconButton(
                  tooltip: '운동 삭제',
                  icon: const Icon(Icons.close, color: muted),
                  onPressed: () => up(() => items.remove(e)),
                ),
              ],
            ),
            Row(
              children: [
                if (!e.cardio)
                  Expanded(
                    child: stepper(
                      '${e.sets}',
                      '세트',
                      (d) => up(() => e.sets = (e.sets + d).clamp(1, 20)),
                      size: 20,
                      onTapValue: () =>
                          _type('세트', '${e.sets}', (v) => e.sets = (int.tryParse(v) ?? e.sets).clamp(1, 20)),
                    ),
                  ),
                Expanded(
                  child: stepper(
                    e.reps,
                    e.timed ? '시간' : '횟수',
                    (d) => up(() => e.reps = stepReps(e.reps, d)),
                    size: 20,
                    onTapValue: () => _type(
                      e.cardio
                          ? '시간(분)'
                          : e.timed
                          ? '시간(초)'
                          : '횟수',
                      e.reps,
                      (v) => e.reps = int.tryParse(v) == null
                          ? e.reps
                          : '$v${e.cardio
                                ? '분'
                                : e.timed
                                ? '초'
                                : ''}',
                    ),
                  ),
                ),
                if (!e.cardio) ...[
                  Expanded(
                    flex: 2,
                    child: stepper(
                      e.weight.isEmpty ? '-' : e.weight,
                      '무게',
                      (d) => up(() => e.weight = stepWeight(e.weight, d)),
                      size: 20,
                      onTapValue: () => _type('무게(kg) · 비우면 맨몸', e.weight, (v) {
                        final n = double.tryParse(v);
                        e.weight = n == null || n <= 0 ? '맨몸' : '${fmt1(n)}kg';
                      }),
                    ),
                  ),
                  Expanded(
                    child: stepper(
                      '${e.restSec}초',
                      '휴식',
                      (d) => up(() => e.restSec = (e.restSec + d * 15).clamp(0, 600)),
                      size: 20,
                      onTapValue: () => _type(
                        '휴식(초)',
                        '${e.restSec}',
                        (v) => e.restSec = (int.tryParse(v) ?? e.restSec).clamp(0, 600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.doc == null ? '새 루틴' : '루틴 수정'),
        actions: [
          if (widget.doc != null)
            IconButton(
              tooltip: '삭제',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await widget.doc!.reference.delete();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          TextButton(onPressed: _save, child: const Text('저장')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          _field('루틴 이름 (예: 하체 데이)', name, (v) => name = v),
          const SizedBox(height: 10),
          _field('부위 (비우면 고른 운동으로 자동)', tag, (v) => tag = v),
          const SizedBox(height: 16),
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('숫자를 누르면 직접 입력할 수 있어요', style: ts(12, color: muted)),
            ),
          for (final e in items) _row(e),
          OutlinedButton.icon(
            onPressed: _pick,
            style: OutlinedButton.styleFrom(
              foregroundColor: lime,
              side: const BorderSide(color: lime, width: 1.5),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.add),
            label: const Text('운동 추가'),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet: body-part chips → tap exercises to select → add them with default weights.
class ExercisePicker extends StatefulWidget {
  const ExercisePicker({super.key, required this.person, required this.body, this.have = const {}});
  final Json person;
  final List<Json> body;
  final Set<String> have; // already in the routine

  @override
  State<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<ExercisePicker> {
  String cat = catalog.keys.first;
  final picked = <CatalogItem>[];
  String? get gender => widget.person['gender'] as String?;
  num? _last(String k) => widget.body.lastWhere((b) => b[k] is num, orElse: () => const {})[k] as num?;
  Exercise _make(CatalogItem e) => exerciseFrom(e, gender: gender, weight: _last('weight'), height: _last('height'));

  Future<void> _custom() async {
    final ctl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('직접 입력'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '운동 이름'),
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('추가'))],
      ),
    );
    if (name != null && name.trim().isNotEmpty && mounted) {
      Navigator.pop(context, [...picked.map(_make), Exercise(name: name.trim())]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _last('weight'), h = _last('height');
    final basis = fmt1(bodyBasis(gender: gender, weight: w, height: h));
    final g = gender == 'm'
        ? '남성'
        : gender == 'f'
        ? '여성'
        : '성별 미입력';
    final body = w != null
        ? '체중 ${fmt1(w.toDouble())}kg'
        : h != null
        ? '키 ${fmt1(h.toDouble())}cm (체중 약 ${basis}kg)'
        : '평균 체중 ${basis}kg';
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              children: [
                Text('운동 추가', style: ts(20, w: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  '무게는 $g · $body 기준 추천값이에요. 추가한 뒤 고칠 수 있어요'
                  '${w == null ? '\n기록 탭에 체중을 남기면 더 정확해져요' : ''}',
                  style: ts(13, color: muted, h: 1.5),
                ),
                const SizedBox(height: 12),
                Wrap(children: [for (final c in catalog.keys) pill(c, cat == c, () => setState(() => cat = c))]),
                const SizedBox(height: 4),
                for (final e in catalog[cat]!) _tile(e),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(Icons.edit, color: muted),
                  title: Text('목록에 없는 운동 직접 입력', style: ts(15, color: sub)),
                  onTap: _custom,
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: FilledButton(
                onPressed: picked.isEmpty ? null : () => Navigator.pop(context, picked.map(_make).toList()),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: Text(picked.isEmpty ? '운동을 골라주세요' : '${picked.length}개 추가'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(CatalogItem e) {
    final on = picked.contains(e), had = widget.have.contains(e.name);
    final x = _make(e);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      onTap: () => setState(() => on ? picked.remove(e) : picked.add(e)),
      leading: ExerciseArt(e.name),
      title: Text(e.name, style: ts(15, w: FontWeight.w600)),
      subtitle: Text(
        [if (x.weight.isNotEmpty) x.weight, '${x.reps}${x.timed ? '' : '회'}', if (had) '이미 있음'].join(' · '),
        style: ts(13, color: muted),
      ),
      trailing: Icon(on ? Icons.check_circle : Icons.add_circle_outline, color: on ? lime : dim),
    );
  }
}
