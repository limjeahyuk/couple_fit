import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'db.dart';
import 'theme.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.data});
  final AppData data;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String sel = todayKey();

  @override
  Widget build(BuildContext context) {
    final d = widget.data, today = todayKey(), hasPa = d.partner != null;
    final days = DateTime(month.year, month.month + 1, 0).day, lead = month.weekday % 7;
    final keys = [for (var i = 1; i <= days; i++) dayKey(DateTime(month.year, month.month, i))];
    final meCount = keys.where((k) => d.mineOn(k).isNotEmpty).length;
    final paCount = keys.where((k) => d.partnerOn(k).isNotEmpty).length;
    final bothCount = keys.where(d.both).length;

    Widget stat(String who, String v, String unit, Color c) => Expanded(
          child: box(
            r: 18,
            p: const EdgeInsets.all(14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(who, style: ts(12, color: muted)),
              const SizedBox(height: 4),
              Text.rich(TextSpan(style: ts(22, w: FontWeight.w700, color: c), children: [
                TextSpan(text: v, style: digits(22, color: c)),
                TextSpan(text: unit),
              ])),
            ]),
          ),
        );

    Widget cell(String k, int n) {
      final me = d.mineOn(k).isNotEmpty, pa = d.partnerOn(k).isNotEmpty, future = k.compareTo(today) > 0;
      return Material(
        color: me && pa ? lime.withValues(alpha: 0.16) : Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: k == sel ? fg : Colors.transparent, width: 1.5)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => sel = k),
          child: Semantics(
            label: '${month.month}월 $n일${me ? ', 나 운동함' : ''}${pa ? ', ${d.paName} 운동함' : ''}',
            selected: k == sel,
            button: true,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$n',
                  style: digits(15,
                      w: k == today ? FontWeight.w700 : FontWeight.w500, color: k == today ? lime : (future ? dim : fg))),
              const SizedBox(height: 5),
              if (!future)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  dot(me ? lime : off, 6),
                  if (hasPa) ...[const SizedBox(width: 3), dot(pa ? coral : off, 6)],
                ])
              else
                const SizedBox(height: 6),
            ]),
          ),
        ),
      );
    }

    final selDate = DateTime.parse(sel);
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 28, 20, 28), children: [
        Row(children: [
          Expanded(child: h1('캘린더')),
          IconButton(
              tooltip: '이전 달',
              onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left, color: sub)),
          Text('${month.year}년 ${month.month}월', style: ts(16, w: FontWeight.w600, color: sub)),
          IconButton(
              tooltip: '다음 달',
              onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right, color: sub)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          stat('나', '$meCount', '회', lime),
          if (hasPa) ...[
            const SizedBox(width: 10),
            stat(d.paName, '$paCount', '회', coral),
            const SizedBox(width: 10),
            stat('함께', '$bothCount', '일', fg),
          ],
        ]),
        const SizedBox(height: 16),
        box(
          p: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          Column(children: [
            Row(children: [
              for (final w in weekdays) Expanded(child: Text(w, textAlign: TextAlign.center, style: ts(12, color: muted))),
            ]),
            const SizedBox(height: 8),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7, mainAxisExtent: 50, mainAxisSpacing: 4, crossAxisSpacing: 4),
              children: [
                for (var i = 0; i < lead; i++) const SizedBox(),
                for (var i = 0; i < days; i++) cell(keys[i], i + 1),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 14, alignment: WrapAlignment.center, children: [
              legend(lime, '나'),
              if (hasPa) ...[
                legend(coral, d.paName),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: lime.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 5),
                  Text('둘 다', style: ts(12, color: muted)),
                ]),
              ],
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        box(
          p: const EdgeInsets.all(18),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${dateLabel(selDate)}${sel == today ? ' · 오늘' : ''}', style: ts(16, w: FontWeight.w700)),
            const SizedBox(height: 14),
            if (sel.compareTo(today) > 0)
              Text('아직 오지 않은 날이에요', style: ts(14, color: muted))
            else ...[
              _row(d.myName, '나', lime, d.mineOn(sel), false, d.me['avatar'], mine: true),
              if (hasPa) ...[
                const SizedBox(height: 14),
                _row(d.paName, d.paName, coral, d.partnerOn(sel), sel == today && d.locked, d.partner!['avatar']),
              ],
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _row(String name, String who, Color c, List<Json> sessions, bool locked, Map? look, {bool mine = false}) {
    final done = sessions.isNotEmpty;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      avatar(name, c, size: 32, look: look),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(who, style: ts(12, color: muted)),
          const SizedBox(height: 2),
          if (locked || !done)
            Text(locked ? '내 운동을 끝내면 볼 수 있어요' : '쉬는 날', style: ts(15, w: FontWeight.w600))
          else
            // One line per workout ("하체 데이 · 40분"); the sets are a tap away.
            for (final s in sessions)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => showSessionDetail(context, s, who: who, routine: mine ? widget.data.routineOf(s) : null),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Flexible(child: Text(summary(s), style: ts(15, w: FontWeight.w600))),
                    const Icon(Icons.chevron_right, size: 18, color: muted),
                  ]),
                ),
              ),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(color: done ? c.withValues(alpha: 0.14) : surf2, borderRadius: BorderRadius.circular(10)),
        child: Text(locked ? '잠김' : (done ? '완료' : '휴식'), style: ts(12, w: FontWeight.w700, color: done ? c : muted)),
      ),
    ]);
  }
}

