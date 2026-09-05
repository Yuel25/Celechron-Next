import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/task.dart';
import 'package:celechron/page/flow/flow_controller.dart';
import 'package:celechron/page/task/task_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'task_flow_fixture.dart';

class MemoryDatabase extends DatabaseHelper {
  List<Task> tasks = [];
  List<Period> flows = [];
  int saves = 0;

  @override
  Duration getWorkTime() => const Duration(minutes: 45);
  @override
  Duration getRestTime() => const Duration(minutes: 15);
  @override
  Map<DateTime, DateTime> getAllowTime() =>
      {DateTime(0, 1, 1, 8): DateTime(0, 1, 1, 9)};
  @override
  Future<void> saveTaskFlowSnapshot(
      {required List<Task> tasks,
      required List<Period> flows,
      required DateTime taskUpdatedAt,
      required DateTime flowUpdatedAt}) async {
    saves++;
    this.tasks = tasks.map((task) => task.copyWith()).toList();
    this.flows = flows.map((flow) => flow.copyWith()).toList();
  }
}

class CountingFlowController extends FlowController {
  CountingFlowController({required super.now});
  int walks = 0;
  @override
  void walkFlowList() {
    walks++;
    super.walkFlowList();
  }
}

void main() {
  late DateTime now;
  late MemoryDatabase db;
  late RxList<Task> tasks;
  late RxList<Period> flows;

  setUp(() {
    now = DateTime(2030, 1, 1, 8);
    db = MemoryDatabase();
    tasks = <Task>[sampleTask(now)].obs;
    flows = <Period>[
      Period(
          uid: 'old-plan',
          fromUid: 'task',
          type: PeriodType.flow,
          startTime: now.subtract(const Duration(minutes: 5)),
          endTime: now.add(const Duration(minutes: 40)))
    ].obs;
    Get.put<DatabaseHelper>(db, tag: 'db');
    Get.put(Scholar().obs, tag: 'scholar');
    Get.put(tasks, tag: 'taskList');
    Get.put(flows, tag: 'flowList');
    Get.put(now.obs, tag: 'taskListLastUpdate');
    Get.put(now.obs, tag: 'flowListLastUpdate');
  });
  tearDown(() async => Get.reset());

  test('insufficient time preserves old plan and does not save', () {
    final controller = FlowController(now: () => now);
    final original = flows.single;
    tasks.single.endTime = now.add(const Duration(hours: 1));
    expect(controller.generateNewFlowList(now), -1);
    expect(flows.single, same(original));
    expect(db.saves, 0);
  });

  test('successful planning replaces old plan and saves matching state',
      () async {
    tasks.single.timeNeeded = const Duration(minutes: 30);
    final controller = FlowController(now: () => now);
    expect(controller.generateNewFlowList(now), 15);
    await controller.saveFlowListToDb();
    expect(flows.any((flow) => flow.uid == 'old-plan'), isFalse);
    expect(db.flows.single.fromUid, 'task');
    expect(db.tasks.single.timeSpent, Duration.zero);
  });

  testWidgets('progress ticks do not walk; external task edits do',
      (tester) async {
    final controller = Get.put(CountingFlowController(now: () => now));
    expect(controller.walks, 1);
    for (var second = 0; second < 5; second++) {
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    expect(controller.walks, 1);
    expect(tasks.single.timeSpent, const Duration(minutes: 5, seconds: 5));
    tasks.single.summary = 'changed';
    tasks.refresh();
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.walks, 2);
    expect(flows.single.summary, 'changed');
    await Get.delete<CountingFlowController>();
  });

  testWidgets('task-page save and restart do not double-count progress',
      (tester) async {
    Get.put(CountingFlowController(now: () => now));
    now = now.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    // A task edit can save between the flow controller's 15-second snapshots.
    final taskController = TaskController();
    await taskController.saveDeadlineListToDb();
    expect(db.tasks.single.timeSpent, const Duration(minutes: 5, seconds: 5));
    expect(db.flows.single.lastUpdateTime, now);
    await Get.delete<CountingFlowController>();
    tasks.assignAll(db.tasks.map((task) => task.copyWith()));
    flows.assignAll(db.flows.map((flow) => flow.copyWith()));
    now = now.add(const Duration(seconds: 10));
    Get.put(CountingFlowController(now: () => now));
    expect(tasks.single.timeSpent, const Duration(minutes: 5, seconds: 15));
    await Get.delete<CountingFlowController>();
  });

  testWidgets('clock rollback never subtracts or re-accrues progress',
      (tester) async {
    Get.put(CountingFlowController(now: () => now));
    final checkpoint = now;
    now = now.subtract(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(tasks.single.timeSpent, const Duration(minutes: 5));
    expect(flows.single.lastUpdateTime, checkpoint);
    now = checkpoint.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(tasks.single.timeSpent, const Duration(minutes: 5, seconds: 1));
    await Get.delete<CountingFlowController>();
  });

  testWidgets('completed period saves its final progress with its removal',
      (tester) async {
    Get.put(CountingFlowController(now: () => now));
    now = now.add(const Duration(minutes: 41));
    await tester.pump(const Duration(seconds: 1));
    expect(flows, isEmpty);
    expect(db.flows, isEmpty);
    expect(db.tasks.single.timeSpent, const Duration(minutes: 45));
    await Get.delete<CountingFlowController>();
  });
}
