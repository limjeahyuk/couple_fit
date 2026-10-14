import 'package:flutter/foundation.dart';

import 'db.dart';
import 'theme.dart';

/// Debug-only preview of the couple experience: a fake partner held in memory, never written to Firebase.
final demoPartner = ValueNotifier<bool>(false);

const demoPartnerUid = 'demo-partner';

DateTime _daysAgo(int n) {
  final t = DateTime.now();
  return DateTime(t.year, t.month, t.day - n);
}

Json demoPartnerDoc(String myUid) => {
      'name': '소연',
      'code': 'DEMO00',
      'partnerId': myUid,
      'avatar': {'bg': coral.toARGB32(), 'emoji': '🐰'},
      'uid': demoPartnerUid,
    };

/// ~3 weeks of workouts (rests every third day), newest first like the real query.
List<Json> demoSessions() {
  const plans = [
    ('하체 데이', [('바벨 스쿼트', '40kg', '10'), ('레그 프레스', '60kg', '12'), ('카프 레이즈', '맨몸', '20')]),
    ('상체 푸시', [('덤벨 프레스', '8kg', '12'), ('숄더 프레스', '6kg', '12')]),
    ('등·이두', [('랫풀다운', '30kg', '12'), ('덤벨 컬', '5kg', '12')]),
    ('커플 서킷', [('버피', '맨몸', '12'), ('플랭크', '맨몸', '40초')]),
  ];
  return [
    for (var i = 0; i < 21; i++)
      if (i % 3 != 2)
        () {
          final (routine, ex) = plans[i % plans.length];
          return {
            'date': dayKey(_daysAgo(i)),
            'routine': routine,
            'totalSec': (38 + (i * 7) % 15) * 60,
            'restSec': (8 + i % 4) * 60,
            'sets': ex.length * 3,
            'exCount': ex.length,
            'log': [
              for (final (name, weight, reps) in ex)
                for (var s = 0; s < 3; s++) {'ex': name, 'weight': weight, 'reps': reps},
            ],
          };
        }(),
  ];
}

/// Five measurements, ten days apart, oldest first, drifting from [from] to [to] ({weight, fat, muscle}).
List<Json> _bodySeries(double height, Map<String, double> from, Map<String, double> to) => [
      for (var i = 0; i < 5; i++)
        {
          'date': dayKey(_daysAgo(40 - i * 10)),
          'height': height,
          for (final k in from.keys) k: double.parse((from[k]! + (to[k]! - from[k]!) * i / 4).toStringAsFixed(1)),
        },
    ];

List<Json> demoPartnerBody() =>
    _bodySeries(162, {'weight': 55.2, 'fat': 27.6, 'muscle': 20.1}, {'weight': 53.8, 'fat': 25.9, 'muscle': 20.8});

/// Shown for me only while my real body log is empty, so the comparison has two sides.
List<Json> demoMyBody() =>
    _bodySeries(175, {'weight': 74.6, 'fat': 21.9, 'muscle': 31.7}, {'weight': 72.4, 'fat': 19.7, 'muscle': 32.9});

bool get demoAvailable => kDebugMode;
