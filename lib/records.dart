import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'db.dart';
import 'theme.dart';

/// 기록 tab: body measurements (InBody-style summary, trend chart, partner comparison) and workout history.
class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key, required this.data});
  final AppData data;

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  bool body = true, compare = true;
  bool relative = false; // chart: each person's change since their first measurement
  String who = 'both'; // 운동 기록 filter: both | me | partner
  int metric = 0;

  AppData get d => widget.data;
  bool get hasPartner => d.partner != null;

  void _openForm([Json? entry]) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => BodyForm(entry: entry, lastHeight: d.myBody.isEmpty ? null : d.myBody.last['height'] as num?),
  );

  Widget _chip(String label, bool on, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8, bottom: 8),
    child: Material(
      color: on ? lime : surf2,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          // widthFactor 1: center vertically but stay as wide as the label (alignment alone fills the row).
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: ts(13, w: FontWeight.w600, color: on ? ink : sub),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        children: [
          Row(
            children: [
              Expanded(child: h1('기록')),
              if (body)
                IconButton(
                  tooltip: '측정 입력',
                  onPressed: _openForm,
                  style: IconButton.styleFrom(backgroundColor: surf, fixedSize: const Size(44, 44)),
                  icon: const Icon(Icons.add, color: lime),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: surf, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                for (final (label, on) in [('몸 기록', true), ('운동 기록', false)])
                  Expanded(
                    child: Material(
                      color: body == on ? surf2 : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => body = on),
                        child: SizedBox(
                          height: 40,
                          child: Center(
                            child: Text(
                              label,
                              style: ts(14, w: FontWeight.w600, color: body == on ? fg : muted),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...(body ? _bodyView() : _workoutView()),
        ],
      ),
    );
  }

  // ---------- body ----------

  List<Widget> _bodyView() {
    final mine = d.myBody;
    if (mine.isEmpty) {
      return [
        box(
          Column(
            children: [
              Text('아직 측정 기록이 없어요', style: ts(18, w: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                '키, 체중, 체지방률을 입력하면\n변화를 그래프로 보여드려요',
                textAlign: TextAlign.center,
                style: ts(14, color: muted, h: 1.5),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _openForm, child: const Text('첫 측정 입력')),
            ],
          ),
        ),
        if (hasPartner && d.paBody.isNotEmpty) ...[
          const SizedBox(height: 16),
          _chart(),
          const SizedBox(height: 16),
          _history('${d.paName}님 측정 기록', d.paBody),
        ],
      ];
    }
    final last = mine.last, prev = mine.length > 1 ? mine[mine.length - 2] : null;
    return [
      _latest(last, prev),
      const SizedBox(height: 16),
      _chart(),
      if (hasPartner && d.paBody.isNotEmpty) ...[const SizedBox(height: 16), _compare(last, d.paBody.last)],
      const SizedBox(height: 16),
      _history('내 측정 기록', mine, editable: true),
      if (hasPartner && d.paBody.isNotEmpty) ...[const SizedBox(height: 16), _history('${d.paName}님 측정 기록', d.paBody)],
    ];
  }

  Widget _latest(Json last, Json? prev) {
    final weight = bodyMetrics.first;
    Widget tile(Metric m) {
      final v = m.of(last);
      return Expanded(
        child: box(
          r: 16,
          c: surf2,
          p: const EdgeInsets.all(14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.label, style: ts(12, color: muted)),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: v == null ? '-' : fmt1(v), style: digits(20)),
                    TextSpan(
                      text: v == null ? '' : ' ${m.unit}',
                      style: ts(12, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(prev == null ? ' ' : delta(v, m.of(prev)), style: ts(12, color: sub)),
            ],
          ),
        ),
      );
    }

    final rest = bodyMetrics.skip(1).toList();
    return box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${dateLabel(DateTime.parse(last['date']))} 측정', style: ts(13, color: muted)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(fmt1(weight.of(last)!), style: digits(44)),
              Text(' kg', style: ts(16, color: muted)),
            ],
          ),
          if (prev != null) Text('지난 측정 대비 ${delta(weight.of(last), weight.of(prev))}', style: ts(13, color: sub)),
          const SizedBox(height: 16),
          Row(children: [tile(rest[0]), const SizedBox(width: 10), tile(rest[1])]),
          const SizedBox(height: 10),
          Row(children: [tile(rest[2]), const SizedBox(width: 10), tile(rest[3])]),
        ],
      ),
    );
  }

  static double _x(Object? date) => DateTime.parse('$date').millisecondsSinceEpoch / Duration.millisecondsPerDay;

  Widget _chart() {
    final m = bodyMetrics[metric];
    List<FlSpot> spots(List<Json> list) => [
      for (final b in list)
        if (m.of(b) case final v?) FlSpot(_x(b['date']), v),
    ];
    // "처음 대비": shift each person's line so their own first measurement sits at 0.
    List<FlSpot> rebase(List<FlSpot> s) => relative ? [for (final p in s) FlSpot(p.x, p.y - s.first.y)] : s;
    // Series kept with their own name/color so identity never depends on which one is empty.
    // (name, color, plotted spots, raw spots for the tooltip)
    final series = [
      ('나', chartMe, spots(d.myBody)),
      if (hasPartner && compare) (d.paName, chartPartner, spots(d.paBody)),
    ].where((s) => s.$3.isNotEmpty).map((s) => (s.$1, s.$2, rebase(s.$3), s.$3)).toList();
    final all = [for (final s in series) ...s.$3];

    Widget plot;
    if (all.isEmpty) {
      plot = SizedBox(
        height: 200,
        child: Center(
          child: Text('${m.label} 기록이 아직 없어요', style: ts(14, color: muted)),
        ),
      );
    } else {
      var minX = all.map((s) => s.x).reduce((a, b) => a < b ? a : b),
          maxX = all.map((s) => s.x).reduce((a, b) => a > b ? a : b);
      var minY = all.map((s) => s.y).reduce((a, b) => a < b ? a : b),
          maxY = all.map((s) => s.y).reduce((a, b) => a > b ? a : b);
      if (maxX - minX < 1) (minX, maxX) = (minX - 1, maxX + 1);
      if (relative) (minY, maxY) = (minY < 0 ? minY : 0, maxY > 0 ? maxY : 0); // keep the 0 line in view
      final padY = (maxY - minY) < 1 ? 1.0 : (maxY - minY) * 0.15;
      (minY, maxY) = (minY - padY, maxY + padY);
      plot = SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minX: minX,
            baselineX: minX, // x labels count from the first measurement, not from 0
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(color: off, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              // Empty right gutter so the last date label isn't clipped at the card edge.
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 16, getTitlesWidget: (_, _) => const SizedBox()),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (v, meta) => v == meta.max || v == meta.min
                      ? const SizedBox()
                      : Text(relative ? signed(v) : fmt1(v), style: ts(11, color: muted)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  // 4 equal steps → 5 evenly spaced dates (first … last); never under a day apart.
                  interval: (maxX - minX) / 4 < 1 ? 1 : (maxX - minX) / 4,
                  getTitlesWidget: (v, meta) {
                    // Rounding can add a second label a hair before the max; draw only one of them.
                    if (v != meta.max && (meta.max - v).abs() < (maxX - minX) / 400) return const SizedBox();
                    final t = DateTime.fromMillisecondsSinceEpoch((v * Duration.millisecondsPerDay).round());
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('${t.month}/${t.day}', style: ts(11, color: muted)),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => surf2,
                getTooltipItems: (touched) => [
                  for (final t in touched)
                    LineTooltipItem(
                      relative
                          ? '${series[t.barIndex].$1} ${signed(t.y)}${m.unit} (실제 ${fmt1(series[t.barIndex].$4[t.spotIndex].y)}${m.unit})'
                          : '${series[t.barIndex].$1} ${fmt1(t.y)}${m.unit}',
                      ts(12, w: FontWeight.w600),
                    ),
                ],
              ),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                if (relative) HorizontalLine(y: 0, color: sub, strokeWidth: 1, dashArray: const [4, 4]),
              ],
            ),
            lineBarsData: [
              for (final (_, color, pts, _) in series)
                LineChartBarData(
                  spots: pts,
                  color: color,
                  barWidth: 2,
                  dotData: FlDotData(
                    getDotPainter: (_, _, _, _) =>
                        FlDotCirclePainter(radius: 4, color: color, strokeWidth: 2, strokeColor: surf),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return box(
      p: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('변화 그래프', style: ts(15, w: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            children: [
              for (var i = 0; i < bodyMetrics.length; i++)
                _chip(bodyMetrics[i].label, metric == i, () => setState(() => metric = i)),
            ],
          ),
          // How to read the values: as measured, or each person's change from their first measurement.
          Row(
            children: [
              for (final (label, on) in [('실제 값', false), ('처음 대비 변화', true)])
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: TextButton(
                    onPressed: () => setState(() => relative = on),
                    style: TextButton.styleFrom(
                      foregroundColor: relative == on ? fg : muted,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: ts(13, w: relative == on ? FontWeight.w700 : FontWeight.w500),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (relative == on) ...[dot(fg, 6), const SizedBox(width: 6)],
                        Text(label),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (relative)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Text('각자 첫 측정을 0으로 맞춘 변화량이에요', style: ts(12, color: muted)),
            ),
          const SizedBox(height: 8),
          plot,
          const SizedBox(height: 8),
          Row(
            children: [
              // Legend wraps if names are long; the compare switch keeps its own slot.
              Expanded(
                child: Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [legend(chartMe, '나'), if (hasPartner && compare) legend(chartPartner, d.paName)],
                ),
              ),
              if (hasPartner) ...[
                Text('비교', style: ts(12, color: sub)),
                const SizedBox(width: 8),
                // Smaller than the default switch so it doesn't outweigh the legend.
                SizedBox(
                  height: 28, // FittedBox shrinks the layout too, so it sits flush right (Transform.scale wouldn't)
                  child: FittedBox(
                    child: Switch(
                      value: compare,
                      onChanged: (v) => setState(() => compare = v),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _compare(Json mine, Json theirs) {
    Widget row(String who, double? v, double maxV, Color c, String unit) => Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            who,
            style: ts(12, color: sub),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(child: bar(v == null || maxV <= 0 ? 0 : v / maxV, c, h: 8)),
        SizedBox(
          width: 70,
          child: Text(v == null ? '-' : '${fmt1(v)}$unit', textAlign: TextAlign.right, style: digits(13)),
        ),
      ],
    );
    return box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${d.paName}님과 비교', style: ts(15, w: FontWeight.w700)),
              ),
              Text('각자 최근 측정 기준', style: ts(12, color: muted)),
            ],
          ),
          const SizedBox(height: 14),
          for (final m in bodyMetrics)
            if (m.of(mine) != null || m.of(theirs) != null)
              Builder(
                builder: (_) {
                  final a = m.of(mine), b = m.of(theirs);
                  final maxV = [a ?? 0, b ?? 0].reduce((x, y) => x > y ? x : y);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.label, style: ts(12, color: muted)),
                        const SizedBox(height: 6),
                        row('나', a, maxV, chartMe, m.unit),
                        const SizedBox(height: 4),
                        row(d.paName, b, maxV, chartPartner, m.unit),
                      ],
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }

  /// Measurement list, newest first. Only my own entries open the editor.
  Widget _history(String title, List<Json> list, {bool editable = false}) {
    String line(Json b) {
      String? part(int i, String prefix) {
        final v = bodyMetrics[i].of(b);
        return v == null ? null : '$prefix${fmt1(v)}${bodyMetrics[i].unit}';
      }

      return [part(0, ''), part(1, '체지방 '), part(2, '근육 ')].whereType<String>().join(' · ');
    }

    return box(
      p: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(title, style: ts(15, w: FontWeight.w700)),
          ),
          for (final b in list.reversed)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(dateLabel(DateTime.parse(b['date'])), style: ts(14, w: FontWeight.w600)),
              subtitle: Text(line(b), style: ts(13, color: muted)),
              trailing: editable ? const Icon(Icons.chevron_right, color: muted) : null,
              onTap: editable ? () => _openForm(b) : null,
            ),
        ],
      ),
    );
  }

  // ---------- workouts ----------

  List<Widget> _workoutView() {
    final w = hasPartner ? who : 'me';
    // Partner's today stays hidden until I finish mine (same rule as home/calendar).
    final theirs = d.paSessions.where((s) => !(d.locked && s['date'] == todayKey()));
    final list = [
      if (w != 'partner')
        for (final s in d.mySessions) (s, true),
      if (w != 'me')
        for (final s in theirs) (s, false),
    ]..sort((a, b) => '${b.$1['date']}'.compareTo('${a.$1['date']}')); // stable: same day keeps me first
    return [
      if (hasPartner)
        Wrap(
          children: [
            _chip('함께', w == 'both', () => setState(() => who = 'both')),
            _chip('나', w == 'me', () => setState(() => who = 'me')),
            _chip(d.paName, w == 'partner', () => setState(() => who = 'partner')),
          ],
        ),
      if (list.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text('아직 운동 기록이 없어요', style: ts(14, color: muted)),
        ),
      for (final (s, mine) in list.take(80))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: box(
            r: 18,
            p: const EdgeInsets.all(16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (w == 'both') ...[
                      mine
                          ? avatar(d.myName, lime, size: 22, look: d.me['avatar'])
                          : avatar(d.paName, coral, size: 22, look: d.partner!['avatar']),
                      const SizedBox(width: 6),
                      Text(mine ? '나' : d.paName, style: ts(13, w: FontWeight.w600)),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(dateLabel(DateTime.parse(s['date'])), style: ts(13, color: muted)),
                    ),
                    Text(relDay(s['date']), style: ts(12, color: muted)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${s['routine']}', style: ts(16, w: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  '${mmss(s['totalSec'] ?? 0)} · ${s['sets'] ?? 0}세트 · 휴식 ${mmss(s['restSec'] ?? 0)}',
                  style: ts(13, color: sub),
                ),
                for (final l in logLines(s['log'] as List?))
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(l, style: ts(12, color: muted)),
                  ),
              ],
            ),
          ),
        ),
    ];
  }
}

/// Add or edit one day's measurement (one per day; changing the date moves it).
class BodyForm extends StatefulWidget {
  const BodyForm({super.key, this.entry, this.lastHeight});
  final Json? entry;
  final num? lastHeight;

  @override
  State<BodyForm> createState() => _BodyFormState();
}

class _BodyFormState extends State<BodyForm> {
  late DateTime date = widget.entry == null ? DateTime.now() : DateTime.parse(widget.entry!['date']);
  late final height = TextEditingController(text: _s(widget.entry?['height'] ?? widget.lastHeight));
  late final weight = TextEditingController(text: _s(widget.entry?['weight']));
  late final fat = TextEditingController(text: _s(widget.entry?['fat']));
  late final muscle = TextEditingController(text: _s(widget.entry?['muscle']));
  String? error;
  bool saving = false;

  static String _s(Object? v) => v is num ? fmt1(v.toDouble()) : '';
  static double? _p(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    final h = _p(height), w = _p(weight), f = _p(fat), m = _p(muscle);
    String? bad(double? v, String label, double lo, double hi, {bool required = false}) =>
        v == null ? (required ? '$label을 입력하세요' : null) : (v < lo || v > hi ? '$label 값을 확인해 주세요' : null);
    final problem =
        bad(w, '체중', 20, 300, required: true) ??
        bad(h, '키', 100, 250) ??
        bad(f, '체지방률', 1, 70) ??
        bad(m, '골격근량', 5, 100);
    if (problem != null) return setState(() => error = problem);
    setState(() => saving = true);
    final key = dayKey(date), old = widget.entry?['date'] as String?;
    final batch = fs.batch()
      ..set(bodyOf(myUid).doc(key), {'date': key, 'weight': w, 'height': ?h, 'fat': ?f, 'muscle': ?m});
    if (old != null && old != key) batch.delete(bodyOf(myUid).doc(old));
    await batch.commit();
    if (mounted) Navigator.pop(context);
  }

  Widget _field(String label, TextEditingController c, String suffix) => Expanded(
    child: TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(entry == null ? '측정 입력' : '측정 수정', style: ts(18, w: FontWeight.w700)),
              ),
              if (entry != null)
                IconButton(
                  tooltip: '삭제',
                  icon: const Icon(Icons.delete_outline, color: muted),
                  onPressed: () async {
                    await bodyOf(myUid).doc(entry['date']).delete();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            style: TextButton.styleFrom(alignment: Alignment.centerLeft, foregroundColor: fg),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => date = picked);
            },
            icon: const Icon(Icons.event, size: 18, color: lime),
            label: Text(dateLabel(date), style: ts(15, w: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Row(children: [_field('키', height, 'cm'), const SizedBox(width: 10), _field('체중 *', weight, 'kg')]),
          const SizedBox(height: 10),
          Row(children: [_field('체지방률', fat, '%'), const SizedBox(width: 10), _field('골격근량', muscle, 'kg')]),
          const SizedBox(height: 8),
          Text('인바디 결과지의 체중 · 체지방률 · 골격근량을 그대로 옮겨 적으면 돼요', style: ts(12, color: muted)),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: ts(13, color: coral, w: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: saving ? null : _save, child: const Text('저장')),
        ],
      ),
    );
  }
}
