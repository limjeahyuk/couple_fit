import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Simple stick-figure illustrations for the exercise catalog, animated between two keyframes.
/// Canvas is 120 × 100 units; the floor is at y = 92. Angles are degrees in screen space:
/// 0 = right (the way the figure faces), 90 = down, -90 = up, 180 = left.

typedef Limb = (double, double); // (upper arm | thigh, forearm | shin)

class Pose {
  const Pose({
    this.torso = -90,
    this.arm = (90, 90),
    this.armB,
    this.leg = (90, 90),
    this.legB,
    this.at = 'A',
    this.x = 60,
    this.y = 89,
    this.foot,
    this.footB,
    this.head = 0,
  });

  /// Hip → shoulder direction.
  final double torso;

  /// Near side (side view) or viewer's right (front view). [armB]/[legB] = far / left side;
  /// null = same as near (side view) or mirrored (front view).
  final Limb arm, leg;
  final Limb? armB, legB;

  /// Joint placed at ([x], [y]): S E W H K A T (+ 'b' for the far/left side).
  final String at;
  final double x, y;
  final double? foot, footB; // ankle → toe; default perpendicular to the shin
  final double head; // head tilt off the torso line
}

/// Equipment, drawn behind the body ([Line], [Box], [Ring]) or in the hands ([Bar], [Db], [Kb], [FrontBar]).
/// Points are an [Offset] or a joint name.
sealed class Prop {
  const Prop();
}

class Line extends Prop {
  const Line(this.a, this.b, {this.w = 2.5});
  final Object a, b;
  final double w;
}

class Box extends Prop {
  const Box(this.r);
  final Rect r;
}

class Ring extends Prop {
  const Ring(this.c, this.r);
  final Object c;
  final double r;
}

class Bar extends Prop {
  const Bar([this.at = 'W']);
  final String at;
}

class Db extends Prop {
  const Db([this.at = 'W']);
  final String at;
}

class Kb extends Prop {
  const Kb([this.at = 'W']);
  final String at;
}

/// Barbell seen from the front, between both hands.
class FrontBar extends Prop {
  const FrontBar();
}

/// Jump rope from the left hand to the right hand, bulging through [a] (pose a) → [b] (pose b).
class Rope extends Prop {
  const Rope(this.a, this.b);
  final Offset a, b;
}

/// Flat pad / plate of length [len] centred on a joint at angle [deg] (e.g. the leg press sled).
class Pad extends Prop {
  const Pad(this.at, this.deg, [this.len = 14]);
  final String at;
  final double deg, len;
}

class Art {
  const Art(this.a, [Pose? b, this.props = const [], this.front = false, this.floor = true]) : b = b ?? a;
  final Pose a, b;
  final List<Prop> props;
  final bool front, floor;
}

// Segment lengths.
const _torso = 24.0, _upper = 12.0, _fore = 11.0, _thigh = 15.5, _shin = 15.5, _head = 5.5;

Offset _dir(double deg) => Offset(math.cos(deg * math.pi / 180), math.sin(deg * math.pi / 180));
double _mirror(double a) => 180 - a;
double _lerpAngle(double a, double b, double t) {
  final d = ((b - a + 540) % 360) - 180;
  return a + d * t;
}

/// Joint positions for [p] relative to the hip.
Map<String, Offset> _joints(Pose p, bool front) {
  final j = <String, Offset>{};
  const h = Offset.zero;
  final s = h + _dir(p.torso) * _torso;
  j['N'] = s + _dir(p.torso) * 3;
  j['C'] = j['N']! + _dir(p.torso + p.head) * _head;
  void limbs(String sfx, Offset shoulder, Offset hip, Limb arm, Limb leg, double? foot) {
    j['S$sfx'] = shoulder;
    j['E$sfx'] = shoulder + _dir(arm.$1) * _upper;
    j['W$sfx'] = j['E$sfx']! + _dir(arm.$2) * _fore;
    j['H$sfx'] = hip;
    j['K$sfx'] = hip + _dir(leg.$1) * _thigh;
    j['A$sfx'] = j['K$sfx']! + _dir(leg.$2) * _shin;
    j['T$sfx'] = j['A$sfx']! + _dir(foot ?? leg.$2 - 90) * 4.5;
  }

  if (front) {
    Limb m(Limb l) => (_mirror(l.$1), _mirror(l.$2));
    limbs('', s + const Offset(7, 0), h + const Offset(4.5, 0), p.arm, p.leg, p.foot ?? 20);
    limbs(
      'b',
      s - const Offset(7, 0),
      h - const Offset(4.5, 0),
      p.armB ?? m(p.arm),
      p.legB ?? m(p.leg),
      p.footB ?? 160,
    );
  } else {
    limbs('', s, h, p.arm, p.leg, p.foot);
    limbs('b', s, h, p.armB ?? p.arm, p.legB ?? p.leg, p.footB ?? p.foot);
  }
  j['Hc'] = h;
  j['Sc'] = s;
  return j;
}

