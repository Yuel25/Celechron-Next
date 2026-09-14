import 'dart:math' as math;

import 'package:celechron/design/custom_colors.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/widget/agenda_cards.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'task_flow_fixture.dart';

/// WCAG 2.x sRGB 通道线性化。
double _linearize(double c) {
  return c <= 0.04045
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

/// WCAG 2.x 相对亮度计算。
double _relativeLuminance(Color c) {
  final r = _linearize(c.r);
  final g = _linearize(c.g);
  final b = _linearize(c.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// WCAG 2.x 对比度计算：(L1 + 0.05) / (L2 + 0.05)。
double _contrastRatio(Color c1, Color c2) {
  final l1 = _relativeLuminance(c1);
  final l2 = _relativeLuminance(c2);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  const white = Color(0xFFFFFFFF);

  group('readableBarColor pure function tests', () {
    test('systemYellow 在亮色模式下的增强色对白色（Color(0xFFFFFFFF)）的 WCAG 对比度 >= 3.0', () {
      const yellow = CupertinoColors.systemYellow;
      final originalContrast = _contrastRatio(yellow, white);
      // 处理前 systemYellow 对白色对比度仅约 1.51:1
      expect(originalContrast, lessThan(2.0));

      final enhanced = readableBarColor(yellow, Brightness.light);
      final enhancedContrast = _contrastRatio(enhanced, white);
      expect(enhancedContrast, greaterThanOrEqualTo(3.0));

      // 验证原生十六进制黄色同样满足
      const rawYellow = Color(0xFFFFCC00);
      final enhancedRaw = readableBarColor(rawYellow, Brightness.light);
      expect(_contrastRatio(enhancedRaw, white), greaterThanOrEqualTo(3.0));
    });

    test('暗色模式返回原色', () {
      const yellow = CupertinoColors.systemYellow;
      expect(readableBarColor(yellow, Brightness.dark), yellow);

      const blue = CupertinoColors.systemBlue;
      expect(readableBarColor(blue, Brightness.dark), blue);

      const custom = Color(0xFF123456);
      expect(readableBarColor(custom, Brightness.dark), custom);
    });

    test('已有较深颜色（如 systemBlue）增强后对比度不下降', () {
      const blue = CupertinoColors.systemBlue;
      final origBlueContrast = _contrastRatio(blue, white);
      final enhBlue = readableBarColor(blue, Brightness.light);
      final enhBlueContrast = _contrastRatio(enhBlue, white);
      expect(enhBlueContrast, greaterThanOrEqualTo(origBlueContrast));

      const red = CupertinoColors.systemRed;
      final origRedContrast = _contrastRatio(red, white);
      final enhRed = readableBarColor(red, Brightness.light);
      final enhRedContrast = _contrastRatio(enhRed, white);
      expect(enhRedContrast, greaterThanOrEqualTo(origRedContrast));

      const purple = CupertinoColors.systemPurple;
      final origPurpleContrast = _contrastRatio(purple, white);
      final enhPurple = readableBarColor(purple, Brightness.light);
      final enhPurpleContrast = _contrastRatio(enhPurple, white);
      expect(enhPurpleContrast, greaterThanOrEqualTo(origPurpleContrast));
    });

    test('所有时间段课程颜色（TimeColors）在亮色模式下对比度均 >= 3.0', () {
      for (var hour = 0; hour < 24; hour++) {
        final color = TimeColors.colorFromHour(hour);
        final enhanced = readableBarColor(color, Brightness.light);
        final contrast = _contrastRatio(enhanced, white);
        expect(
          contrast,
          greaterThanOrEqualTo(3.0),
          reason:
              'hour $hour color $color enhanced to $enhanced contrast $contrast < 3.0',
        );
      }
    });
  });

  group('_ThinProgressBar in widget hierarchy tests', () {
    final now = DateTime(2030, 9, 5, 13, 15);
    final noonPeriod = Period(
      summary: '数据库原理',
      location: '紫金港 · 西二 101',
      startTime: now.subtract(const Duration(minutes: 15)),
      endTime: now.add(const Duration(minutes: 30)),
    );

    testWidgets('AgendaPeriodCard featured 使用 systemYellow 在亮色模式下应用增强填充色',
        (tester) async {
      await tester.pumpWidget(CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.light),
        home: CupertinoPageScaffold(
          child: AgendaPeriodCard(
            period: noonPeriod,
            now: now,
            color: CupertinoColors.systemYellow,
            featured: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final expectedFill = readableBarColor(
        CupertinoColors.systemYellow.color,
        Brightness.light,
      );
      final expectedTrack =
          CupertinoColors.systemYellow.color.withValues(alpha: 0.12);

      final coloredBoxes =
          tester.widgetList<ColoredBox>(find.byType(ColoredBox)).toList();
      final hasFill = coloredBoxes.any((cb) => cb.color == expectedFill);
      final hasTrack = coloredBoxes.any((cb) => cb.color == expectedTrack);

      expect(hasFill, isTrue, reason: '应包含增强后的可读填充色');
      expect(hasTrack, isTrue, reason: '应包含淡色进度条轨道色');
    });

    testWidgets('AgendaPeriodCard featured 使用 systemYellow 在暗色模式下保持原暗色',
        (tester) async {
      await tester.pumpWidget(CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.dark),
        home: CupertinoPageScaffold(
          child: AgendaPeriodCard(
            period: noonPeriod,
            now: now,
            color: CupertinoColors.systemYellow,
            featured: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final expectedDark = CupertinoColors.systemYellow.darkColor;
      final expectedTrack = expectedDark.withValues(alpha: 0.12);

      final coloredBoxes =
          tester.widgetList<ColoredBox>(find.byType(ColoredBox)).toList();
      final hasFill = coloredBoxes
          .any((cb) => cb.color.toARGB32() == expectedDark.toARGB32());
      final hasTrack = coloredBoxes
          .any((cb) => cb.color.toARGB32() == expectedTrack.toARGB32());

      expect(hasFill, isTrue, reason: '暗色模式下应使用原生暗色');
      expect(hasTrack, isTrue, reason: '暗色模式下应使用原生暗色轨道');
    });

    testWidgets('TaskCardContent 使用 systemYellow 在亮色模式下同样应用增强填充色',
        (tester) async {
      final task = sampleTask(now, spent: const Duration(minutes: 20))
        ..summary = '中午课后作业'
        ..timeNeeded = const Duration(minutes: 60);

      await tester.pumpWidget(CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.light),
        home: CupertinoPageScaffold(
          child: TaskCardContent(
            task: task,
            now: now,
            color: CupertinoColors.systemYellow,
            onToggle: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final expectedFill = readableBarColor(
        CupertinoColors.systemYellow.color,
        Brightness.light,
      );
      final coloredBoxes =
          tester.widgetList<ColoredBox>(find.byType(ColoredBox)).toList();
      final hasFill = coloredBoxes.any((cb) => cb.color == expectedFill);

      expect(hasFill, isTrue, reason: 'TaskCardContent 也应共用增强后的可读填充色');
    });
  });
}
