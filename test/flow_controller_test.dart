import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/task.dart';
import 'package:celechron/page/flow/flow_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'task_flow_fixture.dart';

class MemoryDatabase extends DatabaseHelper {
  List<Task> tasks = [];
  List<Period> flows = [];
  int saves = 0;

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

class FakeScholar extends Scholar {
  List<Period> mockPeriods = [];
  @override
  List<Period> get periods => mockPeriods;
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
  late Rx<FakeScholar> scholar;

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
          endTime: now.add(const Duration(minutes: 40))),
      Period(
          uid: 'old-virtual',
          type: PeriodType.virtual,
          startTime: now.subtract(const Duration(minutes: 10)),
          endTime: now.subtract(const Duration(minutes: 5))),
    ].obs;
    scholar = FakeScholar().obs;
    Get.put<DatabaseHelper>(db, tag: 'db');
    Get.put<Rx<Scholar>>(scholar, tag: 'scholar');
    Get.put(tasks, tag: 'taskList');
    Get.put(flows, tag: 'flowList');
    Get.put(now.obs, tag: 'taskListLastUpdate');
    Get.put(now.obs, tag: 'flowListLastUpdate');
  });
  tearDown(() async => Get.reset());

  test('flowList clears historical flow and virtual periods on walkFlowList',
      () {
    expect(flows.any((flow) => flow.type == PeriodType.flow), isTrue);
    expect(flows.any((flow) => flow.type == PeriodType.virtual), isTrue);

    final controller = FlowController(now: () => now);
    controller.walkFlowList();

    expect(flows.any((flow) => flow.type == PeriodType.flow), isFalse);
    expect(flows.any((flow) => flow.type == PeriodType.virtual), isFalse);
    expect(flows, isEmpty);
  });

  test('walkFlowList populates scholar courses and fixed tasks into flowList',
      () {
    scholar.value.mockPeriods = [
      Period(
        uid: 'course-1',
        type: PeriodType.classes,
        startTime: now.add(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 2)),
      ),
    ];
    tasks.add(Task(
      uid: 'fixed-1',
      type: TaskType.fixed,
      startTime: now.add(const Duration(hours: 3)),
      endTime: now.add(const Duration(hours: 4)),
      repeatEndsTime: now.add(const Duration(days: 7)),
    ));

    final controller = FlowController(now: () => now);
    controller.refreshScholarFlowList();
    controller.walkFlowList();

    expect(flows.length, 2);
    expect(flows[0].type, PeriodType.classes);
    expect(flows[0].uid, 'course-1');
    expect(flows[1].type, PeriodType.user);
    expect(flows[1].fromUid, 'fixed-1');
    expect(db.saves, greaterThan(0));
  });

  testWidgets('idle ticks do not walk; external task edits do',
      (tester) async {
    final controller = Get.put(CountingFlowController(now: () => now));
    expect(controller.walks, 1);
    for (var second = 0; second < 5; second++) {
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    expect(controller.walks, 1);
    tasks.add(Task(
      uid: 'fixed-2',
      type: TaskType.fixed,
      startTime: now.add(const Duration(hours: 1)),
      endTime: now.add(const Duration(hours: 2)),
      repeatEndsTime: now.add(const Duration(days: 7)),
    ));
    tasks.refresh();
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.walks, 2);
    expect(flows.any((f) => f.fromUid == 'fixed-2'), isTrue);
    await Get.delete<CountingFlowController>();
  });

  testWidgets('scholar updates trigger flow list refresh and walk',
      (tester) async {
    final controller = Get.put(CountingFlowController(now: () => now));
    expect(controller.walks, 1);
    scholar.value.mockPeriods = [
      Period(
        uid: 'course-new',
        type: PeriodType.classes,
        startTime: now.add(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 2)),
      ),
    ];
    scholar.refresh();
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.walks, 2);
    expect(flows.any((e) => e.uid == 'course-new'), isTrue);
    await Get.delete<CountingFlowController>();
  });

  testWidgets('editing fixed task triggers walk and updates flowList timeline',
      (tester) async {
    final fixedTask = Task(
      uid: 'fixed-edit-test',
      summary: '旧固定日程',
      type: TaskType.fixed,
      startTime: now.add(const Duration(hours: 1)),
      endTime: now.add(const Duration(hours: 2)),
      repeatEndsTime: now.add(const Duration(days: 7)),
    );
    tasks.add(fixedTask);
    final controller = Get.put(CountingFlowController(now: () => now));
    expect(controller.walks, 1);
    expect(
        flows.any(
            (f) => f.fromUid == 'fixed-edit-test' && f.summary == '旧固定日程'),
        isTrue);

    // 模拟从日历页或编辑页修改固定日程后的通知联动
    fixedTask.summary = '新固定日程';
    tasks.refresh();

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(controller.walks, 2);
    expect(
        flows.any(
            (f) => f.fromUid == 'fixed-edit-test' && f.summary == '新固定日程'),
        isTrue);
    await Get.delete<CountingFlowController>();
  });
}