/// Hip position that puts the pose's anchor joint at (x, y).
Offset _hip(Pose p, bool front) => Offset(p.x, p.y) - _joints(p, front)[p.at]!;

Pose _lerp(Pose a, Pose b, double t) {
  Limb l(Limb x, Limb y) => (_lerpAngle(x.$1, y.$1, t), _lerpAngle(x.$2, y.$2, t));
  Limb? lo(Limb? x, Limb? y, Limb dx, Limb dy) => x == null && y == null ? null : l(x ?? dx, y ?? dy);
  return Pose(
    torso: _lerpAngle(a.torso, b.torso, t),
    arm: l(a.arm, b.arm),
    armB: lo(a.armB, b.armB, a.arm, b.arm),
    leg: l(a.leg, b.leg),
    legB: lo(a.legB, b.legB, a.leg, b.leg),
    foot: a.foot == null && b.foot == null ? null : _lerpAngle(a.foot ?? a.leg.$2 - 90, b.foot ?? b.leg.$2 - 90, t),
    footB: a.footB == null && b.footB == null
        ? null
        : _lerpAngle(a.footB ?? (a.legB ?? a.leg).$2 - 90, b.footB ?? (b.legB ?? b.leg).$2 - 90, t),
    head: a.head + (b.head - a.head) * t,
  );
}

class ArtPainter extends CustomPainter {
  ArtPainter(this.art, this.t, {this.color = lime});
  final Art art;
  final double t; // 0 = pose a, 1 = pose b
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = math.min(size.width / 120, size.height / 100);
    canvas.translate((size.width - 120 * k) / 2, (size.height - 100 * k) / 2);
    canvas.scale(k);

    final hip = Offset.lerp(_hip(art.a, art.front), _hip(art.b, art.front), t)!;
    final rel = _joints(_lerp(art.a, art.b, t), art.front);
    final j = {for (final e in rel.entries) e.key: e.value + hip};
    Offset pt(Object o) => o is Offset ? o : j[o as String]!;

    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final gear = stroke(muted, 2.5), plate = Paint()..color = const Color(0xFF5A606C);
    final near = stroke(color, 5), far = stroke(Color.lerp(color, surf, 0.55)!, 5);

