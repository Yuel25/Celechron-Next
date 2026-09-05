import 'dart:io';

import 'package:celechron/database/adapters/deadline_adapter.dart';
import 'package:celechron/database/adapters/duration_adapter.dart';
import 'package:celechron/database/adapters/period_adapter.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/task.dart';
import 'package:hive/hive.dart';

Future<DatabaseHelper> openTaskFlowDatabase(Directory directory) async {
  Hive.init(directory.path);
  if (!Hive.isAdapterRegistered(6)) {
    Hive.registerAdapter(DeadlineAdapter());
    Hive.registerAdapter(DeadlineStatusAdapter());
    Hive.registerAdapter(DeadlineTypeAdapter());
    Hive.registerAdapter(DeadlineRepeatTypeAdapter());
    Hive.registerAdapter(DurationAdapter());
    Hive.registerAdapter(PeriodAdapter());
    Hive.registerAdapter(PeriodTypeAdapter());
  }
  final db = DatabaseHelper();
  db.flowBox = await Hive.openBox(db.dbFlow);
  db.taskBox = await Hive.openBox(db.dbTask);
  db.optionsBox = await Hive.openBox(db.dbOptions);
  return db;
}

Task sampleTask(DateTime start, {Duration spent = Duration.zero}) => Task(
      uid: 'task',
      startTime: start,
      endTime: start.add(const Duration(days: 1)),
      repeatEndsTime: start.add(const Duration(days: 1)),
      timeNeeded: const Duration(hours: 2),
      timeSpent: spent,
    );
