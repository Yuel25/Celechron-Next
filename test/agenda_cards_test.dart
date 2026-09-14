import 'dart:io';
import 'dart:ui' as ui;

import 'package:celechron/widget/agenda_cards.dart';
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
        final courseProgFinder = find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == '当前事项进度');
        expect(courseProgFinder, findsOneWidget);
        expect(
            tester.widget<Semantics>(courseProgFinder).properties.value, '44%');
        final taskProgFinder = find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == '任务完成进度');
        expect(taskProgFinder, findsOneWidget);
        expect(tester.widget<Semantics>(taskProgFinder).properties.value, '0%');
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

  testWidgets('task page completion saves status', (tester) async {
    final date = DateTime.now();
    final db = MemoryDatabase();
    final task = sampleTask(date);
    final other = sampleTask(date)..uid = 'other';
    final tasks = [task, other].obs;
    final flows = <Period>[].obs;
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
    await tester.tap(find.byType(CupertinoButton).first);
    await tester.pump();
    expect(task.status, TaskStatus.completed);
    expect(db.tasks.firstWhere((item) => item.uid == task.uid).status,
        TaskStatus.completed);
    await Get.deleteAll(force: true);
  });

  testWidgets(
      'AgendaPeriodCard featured active card renders progress bar with exact percentage',
      (tester) async {
    final base = DateTime(2030, 9, 5, 10, 0, 0);
    final coursePeriod = Period(
      summary: '高等数学',
      location: '东一 101',
      startTime: base.subtract(const Duration(minutes: 30)),
      endTime: base.add(const Duration(minutes: 30)),
    );

    await tester.pumpWidget(CupertinoApp(
      home: CupertinoPageScaffold(
        child: AgendaPeriodCard(
          period: coursePeriod,
          now: base,
          color: CupertinoColors.activeBlue,
          featured: true,
        ),
      ),
    ));

    final progFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == '当前事项进度');
    expect(progFinder, findsOneWidget);
    expect(tester.widget<Semantics>(progFinder).properties.value, '50%');
  });

  testWidgets('TaskCardContent progress bar increases as focus time accrues',
      (tester) async {
    final start = DateTime(2030, 9, 5, 10, 0, 0);
    final deadlineTask = sampleTask(start, spent: Duration.zero)
      ..timeNeeded = const Duration(minutes: 60)
      ..focusedSince = start;

    Widget buildCard(DateTime current) {
      return CupertinoApp(
        home: CupertinoPageScaffold(
          child: TaskCardContent(
            task: deadlineTask,
            now: current,
            color: CupertinoColors.activeBlue,
            onToggle: () {},
            isFocusing: true,
          ),
        ),
      );
    }

    final taskProgFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == '任务完成进度');

    // At start + 15m (15m / 60m = 25%)
    await tester.pumpWidget(buildCard(start.add(const Duration(minutes: 15))));
    expect(taskProgFinder, findsOneWidget);
    expect(tester.widget<Semantics>(taskProgFinder).properties.value, '25%');

    // At start + 45m (45m / 60m = 75%)
    await tester.pumpWidget(buildCard(start.add(const Duration(minutes: 45))));
    expect(tester.widget<Semantics>(taskProgFinder).properties.value, '75%');

    // At start + 60m (60m / 60m = 100%)
    await tester.pumpWidget(buildCard(start.add(const Duration(minutes: 60))));
    expect(tester.widget<Semantics>(taskProgFinder).properties.value, '100%');
  });

  group('AgendaPeriodCard 方案 A featured 卡片视觉样式', () {
    final baseTime = DateTime(2030, 9, 5, 14, 0);

    test('FeaturedCardStyle.from 针对 systemYellow 计算出的颜色值符合方案 A 规格', () {
      // 亮色模式
      final lightStyle = FeaturedCardStyle.from(
        color: CupertinoColors.systemYellow.color,
        brightness: Brightness.light,
      );
      expect(
        lightStyle.backgroundColor,
        Color.alphaBlend(
          CupertinoColors.systemYellow.color.withValues(alpha: 0.10),
          CupertinoColors.white,
        ),
      );
      expect(lightStyle.backgroundColor.toARGB32(), 0xFFFFFAE6);
      expect(lightStyle.borderColor, const Color(0xFFAD8B00));
      expect(lightStyle.borderWidth, 1.5);
      expect(lightStyle.accentColor, const Color(0xFFAD8B00));

      // 暗色模式
      final darkStyle = FeaturedCardStyle.from(
        color: CupertinoColors.systemYellow.darkColor,
        brightness: Brightness.dark,
        darkBaseColor: CupertinoColors.black,
      );
      expect(
        darkStyle.backgroundColor,
        Color.alphaBlend(
          CupertinoColors.systemYellow.darkColor.withValues(alpha: 0.16),
          CupertinoColors.black,
        ),
      );
      expect(darkStyle.backgroundColor.toARGB32(), 0xFF292202);
      expect(darkStyle.borderColor,
          CupertinoColors.systemYellow.darkColor.withValues(alpha: 0.6));
      expect(darkStyle.borderWidth, 1.0);
      expect(darkStyle.accentColor, CupertinoColors.systemYellow.darkColor);
    });
    final period = Period(
      summary: '计算机系统结构',
      location: '紫金港 · 西一 407',
      startTime: baseTime.subtract(const Duration(minutes: 20)),
      endTime: baseTime.add(const Duration(minutes: 40)),
    );

    testWidgets('featured 卡片亮色模式：背景 10% 白底混合、边框与强调文字为深色变体', (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          theme: const CupertinoThemeData(brightness: Brightness.light),
          home: CupertinoPageScaffold(
            child: AgendaPeriodCard(
              period: period,
              now: baseTime,
              color: CupertinoColors.systemYellow,
              featured: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final expectedResolved = CupertinoColors.systemYellow.color;
      final expectedBg = Color.alphaBlend(
        expectedResolved.withValues(alpha: 0.10),
        CupertinoColors.white,
      );
      final expectedDarkVariant = readableBarColor(
        expectedResolved,
        Brightness.light,
      );

      final cardContainer = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(RoundRectangleCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = cardContainer.decoration as BoxDecoration;

      // 验证背景为 color 10% 白底混合
      expect(decoration.color, expectedBg);

      // 验证边框为深色变体，1.5px
      expect(decoration.border, isNotNull);
      final border = decoration.border as Border;
      expect(border.top.color, expectedDarkVariant);
      expect(border.top.width, 1.5);

      // 验证强调文字为深色变体
      final tagText = tester.widget<Text>(find.text('进行中 · 课程'));
      expect(tagText.style?.color, expectedDarkVariant);

      final countdownText = tester.widget<Text>(find.text('还剩 40 分钟'));
      expect(countdownText.style?.color, expectedDarkVariant);
    });

    testWidgets('featured 卡片暗色模式：背景 16% 暗底混合、边框 60% 透明度原色、强调文字为原色',
        (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          theme: const CupertinoThemeData(brightness: Brightness.dark),
          home: CupertinoPageScaffold(
            child: AgendaPeriodCard(
              period: period,
              now: baseTime,
              color: CupertinoColors.systemYellow,
              featured: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final expectedResolved = CupertinoColors.systemYellow.darkColor;
      final expectedDarkBase = CupertinoColors.systemBackground.darkColor;
      final expectedBg = Color.alphaBlend(
        expectedResolved.withValues(alpha: 0.16),
        expectedDarkBase,
      );
      final expectedBorderColor = expectedResolved.withValues(alpha: 0.6);

      final cardContainer = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(RoundRectangleCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = cardContainer.decoration as BoxDecoration;

      // 验证背景为 16% 暗底混合
      expect(decoration.color, expectedBg);

      // 验证边框为 60% 透明度原色，1.0px
      expect(decoration.border, isNotNull);
      final border = decoration.border as Border;
      expect(border.top.color, expectedBorderColor);
      expect(border.top.width, 1.0);

      // 验证强调文字为原色
      final tagText = tester.widget<Text>(find.text('进行中 · 课程'));
      expect(tagText.style?.color?.toARGB32(), expectedResolved.toARGB32());

      final countdownText = tester.widget<Text>(find.text('还剩 40 分钟'));
      expect(
          countdownText.style?.color?.toARGB32(), expectedResolved.toARGB32());
    });

    testWidgets('非 featured 卡片不受影响：亮色与暗色下均保持原背景无边框且标签文字为原色', (tester) async {
      // 亮色模式测试
      await tester.pumpWidget(
        CupertinoApp(
          theme: const CupertinoThemeData(brightness: Brightness.light),
          home: CupertinoPageScaffold(
            child: AgendaPeriodCard(
              period: period,
              now: baseTime,
              color: CupertinoColors.systemYellow,
              featured: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      var cardContainer = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(RoundRectangleCard),
              matching: find.byType(Container),
            )
            .first,
      );
      var decoration = cardContainer.decoration as BoxDecoration;

      expect(decoration.color, CupertinoColors.white);
      expect(decoration.border, isNull);
      var tagText = tester.widget<Text>(find.text('进行中 · 课程'));
      expect(tagText.style?.color, CupertinoColors.systemYellow);
      expect(find.text('还剩 40 分钟'), findsNothing);

      // 暗色模式测试
      await tester.pumpWidget(
        CupertinoApp(
          theme: const CupertinoThemeData(brightness: Brightness.dark),
          home: CupertinoPageScaffold(
            child: AgendaPeriodCard(
              period: period,
              now: baseTime,
              color: CupertinoColors.systemYellow,
              featured: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      cardContainer = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(RoundRectangleCard),
              matching: find.byType(Container),
            )
            .first,
      );
      decoration = cardContainer.decoration as BoxDecoration;

      expect(decoration.color?.toARGB32(),
          CupertinoColors.secondarySystemBackground.darkColor.toARGB32());
      expect(decoration.border, isNull);
      tagText = tester.widget<Text>(find.text('进行中 · 课程'));
      expect(tagText.style?.color, CupertinoColors.systemYellow);
      expect(find.text('还剩 40 分钟'), findsNothing);
    });
  });
}