    if (art.floor) canvas.drawLine(const Offset(4, 92), const Offset(116, 92), stroke(off, 2));
    for (final p in art.props) {
      switch (p) {
        case Line(:final a, :final b, :final w):
          canvas.drawLine(pt(a), pt(b), stroke(muted, w));
        case Box(:final r):
          canvas.drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(1.5)),
            Paint()..color = const Color(0xFF4A505C),
          );
        case Ring(:final c, :final r):
          canvas.drawCircle(pt(c), r, gear);
        default:
      }
    }

    void limb(String s, Paint p) {
      canvas.drawPath(
        Path()
          ..moveTo(j['H$s']!.dx, j['H$s']!.dy)
          ..lineTo(j['K$s']!.dx, j['K$s']!.dy)
          ..lineTo(j['A$s']!.dx, j['A$s']!.dy)
          ..lineTo(j['T$s']!.dx, j['T$s']!.dy),
        p..strokeJoin = StrokeJoin.round,
      );
    }

    void arm(String s, Paint p) {
      canvas.drawPath(
        Path()
          ..moveTo(j['S$s']!.dx, j['S$s']!.dy)
          ..lineTo(j['E$s']!.dx, j['E$s']!.dy)
          ..lineTo(j['W$s']!.dx, j['W$s']!.dy),
        p..strokeJoin = StrokeJoin.round,
      );
    }

    final body = stroke(color, 7.5);
    if (art.front) {
      limb('b', near);
      limb('', near);
      canvas.drawLine(j['Hb']!, j['H']!, body);
      canvas.drawLine(j['Sb']!, j['S']!, body);
      canvas.drawLine(j['Hc']!, j['Sc']!, body);
      arm('b', near);
      arm('', near);
    } else {
      limb('b', far);
      arm('b', far);
      canvas.drawLine(j['Hc']!, j['Sc']!, body);
      limb('', near);
      arm('', near);
    }
    canvas.drawLine(j['Sc']!, j['N']!, stroke(color, 4));
    canvas.drawCircle(j['C']!, _head, Paint()..color = color);

    for (final p in art.props) {
      switch (p) {
        case Bar(:final at):
          canvas.drawCircle(pt(at), 7.5, plate);
          canvas.drawCircle(pt(at), 7.5, stroke(muted, 1.5));
        case Db(:final at):
          final c = pt(at);
          canvas.drawLine(c - const Offset(4, 0), c + const Offset(4, 0), stroke(muted, 2));
          for (final d in [-4.0, 4.0]) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: c + Offset(d, 0), width: 3, height: 7),
                const Radius.circular(1),
              ),
              plate,
            );
          }
        case Kb(:final at):
          final c = pt(at) + const Offset(0, 5);
          canvas.drawCircle(c, 4.5, plate);
          canvas.drawCircle(pt(at) + const Offset(0, 1), 2, stroke(muted, 1.5));
        case Pad(:final at, :final deg, :final len):
          final c = pt(at), d = _dir(deg) * (len / 2);
          canvas.drawLine(c - d, c + d, stroke(muted, 4));
        case FrontBar():
          final l = j['Wb']!, r = j['W']!, d = _dir(math.atan2(r.dy - l.dy, r.dx - l.dx) * 180 / math.pi);
          canvas.drawLine(l - d * 12, r + d * 12, stroke(muted, 2));
          for (final e in [l - d * 12, r + d * 12]) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromCenter(center: e, width: 4, height: 13), const Radius.circular(1)),
              plate,
            );
          }
        case Rope(:final a, :final b):
          final l = j['Wb']!, r = j['W']!, via = Offset.lerp(a, b, t)!;
          final c = via * 2 - (l + r) / 2; // quadratic control so the curve passes through [via]
          canvas.drawPath(
            Path()
              ..moveTo(l.dx, l.dy)
              ..quadraticBezierTo(c.dx, c.dy, r.dx, r.dy),
            stroke(muted, 1.5),
          );
        default:
      }
    }
  }

  @override
  bool shouldRepaint(ArtPainter old) => old.t != t || old.art != art || old.color != color;
}

/// Looping illustration for [name]; a plain icon for exercises without one.
class ExerciseArt extends StatefulWidget {
  const ExerciseArt(this.name, {super.key, this.size = 56, this.animate = true});
  final String name;
  final double size;
  final bool animate;

  @override
  State<ExerciseArt> createState() => _ExerciseArtState();
}

class _ExerciseArtState extends State<ExerciseArt> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the system "reduce motion" setting.
    if (widget.animate && !MediaQuery.disableAnimationsOf(context)) {
      if (!c.isAnimating) c.repeat(reverse: true);
    } else {
      c.stop();
    }
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = arts[widget.name];
    return Container(
      width: widget.size,
      height: widget.size * 100 / 120,
      decoration: BoxDecoration(color: surf2, borderRadius: BorderRadius.circular(widget.size / 6)),
      child: art == null
          ? Icon(Icons.fitness_center, color: dim, size: widget.size * 0.4)
          : AnimatedBuilder(
              animation: c,
              builder: (_, _) => CustomPaint(painter: ArtPainter(art, Curves.easeInOut.transform(c.value))),
            ),
    );
  }
}

// ── Scenery ────────────────────────────────────────────────────────────────
const _bench = [
  Box(Rect.fromLTWH(26, 70, 52, 4)),
  Line(Offset(32, 74), Offset(32, 92)),
  Line(Offset(72, 74), Offset(72, 92)),
];
const _seat = [Box(Rect.fromLTWH(44, 77, 26, 4)), Line(Offset(57, 81), Offset(57, 92))];
const _seatBack = [..._seat, Box(Rect.fromLTWH(40, 44, 4, 36))];
const _incline = [
  Line(Offset(30, 38), Offset(62, 70), w: 5),
  Box(Rect.fromLTWH(58, 68, 20, 4)),
  Line(Offset(46, 54), Offset(46, 92)),
  Line(Offset(70, 72), Offset(70, 92)),
];
const _pullBar = [
  Line(Offset(30, 18), Offset(90, 18), w: 3),
  Line(Offset(32, 18), Offset(32, 92)),
  Line(Offset(88, 18), Offset(88, 92)),
];
const _rowBench = [
  Box(Rect.fromLTWH(38, 77, 52, 4)),
  Line(Offset(44, 81), Offset(44, 92)),
  Line(Offset(84, 81), Offset(84, 92)),
  Db(),
];
const _tower = [Line(Offset(100, 6), Offset(100, 92), w: 3), Line(Offset(92, 6), Offset(104, 6), w: 3)];

