import 'dart:async';

import 'package:celechron/widget/data_updated_label.dart';
import 'package:celechron/page/flow/planning_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime now = DateTime(2030, 9, 5, 10);

  Future<void> mount(
      WidgetTester tester, FutureOr<int> Function(DateTime) generate,
      {double scale = 1, Brightness brightness = Brightness.light}) async {
    now = DateTime(2030, 9, 5, 10);
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(CupertinoApp(
        theme: CupertinoThemeData(brightness: brightness),
        home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: CupertinoPageScaffold(
                child: PlanningSheet(
                    workTime: const Duration(minutes: 45),
                    restTime: const Duration(minutes: 15),
                    availableTimes: '08:00–11:35、14:15–23:00',
                    now: () => now,
                    onGenerate: generate)))));
    await tester.pumpAndSettle();
  }

  testWidgets('failed planning stays in panel and allows retry',
      (tester) async {
    var calls = 0;
    await mount(tester, (_) => ++calls == 1 ? -1 : 15);
    await tester.tap(find.text('生成规划'));
    await tester.pumpAndSettle();
    expect(find.textContaining('现有安排已保留'), findsOneWidget);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    await tester.tap(find.text('生成规划'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('规划已生成'), findsOneWidget);
    expect(find.byType(CupertinoDatePicker), findsNothing);
    expect(calls, 2);
    // 成功后约 900ms 自动关闭
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(find.byType(PlanningSheet), findsNothing);
  });

  testWidgets('compressed break result is visible without another dialog',
      (tester) async {
    await mount(tester, (_) => 5);
    await tester.tap(find.text('生成规划'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('本次休息缩短为 5 分钟'), findsOneWidget);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
  });

  testWidgets('time that elapsed while panel was open does not generate',
      (tester) async {
    var calls = 0;
    await mount(tester, (_) {
      calls++;
      return 15;
    });
    now = now.add(const Duration(minutes: 3));
    await tester.tap(find.text('生成规划'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.textContaining('开始时间已过去'), findsOneWidget);
  });

  testWidgets('generation cannot be submitted twice while saving',
      (tester) async {
    var calls = 0;
    final result = Completer<int>();
    await mount(tester, (_) {
      calls++;
      return result.future;
    });
    await tester.tap(find.text('生成规划'));
    await tester.pump();
    final button =
        tester.widget<CupertinoButton>(find.byType(CupertinoButton).last);
    expect(button.onPressed, isNull);
    expect(calls, 1);
    result.complete(15);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('规划已生成'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
  });

  for (final brightness in Brightness.values) {
    testWidgets('narrow panel supports large text in $brightness',
        (tester) async {
      await mount(tester, (_) => -1, scale: 2, brightness: brightness);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('生成规划'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('可用时间不足'), findsOneWidget);
      final errorRect = tester.getRect(find.textContaining('可用时间不足'));
      final buttonRect = tester.getRect(find.text('生成规划'));
      expect(errorRect.top, greaterThanOrEqualTo(0));
      expect(errorRect.bottom, lessThan(buttonRect.top));
    });
  }

  testWidgets('old cached data is neutral rather than a failure',
      (tester) async {
    await tester.pumpWidget(const CupertinoApp(
        home: CupertinoPageScaffold(
            child: DataUpdatedLabel(age: Duration(days: 3)))));
    expect(find.text('3 天前更新'), findsOneWidget);
    expect(
        find.byIcon(CupertinoIcons.exclamationmark_circle_fill), findsNothing);
    final text = tester.widget<Text>(find.text('3 天前更新'));
    expect(text.style!.color, isNot(CupertinoColors.systemOrange));
  });
}
