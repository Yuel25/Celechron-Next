import 'dart:io';
import 'package:celechron/database/adapters/deadline_adapter.dart';
import 'package:celechron/database/adapters/duration_adapter.dart';
import 'package:celechron/database/adapters/period_adapter.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/task.dart';
import 'package:celechron/page/flow/flow_controller.dart';
import 'package:celechron/page/task/task_controller.dart';
import 'package:celechron/page/task/task_view.dart';
import 'package:celechron/widget/agenda_cards.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'flow_controller_test.dart' show MemoryDatabase;
import 'task_flow_fixture.dart';

class FakeLegacyBinaryReader implements BinaryReader {
  final Map<int, dynamic> _fields;
  late final List<int> _keys;
  int _keyIndex = 0;
  bool _readingKey = true;

  FakeLegacyBinaryReader(this._fields) {
    _keys = _fields.keys.toList();
  }

  @override
  int readByte() {
    if (_keyIndex == 0 && _readingKey) {
      // First readByte() is numOfFields
      _readingKey = false;
      return _keys.length;
    }
    if (!_readingKey) {
      // Reading a field key
      final key = _keys[_keyIndex];
      _readingKey = true;
      return key;
    }
    throw UnimplementedError();
  }

  @override
  dynamic read([int? typeId]) {
    final value = _fields[_keys[_keyIndex]];
    _keyIndex++;
    _readingKey = false;
    return value;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  group('Task model: focusedSince & effectiveTimeSpent', () {
    test('effectiveTimeSpent equals timeSpent when focusedSince is null', () {
      final task = sampleTask(now, spent: const Duration(minutes: 20));
      expect(task.focusedSince, isNull);
      expect(task.effectiveTimeSpent, const Duration(minutes: 20));
    });

    test('effectiveTimeSpent accrues elapsed time when focusedSince is set', () {
      final start = now.subtract(const Duration(minutes: 15));
      final task = sampleTask(now, spent: const Duration(minutes: 20))
        ..focusedSince = start;

      // At 'now', effectiveTimeSpent = 20m + 15m = 35m
      expect(task.effectiveTimeSpentAt(now), const Duration(minutes: 35));
    });

    test('effectiveTimeSpent clamps negative difference to zero', () {
      final future = now.add(const Duration(minutes: 10));
      final task = sampleTask(now, spent: const Duration(minutes: 20))
        ..focusedSince = future;

      // When clock is before focusedSince, extra is Duration.zero
      expect(task.effectiveTimeSpentAt(now), const Duration(minutes: 20));
    });

    test('getProgress increases with effectiveTimeSpent and clamps to 1.0', () {
      final task = sampleTask(now, spent: const Duration(hours: 1))
        ..timeNeeded = const Duration(hours: 2); // 50%
      expect(task.getProgress(now), 0.5);

      // Focus for 30 minutes -> 1h30m / 2h = 75%
      task.focusedSince = now;
      final later = now.add(const Duration(minutes: 30));
      expect(task.getProgress(later), 0.75);

      // Focus for 2 hours -> (1h + 2h) = 3h >= 2h -> clamp 1.0
      final overtime = now.add(const Duration(hours: 2));
      expect(task.getProgress(overtime), 1.0);
    });

    test('copy, copyWith, and reset handle focusedSince correctly', () {
      final task1 = sampleTask(now)..focusedSince = now;
      final task2 = sampleTask(now);
      task2.copy(task1);
      expect(task2.focusedSince, now);

      final task3 = task1.copyWith(focusedSince: now.add(const Duration(minutes: 5)));
      expect(task3.focusedSince, now.add(const Duration(minutes: 5)));

      task1.reset();
      expect(task1.focusedSince, isNull);
    });

    test('differentForFlow does not include focusedSince in comparison', () {
      final task1 = sampleTask(now)..focusedSince = now;
      final task2 = sampleTask(now)..focusedSince = null;
      // Focus anchor change should NOT trigger differentForFlow
      expect(task1.differentForFlow(task2), isFalse);
    });
  });

  group('TaskController: startFocus & pauseFocus', () {
    test('startFocus sets anchor, enforces single timer, persists and refreshes', () {
      DateTime clock = now;
      final controller = TaskController(now: () => clock);

      final task1 = sampleTask(now)..uid = 't1';
      final task2 = sampleTask(now)..uid = 't2';
      tasks.assignAll([task1, task2]);

      // Start focus on task1
      controller.startFocus(task1);
      expect(task1.focusedSince, clock);
      expect(db.saves, greaterThan(0));

      // Advance clock by 10 minutes
      clock = clock.add(const Duration(minutes: 10));

      // Start focus on task2 -> must pause task1 and settle its timeSpent
      controller.startFocus(task2);
      expect(task1.focusedSince, isNull);
      expect(task1.timeSpent, const Duration(minutes: 10));
      expect(task2.focusedSince, clock);
    });

    test('startFocus only applies to running deadline tasks', () {
      final controller = TaskController(now: () => now);

      final completedTask = sampleTask(now)..status = TaskStatus.completed;
      final fixedTask = sampleTask(now)..type = TaskType.fixed;
      tasks.assignAll([completedTask, fixedTask]);

      controller.startFocus(completedTask);
      expect(completedTask.focusedSince, isNull);

      controller.startFocus(fixedTask);
      expect(fixedTask.focusedSince, isNull);
    });

    test('pauseFocus accrues effectiveTimeSpent, clears anchor, and saves to DB', () {
      DateTime clock = now;
      final controller = TaskController(now: () => clock);

      final task = sampleTask(now, spent: const Duration(minutes: 15))..uid = 't1';
      tasks.assignAll([task]);

      controller.startFocus(task);
      expect(task.focusedSince, clock);

      // Advance clock by 25 minutes
      clock = clock.add(const Duration(minutes: 25));

      final prevSaves = db.saves;
      controller.pauseFocus(task);

      expect(task.focusedSince, isNull);
      // 15m + 25m = 40m
      expect(task.timeSpent, const Duration(minutes: 40));
      expect(db.saves, greaterThan(prevSaves));
      expect(db.tasks.firstWhere((t) => t.uid == 't1').timeSpent, const Duration(minutes: 40));
    });

    test('pauseFocus automatically sets status to completed when timeSpent reaches timeNeeded', () {
      DateTime clock = now;
      final controller = TaskController(now: () => clock);

      // Needs 1 hour, already spent 50 minutes
      final task = sampleTask(now, spent: const Duration(minutes: 50))
        ..timeNeeded = const Duration(hours: 1)
        ..uid = 't1';
      tasks.assignAll([task]);

      controller.startFocus(task);

      // Advance clock by 15 minutes (total 65 minutes >= 60 minutes)
      clock = clock.add(const Duration(minutes: 15));

      controller.pauseFocus(task);

      expect(task.focusedSince, isNull);
      expect(task.timeSpent, const Duration(hours: 1)); // clamped to timeNeeded
      expect(task.status, TaskStatus.completed);
      expect(db.tasks.firstWhere((t) => t.uid == 't1').status, TaskStatus.completed);
    });

    test('pauseFocus returns early if not focusing', () {
      final controller = TaskController(now: () => now);
      final task = sampleTask(now, spent: const Duration(minutes: 10));
      final prevSaves = db.saves;

      controller.pauseFocus(task);
      expect(task.focusedSince, isNull);
      expect(task.timeSpent, const Duration(minutes: 10));
      expect(db.saves, prevSaves);
    });
  });

  group('TaskController: tick & 15s throttle', () {
    test('tick refreshes taskList every tick and saves DB at 15s throttle', () {
      DateTime clock = now;
      final controller = TaskController(now: () => clock);

      final task = sampleTask(now)..uid = 't1';
      tasks.assignAll([task]);

      controller.startFocus(task);
      final savesAfterStart = db.saves;

      // 5 seconds later: tick should NOT save to DB (throttle < 15s)
      clock = clock.add(const Duration(seconds: 5));
      controller.onTickForTesting();
      expect(db.saves, savesAfterStart);

      // 10 seconds later (total 15s since start): tick SHOULD save to DB
      clock = clock.add(const Duration(seconds: 10));
      controller.onTickForTesting();
      expect(db.saves, savesAfterStart + 1);

      // 5 seconds later: tick should not save
      clock = clock.add(const Duration(seconds: 5));
      controller.onTickForTesting();
      expect(db.saves, savesAfterStart + 1);

      // Another 10 seconds later (total 15s since last save): tick should save again
      clock = clock.add(const Duration(seconds: 10));
      controller.onTickForTesting();
      expect(db.saves, savesAfterStart + 2);
    });

    test('updateDeadlineList does not flag changed for ongoing focus ticks', () {
      DateTime clock = now;
      final controller = TaskController(now: () => clock);

      final task = sampleTask(now)..uid = 't1';
      tasks.assignAll([task]);
      controller.startFocus(task);

      clock = clock.add(const Duration(seconds: 1));
      final changed = controller.updateDeadlineList();
      // Should be false so we do not trigger sorting / full write every single second
      expect(changed, isFalse);
    });
  });

  group('DeadlineAdapter Hive serialization', () {
    test('roundtrip with focusedSince != null and == null', () async {
      final tempDir = Directory.systemTemp.createTempSync('hive_focus_test');
      addTearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(6)) {
        Hive.registerAdapter(DeadlineAdapter());
        Hive.registerAdapter(DeadlineStatusAdapter());
        Hive.registerAdapter(DeadlineTypeAdapter());
        Hive.registerAdapter(DeadlineRepeatTypeAdapter());
        Hive.registerAdapter(DurationAdapter());
        Hive.registerAdapter(PeriodAdapter());
        Hive.registerAdapter(PeriodTypeAdapter());
      }

      final box = await Hive.openBox<Task>('focus_box');

      final taskWithFocus = sampleTask(now)
        ..uid = 'task_with_focus'
        ..focusedSince = now;

      final taskWithoutFocus = sampleTask(now)
        ..uid = 'task_without_focus'
        ..focusedSince = null;

      await box.put(taskWithFocus.uid, taskWithFocus);
      await box.put(taskWithoutFocus.uid, taskWithoutFocus);

      final loadedWithFocus = box.get('task_with_focus')!;
      final loadedWithoutFocus = box.get('task_without_focus')!;

      expect(loadedWithFocus.focusedSince, now);
      expect(loadedWithoutFocus.focusedSince, isNull);

      await box.close();
    });

    test('reading legacy record without field 16 defaults focusedSince to null', () {
      final adapter = DeadlineAdapter();
      final legacyFields = <int, dynamic>{
        0: 'legacy_task',
        1: TaskStatus.running,
        2: 'legacy description',
        3: const Duration(minutes: 30),
        4: const Duration(hours: 2),
        5: now,
        6: 'location',
        7: 'summary',
        8: true,
        9: TaskType.deadline,
        10: now,
        11: TaskRepeatType.norepeat,
        12: 1,
        13: now,
        14: true,
        15: 'some_parent_uid',
        // field 16 is intentionally absent
      };

      final fakeReader = FakeLegacyBinaryReader(legacyFields);
      final readTask = adapter.read(fakeReader);

      expect(readTask.uid, 'legacy_task');
      expect(readTask.fromUid, 'some_parent_uid');
      expect(readTask.focusedSince, isNull);
    });
  });