// ── Shared poses ───────────────────────────────────────────────────────────
const _lie = Pose(torso: 180, leg: (28, 90), at: 'Hc', x: 70, y: 66); // on the flat bench, head left
const _sit = Pose(leg: (0, 90), at: 'Hc', x: 58, y: 73.5); // on [_seat]
const _standDown = Pose(); // arms hanging
const _hinge = Pose(torso: -30, leg: (75, 100)); // bent-over row / deadlift start
const _squat = Pose(torso: -55, leg: (-5, 115), arm: (10, 0));

Pose _withArm(Pose p, Limb arm, {Limb? armB}) => Pose(
  torso: p.torso,
  arm: arm,
  armB: armB,
  leg: p.leg,
  legB: p.legB,
  at: p.at,
  x: p.x,
  y: p.y,
  foot: p.foot,
  footB: p.footB,
  head: p.head,
);

final Map<String, Art> arts = {
  // 가슴
  '벤치프레스': Art(_withArm(_lie, (-90, -90)), _withArm(_lie, (115, -75)), [..._bench, const Bar()]),
  '인클라인 벤치프레스': const Art(
    Pose(torso: -135, leg: (25, 95), at: 'Hc', x: 64, y: 66, arm: (-95, -95)),
    Pose(torso: -135, leg: (25, 95), at: 'Hc', x: 64, y: 66, arm: (100, -70)),
    [..._incline, Bar()],
  ),
  '덤벨 벤치프레스': Art(_withArm(_lie, (-90, -90)), _withArm(_lie, (115, -75)), [..._bench, const Db()]),
  '인클라인 덤벨 프레스': const Art(
    Pose(torso: -135, leg: (25, 95), at: 'Hc', x: 64, y: 66, arm: (-95, -95)),
    Pose(torso: -135, leg: (25, 95), at: 'Hc', x: 64, y: 66, arm: (100, -70)),
    [..._incline, Db()],
  ),
  '체스트 프레스 머신': Art(_withArm(_sit, (0, 0)), _withArm(_sit, (150, 10)), [
    ..._seatBack,
    const Line('W', Offset(96, 54)),
    const Line(Offset(96, 34), Offset(96, 92), w: 3),
  ]),
  '펙덱 플라이': const Art(
    Pose(arm: (5, -90), leg: (70, 90), at: 'Hc', x: 60, y: 60),
    Pose(arm: (150, -80), leg: (70, 90), at: 'Hc', x: 60, y: 60),
    [Box(Rect.fromLTWH(46, 62, 28, 4)), Line(Offset(60, 66), Offset(60, 92))],
    true,
  ),
  '케이블 크로스오버': const Art(Pose(arm: (-25, -15), leg: (95, 90)), Pose(arm: (110, 130), leg: (95, 90)), [
    Line(Offset(8, 6), 'Wb', w: 1.5),
    Line(Offset(112, 6), 'W', w: 1.5),
    Line(Offset(8, 6), Offset(8, 92), w: 3),
    Line(Offset(112, 6), Offset(112, 92), w: 3),
  ], true),
  '덤벨 플라이': Art(_withArm(_lie, (-90, -90)), _withArm(_lie, (100, 110)), [..._bench, const Db()]),
  '푸시업': const Art(
    Pose(torso: -25, arm: (92, 92), leg: (155, 155), at: 'W', x: 84, y: 89, foot: 100),
    Pose(torso: -12, arm: (145, 50), leg: (161, 161), at: 'W', x: 84, y: 89, foot: 100),
  ),
  '딥스': const Art(
    Pose(arm: (90, 90), leg: (105, 160), at: 'W', x: 60, y: 54),
    Pose(arm: (140, 55), leg: (105, 160), at: 'W', x: 60, y: 54),
    [Line(Offset(48, 56), Offset(76, 56), w: 3), Line(Offset(72, 56), Offset(72, 92))],
  ),

  // 등
  '데드리프트': const Art(Pose(torso: -40, leg: (60, 110)), _standDown, [Bar()]),
  '랫풀다운': Art(_withArm(_sit, (-95, -90)), _withArm(_sit, (125, -70)), [
    ..._seat,
    const Line('W', Offset(62, 4), w: 1.5),
    const Line(Offset(40, 4), Offset(90, 4), w: 3),
    const Line(Offset(90, 4), Offset(90, 92), w: 3),
  ]),
  '바벨 로우': Art(_withArm(_hinge, (90, 90)), _withArm(_hinge, (165, 85)), const [Bar()]),
  '시티드 케이블 로우': const Art(
    Pose(torso: -80, leg: (-8, 8), arm: (0, 0), at: 'Hc', x: 36, y: 86),
    Pose(torso: -95, leg: (-8, 8), arm: (150, 5), at: 'Hc', x: 36, y: 86),
    [Line('W', Offset(104, 80), w: 1.5), Line(Offset(104, 60), Offset(104, 92), w: 3)],
  ),
  '원암 덤벨 로우': const Art(
    Pose(torso: -15, arm: (90, 90), armB: (90, 90), leg: (95, 85), legB: (90, 180), x: 62),
    Pose(torso: -15, arm: (175, 85), armB: (90, 90), leg: (95, 85), legB: (90, 180), x: 62),
    _rowBench,
  ),
  'T바 로우': Art(_withArm(_hinge, (90, 90)), _withArm(_hinge, (165, 85)), const [Line(Offset(8, 90), 'W'), Bar()]),
  '페이스 풀': const Art(Pose(arm: (-15, -10), leg: (100, 85)), Pose(arm: (-170, -45), leg: (100, 85)), [
    Line('W', Offset(104, 30), w: 1.5),
    ..._tower,
  ]),
  '백 익스텐션': const Art(
    Pose(torso: 40, leg: (150, 150), arm: (60, 60), at: 'Hc', x: 60, y: 50, head: 0),
    Pose(torso: -30, leg: (150, 150), arm: (150, 150), at: 'Hc', x: 60, y: 50),
    [
      Line(Offset(40, 66), Offset(64, 52), w: 5),
      Line(Offset(50, 60), Offset(50, 92)),
      Line(Offset(30, 78), Offset(30, 92)),
    ],
  ),
  '풀업': const Art(
    Pose(arm: (-92, -90), leg: (110, 165), at: 'W', x: 60, y: 18),
    Pose(arm: (115, -80), leg: (110, 165), at: 'W', x: 60, y: 18),
    _pullBar,
    false,
    false,
  ),

  // 하체
  '바벨 스쿼트': const Art(Pose(arm: (140, -60)), Pose(torso: -55, leg: (-5, 115), arm: (175, -40)), [Bar()]),
  '레그 프레스': const Art(
    Pose(torso: -160, leg: (-40, -40), arm: (40, 0), at: 'Hc', x: 46, y: 74, foot: -130),
    Pose(torso: -160, leg: (-75, 5), arm: (40, 0), at: 'Hc', x: 46, y: 74, foot: -130),
    [
      Line(Offset(18, 72), Offset(52, 84), w: 5),
      Line(Offset(40, 82), Offset(40, 92)),
      Line(Offset(74, 70), Offset(98, 36), w: 2),
      Line(Offset(74, 70), Offset(74, 92), w: 2),
      Pad('A', 50, 16),
    ],
  ),
  '루마니안 데드리프트': const Art(_standDown, Pose(torso: -15, leg: (95, 88)), [Bar()]),
  '힙 쓰러스트': const Art(
    Pose(torso: -153, leg: (-40, 65), arm: (60, 0), at: 'A', x: 82, y: 89),
    Pose(torso: 180, leg: (0, 90), arm: (60, 0), at: 'A', x: 82, y: 89),
    [Box(Rect.fromLTWH(18, 77, 26, 4)), Line(Offset(30, 81), Offset(30, 92)), Bar('Hc')],
  ),
  '고블릿 스쿼트': const Art(Pose(arm: (100, -80)), Pose(torso: -55, leg: (-5, 115), arm: (65, -60)), [Kb()]),
  '레그 익스텐션': Art(const Pose(leg: (0, 90), at: 'Hc', x: 58, y: 61), const Pose(leg: (0, 5), at: 'Hc', x: 58, y: 61), [
    ..._seatBack,
    const Ring('A', 3),
  ]),
  '레그 컬': const Art(
    Pose(torso: 0, leg: (180, 180), arm: (90, 10), at: 'Hc', x: 54, y: 62),
    Pose(torso: 0, leg: (180, -80), arm: (90, 10), at: 'Hc', x: 54, y: 62),
    [
      Box(Rect.fromLTWH(18, 66, 66, 4)),
      Line(Offset(30, 70), Offset(30, 92)),
      Line(Offset(76, 70), Offset(76, 92)),
      Ring('A', 3),
    ],
  ),
  '힙 어브덕션': const Art(
    Pose(leg: (92, 90), arm: (100, 90), at: 'Hc', x: 60, y: 60),
    Pose(leg: (55, 80), arm: (100, 90), at: 'Hc', x: 60, y: 60),
    [Box(Rect.fromLTWH(42, 62, 36, 4)), Line(Offset(60, 66), Offset(60, 92))],
    true,
  ),
  '워킹 런지': const Art(Pose(leg: (85, 95), legB: (100, 85)), Pose(leg: (5, 90), legB: (105, 170), footB: 90)),
  '불가리안 스플릿 스쿼트': const Art(
    Pose(leg: (75, 100), legB: (140, 141), footB: 175),
    Pose(leg: (20, 100), legB: (100, -160), footB: 175),
    [Box(Rect.fromLTWH(14, 80, 24, 4)), Line(Offset(26, 84), Offset(26, 92)), Db()],
  ),
  '카프 레이즈': const Art(Pose(at: 'T', x: 66, y: 86), Pose(foot: 60, at: 'T', x: 66, y: 86), [
    Box(Rect.fromLTWH(56, 87, 24, 5)),
    Db(),
  ]),

  // 어깨
  '오버헤드 프레스': const Art(Pose(arm: (115, -75)), Pose(arm: (-88, -90)), [Bar()]),
  '덤벨 숄더 프레스': Art(_withArm(_sit, (115, -75)), _withArm(_sit, (-88, -90)), [..._seatBack, const Db()]),
  '숄더 프레스 머신': Art(_withArm(_sit, (115, -75)), _withArm(_sit, (-88, -90)), [
    ..._seatBack,
    const Line('W', Offset(80, 8), w: 1.5),
    const Line(Offset(70, 8), Offset(96, 8), w: 3),
  ]),
  '사이드 레터럴 레이즈': const Art(Pose(arm: (95, 92), leg: (95, 90)), Pose(arm: (0, -5), leg: (95, 90)), [
    Db(),
    Db('Wb'),
  ], true),
  '프론트 레이즈': const Art(_standDown, Pose(arm: (0, 0)), [Db()]),
  '리어 델트 플라이': const Art(Pose(arm: (110, 100), leg: (80, 100)), Pose(arm: (-5, 0), leg: (80, 100)), [
    Db(),
    Db('Wb'),
  ], true),
  '업라이트 로우': const Art(Pose(arm: (100, 100), leg: (95, 90)), Pose(arm: (-15, 130), leg: (95, 90)), [FrontBar()], true),

  // 이두
  '바벨 컬': const Art(_standDown, Pose(arm: (95, -75)), [Bar()]),
  '덤벨 컬': const Art(_standDown, Pose(arm: (95, -75)), [Db()]),
  '해머 컬': const Art(_standDown, Pose(arm: (95, -75)), [Kb()]),
  '케이블 컬': const Art(_standDown, Pose(arm: (95, -75)), [
    Line('W', Offset(100, 88), w: 1.5),
    Line(Offset(100, 70), Offset(100, 92), w: 3),
  ]),
  '프리처 컬': Art(_withArm(_sit, (40, 40)), _withArm(_sit, (40, -110)), [
    ..._seat,
    const Line(Offset(62, 58), Offset(78, 72), w: 5),
    const Line(Offset(76, 72), Offset(76, 92)),
    const Db(),
  ]),

  // 삼두
  '케이블 푸시다운': const Art(Pose(arm: (95, -40), leg: (95, 88)), Pose(arm: (95, 85), leg: (95, 88)), [
    Line('W', Offset(80, 6), w: 1.5),
    Line(Offset(74, 6), Offset(100, 6), w: 3),
    Line(Offset(100, 6), Offset(100, 92), w: 3),
  ]),
  '오버헤드 트라이셉스 익스텐션': const Art(Pose(arm: (-100, 110)), Pose(arm: (-95, -90)), [Db()]),
  '라잉 트라이셉스 익스텐션': Art(_withArm(_lie, (-100, 170)), _withArm(_lie, (-100, -95)), [..._bench, const Bar()]),
  '클로즈 그립 벤치프레스': Art(_withArm(_lie, (-90, -90)), _withArm(_lie, (100, -85)), [..._bench, const Bar()]),
  '덤벨 킥백': const Art(
    Pose(torso: -15, arm: (175, 90), armB: (90, 90), leg: (95, 85), legB: (90, 180), x: 62),
    Pose(torso: -15, arm: (175, 175), armB: (90, 90), leg: (95, 85), legB: (90, 180), x: 62),
    _rowBench,
  ),
  '벤치 딥스': const Art(
    Pose(arm: (95, 95), leg: (40, 80), at: 'W', x: 44, y: 60),
    Pose(arm: (140, 50), leg: (25, 70), at: 'W', x: 44, y: 60),
    [Box(Rect.fromLTWH(20, 60, 30, 4)), Line(Offset(26, 64), Offset(26, 92)), Line(Offset(44, 64), Offset(44, 92))],
  ),

  // 복근
  '플랭크': const Art(Pose(torso: -10, arm: (90, 0), leg: (165, 165), at: 'E', x: 78, y: 87, foot: 100)),
  '크런치': const Art(
    Pose(torso: 180, arm: (-30, 200), leg: (-45, 50), at: 'Hc', x: 66, y: 86),
    Pose(torso: -150, arm: (-60, 170), leg: (-45, 50), at: 'Hc', x: 66, y: 86),
  ),
  '레그 레이즈': const Art(
    Pose(torso: 180, arm: (0, 0), leg: (-5, -5), at: 'Hc', x: 66, y: 86),
    Pose(torso: 180, arm: (0, 0), leg: (-88, -88), at: 'Hc', x: 66, y: 86),
  ),
  '행잉 레그 레이즈': const Art(
    Pose(arm: (-92, -90), leg: (100, 120), at: 'W', x: 60, y: 18),
    Pose(arm: (-100, -90), torso: -100, leg: (-5, -5), at: 'W', x: 60, y: 18),
    _pullBar,
    false,
    false,
  ),
  '러시안 트위스트': const Art(
    Pose(torso: -95, arm: (150, 160), armB: (165, 175), leg: (60, 100), at: 'Hc', x: 60, y: 82),
    Pose(torso: -85, arm: (15, 5), armB: (30, 20), leg: (60, 100), at: 'Hc', x: 60, y: 82),
    [Kb()],
    true,
  ),
  '케이블 크런치': const Art(
    Pose(torso: -80, arm: (-60, 150), leg: (90, 180), at: 'K', x: 52, y: 89),
    Pose(torso: 10, arm: (-10, 110), leg: (90, 180), at: 'K', x: 52, y: 89),
    [Line('W', Offset(96, 6), w: 1.5), ..._tower],
  ),

  // 전신
  '버피': const Art(
    Pose(torso: -40, leg: (-15, 120), arm: (95, 95)),
    Pose(arm: (-80, -85), leg: (88, 92), y: 80, foot: 60),
  ),
  '마운틴 클라이머': const Art(
    Pose(torso: -25, arm: (92, 92), leg: (40, 150), legB: (155, 155), at: 'W', x: 84, y: 89, foot: 100, footB: 100),
    Pose(torso: -25, arm: (92, 92), leg: (155, 155), legB: (40, 150), at: 'W', x: 84, y: 89, foot: 100, footB: 100),
  ),
  '점프 스쿼트': const Art(_squat, Pose(arm: (150, 140), leg: (92, 95), y: 78, foot: 60)),
  '줄넘기': const Art(Pose(arm: (100, 20), leg: (92, 90), foot: 70, y: 86), Pose(arm: (100, 20), leg: (92, 90), y: 89), [
    Rope(Offset(60, 8), Offset(60, 95)),
  ], true),
  '케틀벨 스윙': const Art(Pose(torso: -35, leg: (70, 105), arm: (110, 110)), Pose(arm: (5, 0)), [Kb()]),
  '스러스터': const Art(Pose(torso: -60, leg: (-5, 115), arm: (115, -75)), Pose(arm: (-88, -90)), [Bar()]),

  // 유산소
  '러닝': const Art(_run1, _run2),
  '러닝머신': const Art(_run1, _run2, [
    Box(Rect.fromLTWH(20, 90, 80, 4)),
    Line(Offset(96, 90), Offset(104, 40), w: 3),
    Line(Offset(98, 40), Offset(110, 40), w: 3),
  ]),
  '걷기': const Art(
    Pose(arm: (70, 70), armB: (110, 110), leg: (75, 95), legB: (105, 90)),
    Pose(arm: (110, 110), armB: (70, 70), leg: (105, 90), legB: (75, 95)),
  ),
  '수영': const Art(
    Pose(torso: 0, arm: (-5, 0), armB: (160, 170), leg: (178, 185), legB: (182, 175), at: 'Hc', x: 42, y: 66, head: 10),
    Pose(torso: 0, arm: (160, 170), armB: (-5, 0), leg: (182, 175), legB: (178, 185), at: 'Hc', x: 42, y: 66, head: 10),
    [Line(Offset(4, 64), Offset(116, 64), w: 1.5)],
    false,
    false,
  ),
  '등산': const Art(
    Pose(torso: -80, arm: (60, 30), leg: (60, 100), legB: (110, 95), at: 'Ab', x: 40, y: 78),
    Pose(torso: -80, arm: (60, 30), leg: (85, 90), legB: (100, 70), at: 'Ab', x: 40, y: 78),
    [Line(Offset(4, 92), Offset(116, 56), w: 2), Box(Rect.fromLTWH(36, 32, 8, 16)), Line('W', Offset(80, 74), w: 1.5)],
    false,
    false,
  ),
  '자전거': const Art(
    _bike1,
    _bike2,
    [
      Ring(Offset(32, 80), 12),
      Ring(Offset(92, 80), 12),
      Line(Offset(32, 80), Offset(54, 62)),
      Line(Offset(54, 62), Offset(62, 80)),
      Line(Offset(62, 80), Offset(32, 80)),
      Line(Offset(54, 62), Offset(84, 60)),
      Line(Offset(84, 60), Offset(92, 80)),
      Line(Offset(84, 60), Offset(84, 50)),
    ],
    false,
    false,
  ),
  '실내 사이클': const Art(
    _bike1,
    _bike2,
    [
      Ring(Offset(62, 80), 7),
      Line(Offset(54, 62), Offset(62, 80)),
      Line(Offset(54, 62), Offset(84, 52)),
      Line(Offset(30, 92), Offset(90, 92), w: 3),
      Line(Offset(62, 80), Offset(62, 92), w: 3),
      Line(Offset(84, 52), Offset(84, 92), w: 3),
    ],
    false,
    false,
  ),
  '천국의 계단': const Art(
    Pose(arm: (80, 0), leg: (40, 100), legB: (95, 90), at: 'Ab', x: 46, y: 89),
    Pose(arm: (80, 0), leg: (95, 90), legB: (120, 150), at: 'A', x: 56.6, y: 83.4),
    [
      Box(Rect.fromLTWH(50, 86, 30, 6)),
      Box(Rect.fromLTWH(80, 78, 30, 14)),
      Line(Offset(104, 36), Offset(104, 78), w: 3),
      Line(Offset(78, 46), Offset(104, 46), w: 3),
    ],
  ),
  '로잉머신': const Art(
    Pose(torso: -60, arm: (0, 0), leg: (-60, 60), at: 'Hc', x: 46, y: 82),
    Pose(torso: -110, arm: (150, 10), leg: (-5, 5), at: 'Hc', x: 46, y: 82),
    [
      Box(Rect.fromLTWH(14, 84, 92, 4)),
      Line(Offset(100, 84), Offset(100, 70), w: 3),
      Line('W', Offset(100, 74), w: 1.5),
    ],
  ),
  '줄넘기 (분)': const Art(
    Pose(arm: (100, 20), leg: (92, 90), foot: 70, y: 86),
    Pose(arm: (100, 20), leg: (92, 90), y: 89),
    [Rope(Offset(60, 8), Offset(60, 95))],
    true,
  ),
};

const _run1 = Pose(
  torso: -80,
  arm: (60, -20),
  armB: (130, 80),
  leg: (50, 120),
  legB: (120, 160),
  y: 84,
  at: 'A',
  x: 66,
);
const _run2 = Pose(
  torso: -80,
  arm: (130, 80),
  armB: (60, -20),
  leg: (120, 160),
  legB: (50, 120),
  y: 84,
  at: 'Ab',
  x: 66,
);
const _bike1 = Pose(torso: -50, arm: (5, 30), leg: (10, 110), legB: (60, 70), at: 'Hc', x: 52, y: 58);
const _bike2 = Pose(torso: -50, arm: (5, 30), leg: (60, 70), legB: (10, 110), at: 'Hc', x: 52, y: 58);
