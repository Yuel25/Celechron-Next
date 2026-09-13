import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/task.dart';
import 'package:celechron/page/flow/flow_controller.dart';
import 'package:celechron/page/flow/flow_view.dart';
import 'package:celechron/page/flow/planning_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'flow_controller_test.dart' show MemoryDatabase;

class FullDayMemoryDatabase extends MemoryDatabase {
  @override
  Map<DateTime, DateTime> getAllowTime() => {
        DateTime(0, 1, 1, 0, 0): DateTime(0, 1, 1, 23, 59),
      };
}

class ThrowingFlowController extends FlowController {
  @override
  int generateNewFlowList(DateTime startsAt) {
    throw StateError('Simulated unexpected planner error');
  }
}

void main() {
  late FullDayMemoryDatabase db;
  late RxList<Task> tasks;
  late RxList<Period> flows;

  setUp(() {
    db = FullDayMemoryDatabase();
    tasks = <Task>[].obs;
    flows = <Period>[].obs;

    final now = DateTime.now();
    Get.put<DatabaseHelper>(db, tag: 'db');
    Get.put(Scholar().obs, tag: 'scholar');
    Get.put(tasks, tag: 'taskList');
    Get.put(flows, tag: 'flowList');
    Get.put(now.obs, tag: 'taskListLastUpdate');
    Get.put(now.obs, tag: 'flowListLastUpdate');
  });

  tearDown(() async {
    await Get.deleteAll(force: true);
    Get.reset();
  });

  group('FlowPage header buttons', () {
    testWidgets('Header displays two buttons: 刷新计划 and 安排专注时间', (tester) async {
      await tester.pumpWidget(CupertinoApp(
        home: FlowPage(),
      ));
      await tester.pump();

      expect(find.bySemanticsLabel('刷新计划'), findsOneWidget);
      expect(find.bySemanticsLabel('安排专注时间'), findsOneWidget);

      final iconRefresh = find.byIcon(CupertinoIcons.refresh_circled);
      final iconSlider = find.byIcon(CupertinoIcons.slider_horizontal_3);
      expect(iconRefresh, findsOneWidget);
      expect(iconSlider, findsOneWidget);

      await Get.delete<FlowController>(force: true);
    });

    testWidgets('Button B: 安排专注时间 opens PlanningSheet', (tester) async {
      await tester.pumpWidget(CupertinoApp(
        home: FlowPage(),
      ));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('安排专注时间'));
      await tester.pumpAndSettle();

      expect(find.byType(PlanningSheet), findsOneWidget);

      await Get.delete<FlowController>(force: true);
    });

    testWidgets('Button A: 刷新计划 directly replans without opening PlanningSheet on success',
        (tester) async {
      final now = DateTime.now();
      final task = Task(
        uid: 'task-1',
        startTime: now,
        endTime: now.add(const Duration(days: 1)),
        repeatEndsTime: now.add(const Duration(days: 1)),
        timeNeeded: const Duration(minutes: 30),
      );
      tasks.assignAll([task]);

      await tester.pumpWidget(CupertinoApp(
        home: FlowPage(),
      ));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('刷新计划'));
      await tester.pumpAndSettle();

      // 不打开规划面板
      expect(find.byType(PlanningSheet), findsNothing);
      // 不弹出错误弹窗
      expect(find.byType(CupertinoAlertDialog), findsNothing);

      // 直接重排生成了 flow 并落盘
      expect(flows.any((f) => f.fromUid == 'task-1'), isTrue);
      expect(db.saves, greaterThanOrEqualTo(1));

      await Get.delete<FlowController>(force: true);
    });

    testWidgets('Button A: 刷新计划 shows alert dialog and preserves old plan when insufficient time',
        (tester) async {
      final now = DateTime.now();
      final task = Task(
        uid: 'impossible-task',
        startTime: now,
        endTime: now.add(const Duration(minutes: 5)),
        repeatEndsTime: now.add(const Duration(minutes: 5)),
        timeNeeded: const Duration(hours: 10),
      );
      tasks.assignAll([task]);

      final oldPlan = Period(
        uid: 'old-plan-1',
        fromUid: 'impossible-task',
        type: PeriodType.flow,
        startTime: now,
        endTime: now.add(const Duration(minutes: 5)),
      );
      flows.assignAll([oldPlan]);

      await tester.pumpWidget(CupertinoApp(
        home: FlowPage(),
      ));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('刷新计划'));
      await tester.pumpAndSettle();

      // 不打开规划面板
      expect(find.byType(PlanningSheet), findsNothing);

      // 弹出警告提示可用时间不足
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('可用时间不足'), findsOneWidget);
      expect(find.textContaining('现有安排已保留'), findsOneWidget);

      // 现有安排保留不动
      expect(flows.single.uid, 'old-plan-1');

      // 点击确定关闭弹窗
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);

      await Get.delete<FlowController>(force: true);
    });

    testWidgets('Button A: 刷新计划 shows retry alert dialog when an exception is thrown',
        (tester) async {
      // 预先注册会抛出异常的 FlowController
      Get.put<FlowController>(ThrowingFlowController());

      await tester.pumpWidget(CupertinoApp(
        home: FlowPage(),
      ));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('刷新计划'));
      await tester.pumpAndSettle();

      expect(find.byType(PlanningSheet), findsNothing);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('暂时无法完成规划，请稍后重试。'), findsOneWidget);

      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);

      await Get.delete<FlowController>(force: true);
    });
  });
}