  group('Widget integration: TaskCardContent & TaskPage', () {
    testWidgets('TaskCardContent renders play button for running deadline and toggles focus', (tester) async {
      bool toggled = false;
      bool focusToggled = false;

      final task = sampleTask(now, spent: const Duration(minutes: 10))
        ..timeNeeded = const Duration(hours: 1);

      await tester.pumpWidget(CupertinoApp(
        home: CupertinoPageScaffold(
          child: TaskCardContent(
            task: task,
            now: now,
            color: CupertinoColors.activeBlue,
            onToggle: () => toggled = true,
            onToggleFocus: () => focusToggled = true,
            isFocusing: false,
          ),
        ),
      ));

      expect(find.byIcon(CupertinoIcons.play_fill), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.pause_fill), findsNothing);

      await tester.tap(find.byIcon(CupertinoIcons.play_fill));
      await tester.pump();
      expect(focusToggled, isTrue);
      expect(toggled, isFalse);
    });

    testWidgets('TaskCardContent displays pause icon when isFocusing is true and shows remaining based on effectiveTimeSpent', (tester) async {
      // 1 hour needed, 10 min spent, focused for 20 min -> remaining = 30 min
      final task = sampleTask(now, spent: const Duration(minutes: 10))
        ..timeNeeded = const Duration(hours: 1)
        ..focusedSince = now.subtract(const Duration(minutes: 20));

      await tester.pumpWidget(CupertinoApp(
        home: CupertinoPageScaffold(
          child: TaskCardContent(
            task: task,
            now: now,
            color: CupertinoColors.activeBlue,
            onToggle: () {},
            onToggleFocus: () {},
            isFocusing: true,
          ),
        ),
      ));

      expect(find.byIcon(CupertinoIcons.pause_fill), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.play_fill), findsNothing);
      expect(find.text('还需 30 分钟'), findsOneWidget);
    });

