import 'db.dart';

/// Pick-list for the routine editor.
/// [ratio]: working weight for ~10 reps as a share of bodyweight for a beginner–novice man
/// (dumbbells: per hand). 0 = bodyweight. [kind]: bb barbell · db dumbbell · mc machine/cable · bw bodyweight
/// · cardio (just minutes: [reps] like '30분').
typedef CatalogItem = ({String name, double ratio, String kind, String reps, int rest});

CatalogItem _bw(String name, [String reps = '12', int rest = 60]) => (name: name, ratio: 0, kind: 'bw', reps: reps, rest: rest);
CatalogItem _cardio(String name, int mins) => (name: name, ratio: 0, kind: 'cardio', reps: '$mins분', rest: 0);

final Map<String, List<CatalogItem>> catalog = {
  '가슴': [
    (name: '벤치프레스', ratio: 0.6, kind: 'bb', reps: '10', rest: 90),
    (name: '인클라인 벤치프레스', ratio: 0.5, kind: 'bb', reps: '10', rest: 90),
    (name: '덤벨 벤치프레스', ratio: 0.2, kind: 'db', reps: '10', rest: 90),
    (name: '인클라인 덤벨 프레스', ratio: 0.18, kind: 'db', reps: '12', rest: 75),
    (name: '체스트 프레스 머신', ratio: 0.5, kind: 'mc', reps: '12', rest: 75),
    (name: '펙덱 플라이', ratio: 0.4, kind: 'mc', reps: '12', rest: 60),
    (name: '케이블 크로스오버', ratio: 0.15, kind: 'mc', reps: '15', rest: 60),
    (name: '덤벨 플라이', ratio: 0.1, kind: 'db', reps: '12', rest: 60),
    _bw('푸시업', '15'),
    _bw('딥스', '10', 90),
  ],
  '등': [
    (name: '데드리프트', ratio: 0.9, kind: 'bb', reps: '8', rest: 120),
    (name: '랫풀다운', ratio: 0.55, kind: 'mc', reps: '10', rest: 90),
    (name: '바벨 로우', ratio: 0.5, kind: 'bb', reps: '10', rest: 90),
    (name: '시티드 케이블 로우', ratio: 0.5, kind: 'mc', reps: '12', rest: 75),
    (name: '원암 덤벨 로우', ratio: 0.25, kind: 'db', reps: '10', rest: 75),
    (name: 'T바 로우', ratio: 0.4, kind: 'mc', reps: '10', rest: 90),
    (name: '페이스 풀', ratio: 0.2, kind: 'mc', reps: '15', rest: 60),
    _bw('백 익스텐션', '15'),
    _bw('풀업', '8', 90),
  ],
  '하체': [
    (name: '바벨 스쿼트', ratio: 0.75, kind: 'bb', reps: '8', rest: 120),
    (name: '레그 프레스', ratio: 1.5, kind: 'mc', reps: '12', rest: 90),
    (name: '루마니안 데드리프트', ratio: 0.6, kind: 'bb', reps: '10', rest: 90),
    (name: '힙 쓰러스트', ratio: 0.8, kind: 'bb', reps: '12', rest: 90),
    (name: '고블릿 스쿼트', ratio: 0.25, kind: 'db', reps: '12', rest: 75),
    (name: '레그 익스텐션', ratio: 0.45, kind: 'mc', reps: '12', rest: 60),
    (name: '레그 컬', ratio: 0.35, kind: 'mc', reps: '12', rest: 60),
    (name: '힙 어브덕션', ratio: 0.5, kind: 'mc', reps: '15', rest: 60),
    _bw('워킹 런지'),
    _bw('불가리안 스플릿 스쿼트', '10', 75),
    _bw('카프 레이즈', '20', 45),
  ],
  '어깨': [
    (name: '오버헤드 프레스', ratio: 0.4, kind: 'bb', reps: '8', rest: 90),
    (name: '덤벨 숄더 프레스', ratio: 0.15, kind: 'db', reps: '12', rest: 75),
    (name: '숄더 프레스 머신', ratio: 0.35, kind: 'mc', reps: '12', rest: 75),
    (name: '사이드 레터럴 레이즈', ratio: 0.07, kind: 'db', reps: '15', rest: 60),
    (name: '프론트 레이즈', ratio: 0.07, kind: 'db', reps: '12', rest: 60),
    (name: '리어 델트 플라이', ratio: 0.06, kind: 'db', reps: '15', rest: 60),
    (name: '업라이트 로우', ratio: 0.3, kind: 'bb', reps: '12', rest: 60),
  ],
  '이두': [
    (name: '바벨 컬', ratio: 0.3, kind: 'bb', reps: '10', rest: 60),
    (name: '덤벨 컬', ratio: 0.12, kind: 'db', reps: '12', rest: 60),
    (name: '해머 컬', ratio: 0.13, kind: 'db', reps: '12', rest: 60),
    (name: '케이블 컬', ratio: 0.25, kind: 'mc', reps: '12', rest: 60),
    (name: '프리처 컬', ratio: 0.25, kind: 'mc', reps: '10', rest: 60),
  ],
  '삼두': [
    (name: '케이블 푸시다운', ratio: 0.3, kind: 'mc', reps: '15', rest: 60),
    (name: '오버헤드 트라이셉스 익스텐션', ratio: 0.2, kind: 'db', reps: '12', rest: 60),
    (name: '라잉 트라이셉스 익스텐션', ratio: 0.3, kind: 'bb', reps: '10', rest: 60),
    (name: '클로즈 그립 벤치프레스', ratio: 0.5, kind: 'bb', reps: '10', rest: 90),
    (name: '덤벨 킥백', ratio: 0.06, kind: 'db', reps: '12', rest: 60),
    _bw('벤치 딥스'),
  ],
  '복근': [
    _bw('플랭크', '40초', 30),
    _bw('크런치', '20', 45),
    _bw('레그 레이즈', '15', 45),
    _bw('행잉 레그 레이즈', '10', 60),
    _bw('러시안 트위스트', '20', 45),
    (name: '케이블 크런치', ratio: 0.3, kind: 'mc', reps: '15', rest: 60),
  ],
  '전신': [
    _bw('버피', '15', 45),
    _bw('마운틴 클라이머', '30', 30),
    _bw('점프 스쿼트', '15', 45),
    _bw('줄넘기', '60초', 30),
    (name: '케틀벨 스윙', ratio: 0.2, kind: 'db', reps: '15', rest: 60),
    (name: '스러스터', ratio: 0.3, kind: 'bb', reps: '10', rest: 90),
  ],
  '유산소': [
    _cardio('러닝', 30),
    _cardio('러닝머신', 30),
    _cardio('걷기', 40),
    _cardio('수영', 40),
    _cardio('등산', 120),
    _cardio('자전거', 40),
    _cardio('실내 사이클', 30),
    _cardio('천국의 계단', 20),
    _cardio('로잉머신', 15),
    _cardio('줄넘기 (분)', 15),
  ],
};