/// One workout's record: time, sets, rest, and what was lifted set by set.
/// With [routine] (my own sessions): if the routine now differs from what was done, offer to overwrite it.
Future<void> showSessionDetail(BuildContext context, Json s, {required String who, QueryDocumentSnapshot<Json>? routine}) {
  final lines = logLines(s['log'] as List?);
  // What the routine would become, and how that differs from it now ("바벨 스쿼트  4세트 × 8회 · 60kg → 60kg×8 · …").
  final before = routine == null ? <Exercise>[] : exercisesOf(routine.data());
  final after = routine == null || lines.isEmpty ? before : routineFromLog(before, s['log'] as List?);
  final diff = [
    for (final e in after)
      if (before.where((b) => b.name == e.name).firstOrNull case final b)
        if (b == null)
          '${e.name}  추가 · ${e.label}'
        else if (jsonEncode(b.toMap()) != jsonEncode(e.toMap()))
          '${e.name}  ${b.label} → ${e.label}',
  ];
  var saved = false;

  Future<void> overwrite(BuildContext c, StateSetter set) async {
    final ok = await showDialog<bool>(
      context: c,
      builder: (d) => AlertDialog(
        title: Text('${routine!.data()['name']} 루틴을 덮어쓸까요?'),
        content: const Text('이 기록에서 한 세트·횟수·무게로 루틴이 바뀌어요'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('취소', style: TextStyle(color: sub))),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('덮어쓰기')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await routine!.reference.update({'exercises': after.map((e) => e.toMap()).toList()});
      set(() => saved = true);
    } catch (_) {
      if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('루틴을 바꾸지 못했어요')));
    }
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (c) {
      Widget stat(String v, String label) => Expanded(
        child: Column(
          children: [
            Text(v, style: digits(20)),
            const SizedBox(height: 2),
            Text(label, style: ts(12, color: muted)),
          ],
        ),
      );
      return StatefulBuilder(
        builder: (c, set) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
            children: [
              Text('$who · ${dateLabel(DateTime.parse(s['date']))}', style: ts(13, color: muted)),
              const SizedBox(height: 4),
              Text('${s['routine']}', style: ts(22, w: FontWeight.w700)),
              const SizedBox(height: 16),
              box(
                r: 18,
                p: const EdgeInsets.symmetric(vertical: 14),
                c: surf2,
                Row(
                  children: [
                    stat(mmss(s['totalSec'] ?? 0), '운동 시간'),
                    stat('${s['sets'] ?? 0}', '세트'),
                    stat(mmss(s['restSec'] ?? 0), '휴식'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (lines.isEmpty)
                Text('세트 기록이 없는 운동이에요', style: ts(14, color: muted))
              else
                for (final l in lines)
                  // "벤치프레스 · 40kg × 10·10·8" → name, then the sets underneath.
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.split(' · ').first, style: ts(15, w: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(l.split(' · ').skip(1).join(' · '), style: ts(13, color: sub)),
                      ],
                    ),
                  ),
              // Only when the saved routine no longer matches this record.
              if (diff.isNotEmpty && !saved) ...[
                const SizedBox(height: 4),
                box(
                  r: 18,
                  p: const EdgeInsets.all(16),
                  c: surf2,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('지금 루틴과 다른 점', style: ts(13, color: muted)),
                      const SizedBox(height: 8),
                      for (final d in diff)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(d, style: ts(13, h: 1.4)),
                        ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => overwrite(c, set),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: lime,
                          side: const BorderSide(color: lime, width: 1.5),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: const Icon(Icons.sync, size: 18),
                        label: Text('${routine!.data()['name']} 루틴 덮어쓰기'),
                      ),
                    ],
                  ),
                ),
              ],
              if (saved)
                Row(
                  children: [
                    const Icon(checkIcon, size: 18, color: lime),
                    const SizedBox(width: 6),
                    Text('루틴을 이 기록대로 바꿨어요', style: ts(14, color: lime, w: FontWeight.w600)),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
}