    test('deadlineProgress in TaskPage reflects effectiveTimeSpent', () async {
      final page = TaskPage();
      final task = sampleTask(now, spent: const Duration(minutes: 10))
        ..timeNeeded = const Duration(hours: 1)
        ..focusedSince = now.subtract(const Duration(minutes: 20));

      // With effectiveTimeSpent = 30 min (50%), remaining = 30 min
      final progressText = page.deadlineProgress(task, now);
      expect(progressText, contains('50% 已完成'));
      expect(progressText, contains('还要 30 分钟'));

      // Also test real-time clock without passing now
      final realNow = DateTime.now();
      final realTask = sampleTask(realNow, spent: const Duration(minutes: 10))
        ..timeNeeded = const Duration(hours: 1)
        ..focusedSince = realNow.subtract(const Duration(minutes: 20));
      final realProgress = page.deadlineProgress(realTask);
      expect(realProgress, contains('50% 已完成'));
      expect(realProgress, matches(r'还要 (29|30) 分钟'));

      await Get.deleteAll(force: true);
    });

    testWidgets('tap play button in TaskPage sets focusedSince, changes icon to pause, then tap pause settles', (tester) async {
      DateTime clock = now;
      Get.put(TaskController(now: () => clock));
      Get.put(FlowController(now: () => clock));

      final task = sampleTask(now, spent: Duration.zero)
        ..uid = 't_e2e'
        ..timeNeeded = const Duration(hours: 1);
      tasks.assignAll([task]);

      await tester.pumpWidget(CupertinoApp(
        home: TaskPage(),
      ));

      final playFinder = find.byIcon(CupertinoIcons.play_fill);
      final pauseFinder = find.byIcon(CupertinoIcons.pause_fill);
      expect(playFinder, findsOneWidget);
      expect(pauseFinder, findsNothing);
      expect(task.focusedSince, isNull);

      // Tap play button
      await tester.tap(playFinder);
      await tester.pump();

      expect(task.focusedSince, isNotNull);
      expect(pauseFinder, findsOneWidget);
      expect(playFinder, findsNothing);

      // Advance clock by 10 minutes
      clock = clock.add(const Duration(minutes: 10));

      // Tap pause button
      await tester.tap(pauseFinder);
      await tester.pump();

      expect(task.focusedSince, isNull);
      expect(task.timeSpent, const Duration(minutes: 10));
      expect(playFinder, findsOneWidget);
      expect(pauseFinder, findsNothing);

      await Get.delete<TaskController>(force: true);
      await Get.delete<FlowController>(force: true);
    });