/// Category of a catalog exercise name ('' for custom ones).
String categoryOf(String name) {
  for (final MapEntry(key: c, value: list) in catalog.entries) {
    if (list.any((e) => e.name == name)) return c;
  }
  return '';
}

/// Bodyweight used for defaults: measured, else from height at BMI 22, else a Korean adult average.
double bodyBasis({String? gender, num? weight, num? height}) {
  if (weight != null && weight > 0) return weight.toDouble();
  if (height != null && height > 0) return 22 * (height / 100) * (height / 100);
  return gender == 'f' ? 57 : gender == 'm' ? 72 : 65;
}

/// Default working weight for [e], e.g. "47.5kg" / "10kg" / "맨몸".
/// Women's ratios are scaled down more for the upper body than the legs (typical strength-standard gap).
String suggestWeight(CatalogItem e, {String? gender, num? weight, num? height}) {
  if (e.kind == 'cardio') return '';
  if (e.kind == 'bw') return '맨몸';
  final legs = categoryOf(e.name) == '하체';
  final f = legs ? 0.75 : 0.55;
  final scale = gender == 'f' ? f : gender == 'm' ? 1.0 : (1 + f) / 2;
  final kg = e.ratio * bodyBasis(gender: gender, weight: weight, height: height) * scale;
  final step = e.kind == 'db' ? 1.0 : 2.5;
  final min = e.kind == 'bb' ? 20.0 : e.kind == 'mc' ? 5.0 : 1.0; // empty bar / lightest stack / lightest dumbbell
  final r = ((kg / step).round() * step).clamp(min, 500.0);
  return '${fmt1(r)}kg';
}

Exercise exerciseFrom(CatalogItem e, {String? gender, num? weight, num? height}) => Exercise(
  name: e.name,
  sets: e.kind == 'cardio' ? 1 : 3,
  reps: e.reps,
  weight: suggestWeight(e, gender: gender, weight: weight, height: height),
  restSec: e.rest,
);
