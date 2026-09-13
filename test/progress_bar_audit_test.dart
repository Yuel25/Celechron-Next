import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/task.dart';
import 'package:celechron/page/task/task_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'flow_controller_test.dart' show MemoryDatabase;
import 'task_flow_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late MemoryDatabase db;
  late RxList<Task> tasks;
  late RxList<Period> flows;

  setUp(() {
    now = DateTime(2030, 9, 5, 10, 0, 0);
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

  group('Focus timer and progress bar audit specifications', () {
    test(
        'focusing deadline task settles elapsed time up to endTime and clears anchor upon expiration',
        () {
      DateTime clock = now;
      final controller = TaskController(now: () => clock);

      // Task needs 1 hour, initially spent 10 minutes, ends at now + 20 minutes
      final task = sampleTask(now, spent: const Duration(minutes: 10))
        ..uid = 't_deadline'
        ..timeNeeded = const Duration(hours: 1)
        ..endTime = now.add(const Duration(minutes: 20));
      tasks.assignAll([task]);

      controller.startFocus(task);
      expect(task.focusedSince, clock);

      // Advance clock past endTime (25 minutes later, 5 minutes past deadline)
      clock = clock.add(const Duration(minutes: 25));

      // Tick detects expired task, settles time up to endTime (20m, not 25m), clears anchor, marks failed
      controller.onTickForTesting();

      expect(task.status, TaskStatus.failed);
      expect(task.focusedSince, isNull);
      // Spent should be 10m + 20m (up to endTime) = 30m, not 35m
      expect(task.timeSpent, const Duration(minutes: 30));

      // Ghost writes must stop: advance another 16 seconds, no periodic write because hasFocusing is false
      final savesBefore = db.saves;
      clock = clock.add(const Duration(seconds: 16));
      controller.onTickForTesting();
      expect(db.saves, savesBefore);
    });

    test(
        'focusing deadline task completing timeNeeded at deadline transitions to completed',
        () {
      DateTime clock = now;
      final controller = TaskController(now: () => clock);

      // Needs 30 minutes, already spent 15 minutes, ends at now + 15 minutes
      final task = sampleTask(now, spent: const Duration(minutes: 15))
        ..uid = 't_just_in_time'
        ..timeNeeded = const Duration(minutes: 30)
        ..endTime = now.add(const Duration(minutes: 15));
      tasks.assignAll([task]);

      controller.startFocus(task);

      // Advance clock past endTime (16 minutes later)
      clock = clock.add(const Duration(minutes: 16));

      controller.onTickForTesting();

      // Settle 15 minutes (capped at endTime) -> timeSpent reaches 30m >= timeNeeded -> completed
      expect(task.timeSpent, const Duration(minutes: 30));
      expect(task.status, TaskStatus.completed);
      expect(task.focusedSince, isNull);
    });

    test(
        'suspendAllDeadline retains completed status when pauseFocus finishes the task',
        () {
      DateTime clock = now;
      final controller = TaskController(now: () => clock);

      // Needs 30 minutes, spent 20 minutes
      final task = sampleTask(now, spent: const Duration(minutes: 20))
        ..uid = 't_suspend'
        ..timeNeeded = const Duration(minutes: 30)
        ..status = TaskStatus.running;
      tasks.assignAll([task]);

      controller.startFocus(task);

      // Advance clock by 15 minutes (total 35 min >= 30 min required)
      clock = clock.add(const Duration(minutes: 15));

      // User triggers suspendAll
      final suspendedCount = controller.suspendAllDeadline(null);

      expect(task.status, TaskStatus.completed);
      expect(task.timeSpent, const Duration(minutes: 30));
      expect(task.focusedSince, isNull);
      expect(suspendedCount, 0,
          reason: 'Completed task should not be counted as suspended');
    });

    test(
        'Task.getProgress for fixed task handles zero duration without returning NaN',
        () {
      final task = Task(
        type: TaskType.fixed,
        startTime: now,
        endTime: now,
        repeatEndsTime: now.add(const Duration(days: 1)),
      );

      final before = task.getProgress(now.subtract(const Duration(seconds: 1)));
      expect(before, 0.0);

      final atNow = task.getProgress(now);
      expect(atNow.isFinite, isTrue);
      expect(atNow, 1.0);

      final after = task.getProgress(now.add(const Duration(seconds: 1)));
      expect(after, 1.0);
    });
  });
}
