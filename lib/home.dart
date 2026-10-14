import 'package:flutter/material.dart';

import 'couple.dart';
import 'db.dart';
import 'theme.dart';
import 'workout.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.data, required this.go});
  final AppData data;
  final void Function(int tab) go;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 28, 20, 28), children: [
        Row(children: [
          Expanded(child: Text(dateLabel(DateTime.now()), style: ts(14, color: muted))),
          InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CouplePage())),
            child: Semantics(
              label: '커플 설정',
              child: SizedBox(
                height: 44,
                child: Row(children: [
                  avatar(d.myName, lime, ring: true, look: d.me['avatar']),
                  Transform.translate(
                    offset: const Offset(-10, 0),
                    child: d.partner == null
                        ? Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(color: surf2, shape: BoxShape.circle, border: Border.all(color: bg, width: 2)),
                            child: const Icon(Icons.add, size: 18, color: coral))
                        : avatar(d.paName, coral, ring: true, look: d.partner!['avatar']),
                  ),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        if (activeWorkout.value != null) ...[_activeCard(), const SizedBox(height: 20)],
        ...(d.doneToday ? _done(context) : _todo(context)),
      ]),
    );
  }

  /// Running workout: live clock + current step; tap to jump back to it.
  Widget _activeCard() {
    final w = activeWorkout.value!;
    return ListenableBuilder(
      listenable: w,
      builder: (context, _) {
        final t = w.t;
        final line = t.finished
            ? '운동 끝 · 기록을 저장해 주세요'
            : t.resting
                ? '휴식 ${mmss(t.restLeft.clamp(0, 99999))} · 다음 ${t.current.name}'
                : '${t.current.name} · 세트 ${t.setIdx + 1}/${t.current.sets}';
        return Material(
          color: lime,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => go(1),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('운동 중', style: ts(13, color: ink, w: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${w.r['name']}', style: ts(20, color: ink, w: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(line, style: ts(14, color: ink)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(mmss(t.elapsedSec), style: digits(28, color: ink)),
                  Text('${t.doneSets}/${t.totalSets} 세트', style: ts(12, color: ink)),
                ]),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: ink),
              ]),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _todo(BuildContext context) {
    final d = data, r = d.todayRoutine;
    return [
      h1(activeWorkout.value == null ? '${d.myName}님, 오늘은 아직\n운동 전이에요' : '${d.myName}님, 지금\n운동 중이에요'),
      if (d.partner != null && (d.partnerNudgedToday || d.partnerNotifiedToday)) ...[
        const SizedBox(height: 20),
        box(
          r: 16,
          p: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          c: coral.withValues(alpha: 0.12),
          Text(
              d.partnerNotifiedToday
                  ? '${d.paName}님이 오늘 운동을 끝냈어요. 이제 ${d.myName}님 차례!'
                  : '${d.paName}님이 콕 찔렀어요! 오늘 운동 같이 해요',
              textAlign: TextAlign.center,
              style: ts(15, color: coral, w: FontWeight.w600)),
        ),
      ],
      const SizedBox(height: 20),
      if (activeWorkout.value == null) // running workout already has its card above
      box(
        r: 28,
        p: const EdgeInsets.fromLTRB(20, 28, 20, 16),
        r == null
            ? Column(children: [
                Text('아직 루틴이 없어요', style: ts(18, w: FontWeight.w700)),
                TextButton(onPressed: () => go(1), child: const Text('루틴 만들러 가기')),
              ])
            : Column(children: [
                Text('오늘의 루틴', style: ts(13, color: muted)),
                const SizedBox(height: 6),
                Text(r.data()['name'] ?? '', style: ts(22, w: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(routineMeta(r.data()), style: ts(14, color: muted)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 48, 0, 40),
                  child: Material(
                    color: lime,
                    shape: const CircleBorder(),
                    elevation: 0,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        startWorkout(r, d.partner?['name']);
                        go(1);
                      },
                      child: Container(
                        width: 196,
                        height: 196,
                        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                          BoxShadow(color: lime.withValues(alpha: 0.06), spreadRadius: 26),
                          BoxShadow(color: lime.withValues(alpha: 0.14), spreadRadius: 12),
                        ]),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.play_arrow_rounded, size: 48, color: ink),
                          Text('운동 시작', style: ts(24, color: ink, w: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ),
                ),
                TextButton(onPressed: () => go(1), child: const Text('다른 루틴 고르기')),
              ]),
      ),
      const SizedBox(height: 20),
      if (d.partner == null)
        tapBox(
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CouplePage())),
          _iconRow(Icons.favorite_border, '짝꿍을 연결해 보세요', '서로의 운동 기록을 보고 루틴을 짜줄 수 있어요'),
        )
      else if (!d.partnerNotifiedToday)
        box(r: 20, p: const EdgeInsets.all(18),
            _iconRow(Icons.lock_outline, '${d.paName}님의 오늘 기록은 잠겨 있어요', '내 운동을 끝내면 짝꿍이 오늘 운동했는지 볼 수 있어요')),
    ];
  }

  Widget _iconRow(IconData icon, String title, String body) => Row(children: [
        Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: surf2, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: coral)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: ts(15, w: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(body, style: ts(13, color: muted, h: 1.5)),
          ]),
        ),
      ]);

  List<Widget> _done(BuildContext context) {
    final d = data, today = todayKey();
    final mine = d.mineOn(today).first, paToday = d.partnerOn(today), last = d.partnerLast;
    final paDone = paToday.isNotEmpty;
    Widget tile(String name, String who, Color c, bool done, String line, Map? look) => Expanded(
          child: box(
            r: 18,
            p: const EdgeInsets.all(16),
            c: surf2,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [avatar(name, c, size: 28, look: look), const SizedBox(width: 8), Text(who, style: ts(14, w: FontWeight.w600))]),
              const SizedBox(height: 10),
              Row(children: [
                Icon(done ? checkIcon : Icons.schedule, size: 18, color: done ? c : sub),
                const SizedBox(width: 6),
                Text(done ? '완료' : '아직 전', style: ts(16, w: FontWeight.w700, color: done ? c : sub)),
              ]),
              const SizedBox(height: 10),
              Text(line, style: ts(13, color: muted), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
        );

    return [
      Row(children: [
        const CircleAvatar(radius: 20, backgroundColor: lime, child: Icon(checkIcon, color: ink)),
        const SizedBox(width: 12),
        Text('오늘 운동 완료!', style: ts(28, w: FontWeight.w700)),
      ]),
      const SizedBox(height: 8),
      Text('${mine['routine']} · ${mmss(mine['totalSec'] ?? 0)} · ${mine['sets']}세트 · 휴식 ${mmss(mine['restSec'] ?? 0)}',
          style: ts(14, color: muted)),
      const SizedBox(height: 20),
      box(
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('오늘 우리 둘', style: ts(13, color: muted)),
          const SizedBox(height: 16),
          Row(children: [
            tile(d.myName, '나', lime, true, summary(mine), d.me['avatar']),
            const SizedBox(width: 12),
            if (d.partner != null)
              tile(d.paName, d.paName, coral, paDone,
                  paDone ? summary(paToday.first) : (last == null ? '기록 없음' : '${relDay(last['date'])} ${summary(last)}'),
                  d.partner!['avatar'])
            else
              const Expanded(child: SizedBox()),
          ]),
          if (d.partner != null) ...[
            const SizedBox(height: 16),
            if (!paDone)
              FilledButton(
                onPressed: d.nudgedToday ? null : () => userDoc(myUid).update({'nudgeAt': today}),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: coral,
                    disabledBackgroundColor: surf2,
                    disabledForegroundColor: coral,
                    textStyle: ts(16, w: FontWeight.w700)),
                child: Text(d.nudgedToday ? '${d.paName}님에게 응원을 보냈어요' : '${d.paName}님 콕 찌르기'),
              )
            else
              box(
                r: 16,
                p: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                c: lime.withValues(alpha: 0.10),
                Text('오늘은 둘 다 운동 완료! 함께 ${d.streak}일 연속',
                    textAlign: TextAlign.center, style: ts(15, color: lime, w: FontWeight.w600)),
              ),
          ],
        ]),
      ),
      const SizedBox(height: 20),
      _week(),
    ];
  }

  Widget _week() {
    final now = DateTime.now();
    final sunday = DateTime(now.year, now.month, now.day - now.weekday % 7);
    final today = todayKey();
    return box(
      p: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      Column(children: [
        Row(children: [
          Expanded(child: Text('이번 주', style: ts(15, w: FontWeight.w600))),
          legend(lime, '나'),
          if (data.partner != null) ...[const SizedBox(width: 12), legend(coral, data.paName)],
        ]),
        const SizedBox(height: 14),
        Row(children: [
          for (var i = 0; i < 7; i++)
            Builder(builder: (_) {
              final day = DateTime(sunday.year, sunday.month, sunday.day + i), k = dayKey(day);
              final future = k.compareTo(today) > 0;
              return Expanded(
                child: Column(children: [
                  Text(weekdays[i], style: ts(12, color: muted)),
                  const SizedBox(height: 6),
                  Text('${day.day}', style: digits(15, color: k == today ? lime : (future ? dim : fg))),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    dot(!future && data.mineOn(k).isNotEmpty ? lime : off),
                    if (data.partner != null) ...[
                      const SizedBox(width: 3),
                      dot(!future && data.partnerOn(k).isNotEmpty ? coral : off),
                    ],
                  ]),
                ]),
              );
            }),
        ]),
        TextButton(onPressed: () => go(2), child: const Text('캘린더에서 자세히 보기')),
      ]),
    );
  }
}
