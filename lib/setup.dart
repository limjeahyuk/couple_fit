import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'db.dart';
import 'theme.dart';

/// First run (no gender on the profile yet): gender, height, weight.
/// Gender goes on the user doc; height/weight become today's body record,
/// so the records tab and the routine editor's default weights use them from then on.
class ProfileSetup extends StatefulWidget {
  const ProfileSetup({super.key, this.gender, this.last});
  final String? gender; // already chosen (older accounts)
  final Json? last; // latest body record, to prefill for existing users

  @override
  State<ProfileSetup> createState() => _ProfileSetupState();
}

class _ProfileSetupState extends State<ProfileSetup> {
  late String? gender = widget.gender;
  late final height = TextEditingController(text: _s(widget.last?['height']));
  late final weight = TextEditingController(text: _s(widget.last?['weight']));
  String? error;
  bool saving = false;

  static String _s(Object? v) => v is num ? fmt1(v.toDouble()) : '';
  static double? _p(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    final h = _p(height), w = _p(weight);
    final problem = gender == null
        ? '성별을 골라주세요'
        : h == null || h < 100 || h > 250
            ? '키를 확인해 주세요'
            : w == null || w < 20 || w > 300
                ? '몸무게를 확인해 주세요'
                : null;
    if (problem != null) return setState(() => error = problem);
    setState(() => saving = true);
    final key = todayKey();
    try {
      await (fs.batch()
            ..update(userDoc(myUid), {'gender': gender})
            ..set(bodyOf(myUid).doc(key), {'date': key, 'height': h, 'weight': w}, SetOptions(merge: true)))
          .commit();
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = '저장하지 못했어요. 다시 시도해 주세요';
        });
      }
    }
  }

  Widget _gender(String g, String label) => Expanded(
        child: _choice(
          gender == g,
          () => setState(() => gender = g),
          Center(child: Text(label, style: ts(17, w: FontWeight.w700, color: gender == g ? ink : fg))),
        ),
      );

  Widget _field(TextEditingController c, String label, String unit) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: digits(20),
        decoration: InputDecoration(labelText: label, suffixText: unit),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            h1('시작하기 전에\n몸 정보를 알려주세요'),
            const SizedBox(height: 10),
            Text('루틴의 추천 무게를 계산하고, 기록 탭의 첫 측정값이 돼요', style: ts(14, color: muted, h: 1.5)),
            const SizedBox(height: 28),
            Text('성별', style: ts(13, color: sub)),
            const SizedBox(height: 8),
            Row(children: [_gender('m', '남성'), const SizedBox(width: 10), _gender('f', '여성')]),
            const SizedBox(height: 20),
            _field(height, '키', 'cm'),
            const SizedBox(height: 12),
            _field(weight, '몸무게', 'kg'),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: ts(13, color: coral)),
            ],
            const SizedBox(height: 28),
            FilledButton(onPressed: saving ? null : _save, child: const Text('시작하기')),
          ],
        ),
      ),
    );
  }
}

/// Big selectable card (lime when selected).
Widget _choice(bool on, VoidCallback onTap, Widget child) => Material(
      color: on ? lime : surf,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(height: 64, child: child),
      ),
    );