    testWidgets('suspended task shows play button and transitions to running + starts focus on tap', (tester) async {
      DateTime clock = now;
      Get.put(TaskController(now: () => clock));
      Get.put(FlowController(now: () => clock));

      final task = sampleTask(now, spent: const Duration(minutes: 5))
        ..uid = 't_suspended'
        ..status = TaskStatus.suspended
        ..timeNeeded = const Duration(hours: 1);
      tasks.assignAll([task]);

      await tester.pumpWidget(CupertinoApp(
        home: TaskPage(),
      ));

      final playFinder = find.byIcon(CupertinoIcons.play_fill);
      final pauseFinder = find.byIcon(CupertinoIcons.pause_fill);
      expect(playFinder, findsOneWidget);
      expect(pauseFinder, findsNothing);

      // Tap play button on suspended task
      await tester.tap(playFinder);
      await tester.pump();

      expect(task.status, TaskStatus.running);
      expect(task.focusedSince, isNotNull);
      expect(pauseFinder, findsOneWidget);
      expect(playFinder, findsNothing);

      await Get.delete<TaskController>(force: true);
      await Get.delete<FlowController>(force: true);
    });
  });

  group('Cold start recovery with focusedSince', () {
    test('offline task not expired continues focus tracking', () {
      final task = sampleTask(now, spent: Duration.zero)
        ..uid = 't_cold_continue'
        ..timeNeeded = const Duration(hours: 1)
        ..endTime = now.add(const Duration(hours: 2))
        ..focusedSince = now.subtract(const Duration(minutes: 10));
      tasks.assignAll([task]);

      final controller = TaskController(now: () => now);
      expect(task.focusedSince, now.subtract(const Duration(minutes: 10)));
      expect(task.effectiveTimeSpentAt(now), const Duration(minutes: 10));
      expect(task.status, TaskStatus.running);

      controller.onTickForTesting();
      expect(task.status, TaskStatus.running);
      expect(task.focusedSince, isNotNull);
    });

    test('offline task crossed DDL settles to failed on first tick', () {
      final task = sampleTask(now, spent: const Duration(minutes: 10))
        ..uid = 't_cold_failed'
        ..timeNeeded = const Duration(hours: 1)
        ..endTime = now.subtract(const Duration(minutes: 5))
        ..focusedSince = now.subtract(const Duration(minutes: 25));
      tasks.assignAll([task]);

      final controller = TaskController(now: () => now);
      controller.onTickForTesting();

      expect(task.status, TaskStatus.failed);
      expect(task.focusedSince, isNull);
      // Settle up to endTime: (-25m to -5m = 20m). 10m + 20m = 30m
      expect(task.timeSpent, const Duration(minutes: 30));
    });

    test('offline task reached timeNeeded auto completes on first tick', () {
      final task = sampleTask(now, spent: const Duration(minutes: 10))
        ..uid = 't_cold_completed'
        ..timeNeeded = const Duration(minutes: 30)
        ..endTime = now.add(const Duration(hours: 1))
        ..focusedSince = now.subtract(const Duration(minutes: 25));
      tasks.assignAll([task]);

      final controller = TaskController(now: () => now);
      // Effective time spent = 10m + 25m = 35m >= 30m
      controller.onTickForTesting();

      expect(task.status, TaskStatus.completed);
      expect(task.focusedSince, isNull);
      expect(task.timeSpent, const Duration(minutes: 30));
      expect(db.tasks.firstWhere((t) => t.uid == 't_cold_completed').status,
          TaskStatus.completed);
    });
  });

  group('TaskPage long press dialog actions', () {
    testWidgets('long press opens dialog, completed task shows "标记为未完成" and can be uncompleted', (tester) async {
      DateTime clock = now;
      Get.put(TaskController(now: () => clock));
      Get.put(FlowController(now: () => clock));

      final task = sampleTask(now, spent: const Duration(hours: 1))
        ..uid = 't_completed'
        ..summary = '已完成的测试任务'
        ..status = TaskStatus.completed
        ..timeNeeded = const Duration(hours: 1);
      tasks.assignAll([task]);

      await tester.pumpWidget(CupertinoApp(
        home: TaskPage(),
      ));

      // Long press the card
      await tester.longPress(find.text('已完成的测试任务'));
      await tester.pumpAndSettle();

      // Dialog should show '标记为未完成'
      final uncompleteFinder = find.text('标记为未完成');
      expect(uncompleteFinder, findsOneWidget);

      // Tap '标记为未完成'
      await tester.tap(uncompleteFinder);
      await tester.pumpAndSettle();

      expect(task.status, TaskStatus.running);
      expect(task.timeSpent, Duration.zero);
      expect(task.focusedSince, isNull);

      await Get.delete<TaskController>(force: true);
      await Get.delete<FlowController>(force: true);
    });

    testWidgets('long press dialog pause on task reaching timeNeeded does not override to suspended', (tester) async {
      DateTime clock = now;
      Get.put(TaskController(now: () => clock));
      Get.put(FlowController(now: () => clock));

      // Task has 10 min left (50m spent / 60m needed), focused for 5 min (< 60m, so not full yet)
      final task = sampleTask(now, spent: const Duration(minutes: 50))
        ..uid = 't_full_pause'
        ..summary = '即将满额任务'
        ..status = TaskStatus.running
        ..timeNeeded = const Duration(hours: 1)
        ..focusedSince = clock.subtract(const Duration(minutes: 5));
      tasks.assignAll([task]);

      await tester.pumpWidget(CupertinoApp(
        home: TaskPage(),
      ));

      // Long press
      await tester.longPress(find.text('即将满额任务'));
      await tester.pumpAndSettle();

      final pauseAction = find.text('暂停');
      expect(pauseAction, findsOneWidget);

      // Advance clock by 10 minutes so focus duration becomes 15m -> total 65m >= 60m
      clock = clock.add(const Duration(minutes: 10));

      await tester.tap(pauseAction);
      await tester.pumpAndSettle();

      // Task must be completed, NOT suspended!
      expect(task.status, TaskStatus.completed);
      expect(task.focusedSince, isNull);
      expect(task.timeSpent, const Duration(hours: 1));

      await Get.delete<TaskController>(force: true);
      await Get.delete<FlowController>(force: true);
    });
  });
}
