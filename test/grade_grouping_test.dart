import 'package:celechron/model/grade.dart';
import 'package:celechron/utils/grade_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

Grade _grade(String id, {double credit = 3.0, double fivePoint = 4.5}) {
  return Grade.fromJson({
    'id': id,
    'name': '测试课程',
    'credit': credit,
    'original': '90',
    'fivePoint': fivePoint,
    'fourPoint': fivePoint > 4.0 ? 4.1 : fivePoint,
    'fourPointLegacy': fivePoint > 4.0 ? 4.0 : fivePoint,
    'hundredPoint': 90,
    'gpaIncluded': true,
    'creditIncluded': true,
  });
}

void main() {
  group('gradeGroupKey', () {
    test('普通本科选课课号取课程号段', () {
      final key = gradeGroupKey(
        '(2024-2025-2)-821T0150-0082403-1',
        const {},
      );
      expect(key, '821T0150');
    });

    test('体育课（PPAE/401）改用班级编号', () {
      final pe = gradeGroupKey(
        '(2024-2025-2)-40103200-0087355-1',
        const {},
      );
      expect(pe, '(2024-2025-2)-40103200');
    });

    test('套用用户自定义课程映射', () {
      final key = gradeGroupKey(
        '(2024-2025-2)-821T0150-0082403-1',
        {'821T0150': 'MATH-CALC'},
      );
      expect(key, 'MATH-CALC');
    });

    test('无正则匹配且长度不足 22 时抛 FormatException', () {
      expect(
        () => gradeGroupKey('short-id', const {}),
        throwsFormatException,
      );
    });

    test('无正则匹配但长度足够时回退到固定下标', () {
      const raw = '202420252821T015000824031'; // 26 chars
      expect(raw.length, greaterThanOrEqualTo(22));
      final key = gradeGroupKey(raw, const {});
      expect(key, raw.substring(14, 22));
    });
  });

  group('groupGradesByCourseKey', () {
    test('同一课程号的多次成绩归入同一组', () {
      final grouped = groupGradesByCourseKey([
        _grade('(2024-2025-2)-821T0150-0082403-1', credit: 5.0, fivePoint: 3.9),
        _grade('(2024-2025-1)-821T0150-0082403-1', credit: 5.0, fivePoint: 5.0),
        _grade('(2024-2025-2)-051F0020-0098350-2', credit: 3.0),
      ], const {});

      expect(grouped.keys.toSet(), {'821T0150', '051F0020'});
      expect(grouped['821T0150'], hasLength(2));
      expect(grouped['051F0020'], hasLength(1));
    });

    test('无法归类的成绩被跳过，其余仍保留', () {
      final good = _grade('(2024-2025-2)-821T0150-0082403-1');
      final bad = _grade('bad'); // 长度不足且无匹配
      final grouped = groupGradesByCourseKey([bad, good], const {});

      expect(grouped.keys, ['821T0150']);
      expect(grouped['821T0150'], [good]);
    });

    test('自定义映射影响分组键', () {
      final grouped = groupGradesByCourseKey(
        [
          _grade('(2024-2025-2)-821T0150-0082403-1'),
          _grade('(2024-2025-1)-821T0150-0099999-9'),
        ],
        {'821T0150': 'MERGED'},
      );

      expect(grouped.keys, ['MERGED']);
      expect(grouped['MERGED'], hasLength(2));
    });
  });
}
