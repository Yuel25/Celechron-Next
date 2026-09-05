import 'dart:io';
import 'dart:ui' as ui;

import 'package:celechron/design/agenda_cards.dart';
import 'package:celechron/design/round_rectangle_card.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/page/task/task_view.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/model/task.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'task_flow_fixture.dart';
import 'flow_controller_test.dart' show MemoryDatabase;

void main() {
  final now = DateTime(2030, 9, 5, 10);
  final period = Period(
      summary: '数据结构与算法',
      location: '紫金港 · 东一 302',
      startTime: now.subtract(const Duration(minutes: 20)),
      endTime: now.add(const Duration(minutes: 25)));

  test('relative dates handle tomorrow across the year boundary', () {
    expect(agendaTime(DateTime(2031, 1, 1, 8), DateTime(2030, 12, 31)),
        '明天 08:00');
    expect(agendaTime(DateTime(2029, 9, 5, 8), now), '2029年9月5日 08:00');
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('agenda layout $brightness scale $scale', (tester) async {
        tester.view.reset();
        tester.view.physicalSize =
            Size(scale == 1 ? 390 : 320, scale == 1 ? 1000 : 1900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const previews = bool.fromEnvironment('UI_PREVIEWS');
        if (previews && Platform.isWindows) {
          await tester.runAsync(() async {
            final font = FontLoader('PreviewChinese');
            font.addFont(File('C:/Windows/Fonts/msyh.ttc')
                .readAsBytes()
                .then((bytes) => ByteData.sublistView(bytes)));
            await font.load();
            final icons = FontLoader('packages/cupertino_icons/CupertinoIcons');
            icons.addFont(rootBundle
                .load('packages/cupertino_icons/assets/CupertinoIcons.ttf'));
            await icons.load();
          });
        }
        final boundary = GlobalKey();
        final task = sampleTask(now)
          ..summary = scale == 1 ? '完成算法作业' : '完成数据结构与算法课程的第三次编程作业'
          ..location = ''
          ..timeNeeded = const Duration(minutes: 45)
          ..endTime = now.copyWith(hour: 23, minute: 59);
        await tester.pumpWidget(CupertinoApp(
          theme: CupertinoThemeData(
              brightness: brightness,
              textTheme: previews
                  ? CupertinoTextThemeData(
                      textStyle: TextStyle(
                          fontFamily: 'PreviewChinese',
                          fontSize: 17,
                          color: brightness == Brightness.dark
                              ? CupertinoColors.white
                              : CupertinoColors.black))
                  : null),
          home: MediaQuery(
            data: MediaQueryData(
                size: Size(scale == 1 ? 390 : 320, scale == 1 ? 1000 : 1900),
                textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(
                key: boundary,
                child: CupertinoPageScaffold(
                  backgroundColor: brightness == Brightness.dark
                      ? const Color(0xFF151517)
                      : const Color(0xFFF4F5F8),
                  child: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 20),
                              const Text('接下来',
                                  style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 24),
                              AgendaPeriodCard(
                                  period: period,
                                  now: now,
                                  color: brightness == Brightness.dark
                                      ? const Color(0xFF8D9BFF)
                                      : const Color(0xFF5367D9),
                                  featured: true),
                              const SizedBox(height: 24),
                              const Text('之后的安排',
                                  style: TextStyle(fontSize: 15)),
                              const SizedBox(height: 12),
                              AgendaPeriodCard(
                                  period: period.copyWith(
                                      summary: '线性代数',
                                      startTime:
                                          now.add(const Duration(hours: 2)),
                                      endTime:
                                          now.add(const Duration(hours: 3))),
                                  now: now,
                                  color: const Color(0xFF49857D)),
                              const SizedBox(height: 24),
                              const Text('任务',
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              RoundRectangleCard(
                                  animate: false,
                                  child: TaskCardContent(
                                      task: task,
                                      now: now,
                                      color: const Color(0xFF5367D9),
                                      onToggle: () {})),
                            ])),
                  ),
                )),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('还剩 25 分钟'), findsOneWidget);
        expect(find.text('今天 23:59 截止'), findsOneWidget);
        if (previews) {
          final render = boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await render.toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final file =
                File('.dart_tool/ui-preview/${brightness.name}-$scale.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }

  testWidgets('completion button does not open the parent edit action',
      (tester) async {
    var completed = 0;
    var edited = 0;
    await tester.pumpWidget(CupertinoApp(
        home: CupertinoPageScaffold(
            child: Center(
                child: RoundRectangleCard(
                    animate: false,
                    onTap: () => edited++,
                    child: TaskCardContent(
                        task: sampleTask(now),
                        now: now,
                        color: CupertinoColors.activeBlue,
                        onToggle: () => completed++))))));
    await tester.tap(find.byType(CupertinoButton));
    await tester.pumpAndSettle();
    expect(completed, 1);
    expect(edited, 0);
  });

  testWidgets('task page completion saves status and preserves other plans',
      (tester) async {
    final date = DateTime.now();
    final db = MemoryDatabase();
    final task = sampleTask(date);
    final other = sampleTask(date)..uid = 'other';
    final tasks = [task, other].obs;
    final flows = [
      for (final item in tasks)
        Period(
            uid: item.uid,
            fromUid: item.uid,
            type: PeriodType.flow,
            startTime: date.add(const Duration(hours: 1)),
            endTime: date.add(const Duration(hours: 2)))
    ].obs;
    Get.put<DatabaseHelper>(db, tag: 'db');
    Get.put(Scholar().obs, tag: 'scholar');
    Get.put(tasks, tag: 'taskList');
    Get.put(flows, tag: 'flowList');
    Get.put(date.obs, tag: 'taskListLastUpdate');
    Get.put(date.obs, tag: 'flowListLastUpdate');
    addTearDown(() => Get.reset());
    final page = TaskPage();
    await tester.pumpWidget(CupertinoApp(
        home: CupertinoPageScaffold(
            child: Builder(
                builder: (context) => page.createCard(
                    context, task, CupertinoColors.activeBlue, null)))));
    await tester.tap(find.byType(CupertinoButton));
    await tester.pump();
    expect(task.status, TaskStatus.completed);
    expect(flows.single.fromUid, 'other');
    expect(db.tasks.firstWhere((item) => item.uid == task.uid).status,
        TaskStatus.completed);
    expect(db.flows.single.fromUid, 'other');
    await Get.deleteAll(force: true);
  });
}
