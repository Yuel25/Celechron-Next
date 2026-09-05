import 'dart:io';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/period.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'task_flow_fixture.dart';

class FailingBox implements Box {
  FailingBox(this.delegate);
  final Box delegate;
  bool failNextWrite = false;

  @override
  Future<void> put(dynamic key, dynamic value) {
    if (failNextWrite) {
      failNextWrite = false;
      return Future<void>.error(
          const FileSystemException('simulated interrupted write'));
    }
    return delegate.put(key, value);
  }

  @override
  Future<void> flush() => delegate.flush();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory directory;
  late DatabaseHelper db;
  final start = DateTime(2030, 1, 1, 8);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('task_flow_snapshot_');
    db = await openTaskFlowDatabase(directory);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('legacy state is readable until a complete snapshot replaces it',
      () async {
    final task = sampleTask(start);
    final flow = Period(startTime: start, endTime: task.endTime);
    await db.taskBox.put(db.kTaskList, [task]);
    await db.flowBox.put(db.kFlowList, [flow]);
    await db.taskBox.put(db.kTaskListUpdateTime, start);
    await db.flowBox.put(db.kFlowListUpdateTime, start);
    expect(db.getTaskList().single.timeSpent, Duration.zero);
    expect(db.getFlowList(), hasLength(1));

    task.timeSpent = const Duration(minutes: 5);
    flow.lastUpdateTime = start.add(task.timeSpent);
    await db.saveTaskFlowSnapshot(
        tasks: [task],
        flows: [flow],
        taskUpdatedAt: start,
        flowUpdatedAt: start);
    await Hive.close();
    db = await openTaskFlowDatabase(directory);
    expect(db.getTaskList().single.timeSpent, const Duration(minutes: 5));
    expect(db.getFlowList().single.lastUpdateTime,
        start.add(const Duration(minutes: 5)));
    expect(db.getTaskListUpdateTime(), start);
    expect(db.getFlowListUpdateTime(), start);
  });

  test('queued saves capture both mutable models before awaiting IO', () async {
    final task = sampleTask(start);
    final flow = Period(startTime: start, endTime: task.endTime);
    final first = db.saveTaskFlowSnapshot(
        tasks: [task],
        flows: [flow],
        taskUpdatedAt: start,
        flowUpdatedAt: start);
    task.timeSpent = const Duration(minutes: 10);
    flow.lastUpdateTime = start.add(task.timeSpent);
    final second = db.saveTaskFlowSnapshot(
        tasks: [task],
        flows: [flow],
        taskUpdatedAt: start,
        flowUpdatedAt: start);
    task.timeSpent = const Duration(minutes: 20);
    flow.lastUpdateTime = start.add(task.timeSpent);
    await Future.wait([first, second]);
    await Hive.close();
    db = await openTaskFlowDatabase(directory);
    expect(db.getTaskList().single.timeSpent, const Duration(minutes: 10));
    expect(db.getFlowList().single.lastUpdateTime,
        start.add(const Duration(minutes: 10)));
  });

  test('truncated final Hive record recovers the previous complete pair',
      () async {
    final task = sampleTask(start, spent: const Duration(minutes: 5));
    final flow = Period(
        startTime: start,
        endTime: task.endTime,
        lastUpdateTime: start.add(task.timeSpent));
    Future<void> save() => db.saveTaskFlowSnapshot(
        tasks: [task],
        flows: [flow],
        taskUpdatedAt: start,
        flowUpdatedAt: start);
    await save();
    final file = File(db.flowBox.path!);
    final committedLength = await file.length();
    task.timeSpent = const Duration(minutes: 10);
    flow.lastUpdateTime = start.add(task.timeSpent);
    await save();
    await Hive.close();
    final bytes = await file.readAsBytes();
    expect(bytes.length, greaterThan(committedLength));
    // 模拟进程在写入下一条记录途中被终止，保留半条尾记录。
    await file.writeAsBytes(
        bytes.sublist(
            0, committedLength + (bytes.length - committedLength) ~/ 2),
        flush: true);
    db = await openTaskFlowDatabase(directory);
    expect(db.getTaskList().single.timeSpent, const Duration(minutes: 5));
    expect(db.getFlowList().single.lastUpdateTime,
        start.add(const Duration(minutes: 5)));
  });

  test('failed write leaves old snapshot intact and does not poison the queue',
      () async {
    final task = sampleTask(start);
    final flow = Period(startTime: start, endTime: task.endTime);
    final box = FailingBox(db.flowBox);
    final writer = DatabaseHelper()..flowBox = box;
    Future<void> save() => writer.saveTaskFlowSnapshot(
        tasks: [task],
        flows: [flow],
        taskUpdatedAt: start,
        flowUpdatedAt: start);
    await save();
    box.failNextWrite = true;
    task.timeSpent = const Duration(minutes: 10);
    flow.lastUpdateTime = start.add(task.timeSpent);
    await expectLater(save(), throwsA(isA<FileSystemException>()));
    expect(db.getTaskList().single.timeSpent, Duration.zero);
    expect(db.getFlowList().single.lastUpdateTime, isNull);
    await save();
    await Hive.close();
    db = await openTaskFlowDatabase(directory);
    expect(db.getTaskList().single.timeSpent, const Duration(minutes: 10));
    expect(db.getFlowList().single.lastUpdateTime,
        start.add(const Duration(minutes: 10)));
  });
}
