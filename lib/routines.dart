import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'db.dart';
import 'theme.dart';
import 'workout.dart';

/// Routines of [uid]. Mine: start / edit. Partner's ([uid] != me): build routines for them.
class RoutinesPage extends StatelessWidget {
  const RoutinesPage({super.key, required this.data, required this.uid});
  final AppData data;
  final String uid;

  bool get mine => uid == myUid;

  void _edit(BuildContext context, [QueryDocumentSnapshot<Json>? doc]) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => RoutineEditor(col: routinesOf(uid), doc: doc, myName: data.myName)));

  @override
  Widget build(BuildContext context) {
    final pa = data.partner, last = data.partnerLast;
    final list = ListView(padding: const EdgeInsets.fromLTRB(20, 28, 20, 28), children: [
      Row(children: [
        Expanded(child: h1(mine ? '운동 루틴' : '${data.paName}님 루틴')),
        IconButton(
            tooltip: '루틴 추가',
            onPressed: () => _edit(context),
            style: IconButton.styleFrom(backgroundColor: surf, fixedSize: const Size(44, 44)),
            icon: const Icon(Icons.add, color: lime)),
      ]),
      const SizedBox(height: 10),
      Text(mine ? '루틴을 고르면 세트 기록과 휴식 타이머가 앱 안에서 이어서 진행돼요' : '짝꿍의 루틴을 대신 짜주거나 고쳐줄 수 있어요',
          style: ts(14, color: muted, h: 1.5)),
      const SizedBox(height: 16),
      StreamBuilder(
        stream: routinesOf(uid).orderBy('createdAt').snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          if (snap.hasData && docs.isEmpty) {
            return Padding(padding: const EdgeInsets.all(24), child: Text('루틴이 없어요. + 로 만들어보세요', style: ts(14, color: muted)));
          }
          return Column(children: [for (final d in docs) _card(context, d)]);
        },
      ),
      if (mine && pa != null) ...[
        if (last != null)
          box(
            r: 20,
            p: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            Row(children: [
              avatar(data.paName, coral, size: 32, look: pa['avatar']),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                    TextSpan(style: ts(14, color: sub, h: 1.5), children: [
                      TextSpan(text: '${data.paName}님은 ${relDay(last['date'])} '),
                      TextSpan(text: '${last['routine']}', style: ts(14, w: FontWeight.w700)),
                      TextSpan(text: '를 ${((last['totalSec'] ?? 0) / 60).round()}분 동안 했어요'),
                    ])),
              ),
            ]),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => RoutinesPage(data: data, uid: pa['uid']))),
          style: OutlinedButton.styleFrom(
              foregroundColor: coral,
              side: const BorderSide(color: coral, width: 1.5),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          icon: const Icon(Icons.favorite, size: 18),
          label: Text('${data.paName}님 루틴 짜주기'),
        ),
      ],
    ]);
    return Scaffold(appBar: mine ? null : AppBar(), body: SafeArea(child: list));
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
            side: BorderSide(color: today ? lime.withValues(alpha: 0.5) : Colors.transparent, width: 1.5)),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _edit(context, d),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (today) Text('오늘 추천', style: ts(12, color: lime, w: FontWeight.w700)),
                    if (gift) Text('${r['by']}님이 짜준 루틴', style: ts(12, color: coral, w: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(r['name'] ?? '', style: ts(18, w: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(routineMeta(r), style: ts(13, color: muted)),
                  ]),
                ),
                if (mine)
                  FilledButton(
                    onPressed: () => startWorkout(d, data.partner?['name']),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: const StadiumBorder(),
                        textStyle: ts(14, w: FontWeight.w700)),
                    child: const Text('시작'),
                  ),
              ]),
              const SizedBox(height: 12),
              Text(exercisesOf(r).map((e) => e.name).join(' · '), style: ts(13, color: sub, h: 1.6)),
            ]),
          ),
        ),
      ),
    );
  }
}

class RoutineEditor extends StatefulWidget {
  const RoutineEditor({super.key, required this.col, this.doc, required this.myName});
  final CollectionReference<Json> col;
  final QueryDocumentSnapshot<Json>? doc;
  final String myName;

  @override
  State<RoutineEditor> createState() => _RoutineEditorState();
}

class _RoutineEditorState extends State<RoutineEditor> {
  late String name = widget.doc?.data()['name'] ?? '', tag = widget.doc?.data()['tag'] ?? '';
  late final List<Exercise> items = widget.doc == null ? [Exercise()] : exercisesOf(widget.doc!.data());

  Future<void> _save() async {
    final ex = items.where((e) => e.name.trim().isNotEmpty && e.sets > 0).toList();
    if (name.trim().isEmpty || ex.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('루틴 이름과 운동을 1개 이상 입력하세요')));
      return;
    }
    final data = {'name': name.trim(), 'tag': tag.trim(), 'exercises': ex.map((e) => e.toMap()).toList()};
    await (widget.doc == null
        ? widget.col.add({...data, 'by': widget.myName, 'createdAt': FieldValue.serverTimestamp()})
        : widget.doc!.reference.update(data));
    if (mounted) Navigator.pop(context);
  }

  Widget _field(String label, String value, void Function(String) set, {bool number = false}) => TextFormField(
        initialValue: value,
        keyboardType: number ? TextInputType.number : null,
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: set,
      );

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
                }),
          TextButton(onPressed: _save, child: const Text('저장')),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(20), keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, children: [
        _field('루틴 이름 (예: 하체 데이)', name, (v) => name = v),
        const SizedBox(height: 10),
        _field('부위 (예: 허벅지·둔근)', tag, (v) => tag = v),
        const SizedBox(height: 16),
        for (final e in items)
          Padding(
            key: ObjectKey(e),
            padding: const EdgeInsets.only(bottom: 12),
            child: box(
              r: 20,
              p: const EdgeInsets.fromLTRB(16, 8, 8, 16),
              Column(children: [
                Row(children: [
                  Expanded(child: _field('운동', e.name, (v) => e.name = v)),
                  IconButton(
                      tooltip: '운동 삭제', icon: const Icon(Icons.close, color: muted), onPressed: () => setState(() => items.remove(e))),
                ]),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(children: [
                    Expanded(child: _field('세트', '${e.sets}', (v) => e.sets = int.tryParse(v) ?? 0, number: true)),
                    const SizedBox(width: 6),
                    Expanded(child: _field('횟수/시간', e.reps, (v) => e.reps = v)),
                    const SizedBox(width: 6),
                    Expanded(child: _field('무게', e.weight, (v) => e.weight = v)),
                    const SizedBox(width: 6),
                    Expanded(child: _field('휴식(초)', '${e.restSec}', (v) => e.restSec = int.tryParse(v) ?? 0, number: true)),
                  ]),
                ),
              ]),
            ),
          ),
        TextButton.icon(
            onPressed: () => setState(() => items.add(Exercise())), icon: const Icon(Icons.add), label: const Text('운동 추가')),
      ]),
    );
  }
}
