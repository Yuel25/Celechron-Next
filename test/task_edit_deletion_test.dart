import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/task.dart';
import 'package:celechron/page/flow/flow_controller.dart';
import 'package:celechron/page/task/task_controller.dart';
import 'package:celechron/page/task/task_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'flow_controller_test.dart' show MemoryDatabase;
import 'task_flow_fixture.dart';

void main() {
  late DateTime now;
  late MemoryDatabase db;
  late RxList<Task> tasks;
  late RxList<Period> flows;

  setUp(() {
    now = DateTime(2030, 9, 5, 10);
    db = MemoryDatabase();
    tasks = <Task>[].obs;
    flows = <Period>[].obs;

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

  group('Task deletion contract & propagation', () {
    test(
        'TaskController contract: status==deleted via copy removes task from taskList and persists',
        () async {
      // 覆盖 Controller 侧契约：
      // 当编辑页返回 status == TaskStatus.deleted 的任务对象后，
      // deadline.copy(res) 将 deleted 状态传播到原任务实例，
      // 随后 TaskController.updateDeadlineList 会将该任务从 taskList 中移除并落盘到数据库。
      final targetTask = sampleTask(now)..summary = '待删除任务';
      final keepTask = sampleTask(now)
        ..uid = 'keep-task'
        ..summary = '保留任务';
      tasks.assignAll([targetTask, keepTask]);

      final taskController = TaskController();

      // 模拟 TaskEditPage.removeAndExit 返回的结果 (status == TaskStatus.deleted)
      final editResult = targetTask.copyWith()..status = TaskStatus.deleted;

      // 模拟卡片回调执行 copy 传播删除状态
      targetTask.copy(editResult);
      expect(targetTask.status, TaskStatus.deleted);

      // 执行 controller 的 updateDeadlineList 契约
      final changed = taskController.updateDeadlineList();

      expect(changed, isTrue);
      expect(tasks.any((t) => t.uid == targetTask.uid), isFalse);
      expect(tasks.any((t) => t.uid == keepTask.uid), isTrue);
      expect(tasks.length, 1);

      // 验证已持久化到数据库
      expect(db.tasks.any((t) => t.uid == targetTask.uid), isFalse);
      expect(db.tasks.any((t) => t.uid == keepTask.uid), isTrue);

      await Get.delete<TaskController>(force: true);
    });

    testWidgets(
        'View onTap integration: tapping card -> TaskEditPage -> 删除任务 removes task from list and DB',
        (tester) async {
      // 覆盖视图层 onTap 传播链路：
      // 卡片点击进入 TaskEditPage，在编辑页内点击"删除任务"，
      // 编辑页通过 Navigator.pop(now) 返回 status==deleted 的任务。
      // onTap 收到返回值后无条件 copy(res)，让 deleted 状态传播到原任务实例，
      // 进而触发 updateDeadlineList 移除任务并落盘。
      final targetTask = sampleTask(now)..summary = '点击删除的任务';
      final keepTask = sampleTask(now)
        ..uid = 'keep-task'
        ..summary = '不应被删除的任务';
      tasks.assignAll([targetTask, keepTask]);

      final page = TaskPage();

      await tester.pumpWidget(CupertinoApp(
        home: CupertinoPageScaffold(
          child: Builder(
            builder: (context) => Obx(
              () => ListView(
                children: [
                  for (final t in tasks)
                    page.createCard(
                      context,
                      t,
                      CupertinoColors.activeBlue,
                      null,
                    ),
                ],
              ),
            ),
          ),
        ),
      ));

      expect(find.text('点击删除的任务'), findsOneWidget);
      expect(find.text('不应被删除的任务'), findsOneWidget);

      // 点击目标任务卡片进入编辑页（触发 onTap）
      await tester.tap(find.text('点击删除的任务'));
      await tester.pumpAndSettle();

      // 编辑页应展示"删除任务"按钮
      final deleteButton = find.text('删除任务');
      expect(deleteButton, findsOneWidget);

      // 点击"删除任务"
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      // 验证已从 taskList 与 UI 移除
      expect(find.text('点击删除的任务'), findsNothing);
      expect(find.text('不应被删除的任务'), findsOneWidget);
      expect(tasks.any((t) => t.uid == targetTask.uid), isFalse);
      expect(tasks.any((t) => t.uid == keepTask.uid), isTrue);

      // 验证已落盘且持久化数据中已排除被删任务
      expect(db.tasks.any((t) => t.uid == targetTask.uid), isFalse);
      expect(db.tasks.any((t) => t.uid == keepTask.uid), isTrue);

      // 清理控制器及其定时器
      await Get.delete<TaskController>(force: true);
      await Get.delete<FlowController>(force: true);
    });
  });
}
