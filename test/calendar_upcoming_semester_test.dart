import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/semester.dart';
import 'package:celechron/model/session.dart';
import 'package:celechron/model/task.dart';
import 'package:celechron/page/calendar/calendar_controller.dart';
import 'package:celechron/page/calendar/schedule_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class FakeSemester extends Semester {
  final DateTime? _mockFirstDay;
  final DateTime? _mockLastDay;

  FakeSemester(
    super.name, {
    DateTime? firstDay,
    DateTime? lastDay,
  })  : _mockFirstDay = firstDay,
        _mockLastDay = lastDay;

  @override
  DateTime get firstDay => _mockFirstDay ?? super.firstDay;

  @override
  DateTime get lastDay => _mockLastDay ?? super.lastDay;
}

void main() {
  late Rx<Scholar> rxScholar;
  late RxList<Task> rxTaskList;
  late CalendarController controller;

  setUp(() {
    Get.reset();
    rxScholar = Rx<Scholar>(Scholar());
    rxTaskList = <Task>[].obs;
    Get.put<Rx<Scholar>>(rxScholar, tag: 'scholar');
    Get.put<RxList<Task>>(rxTaskList, tag: 'taskList');
    controller = CalendarController();
  });

  tearDown(() {
    Get.reset();
  });

  group('CalendarController semester detection unit tests', () {
    final semAutumn = FakeSemester(
      '2024-2025秋冬',
      firstDay: DateTime(2024, 9, 9),
      lastDay: DateTime(2025, 1, 15),
    );
    final semSpring = FakeSemester(
      '2024-2025春夏',
      firstDay: DateTime(2025, 2, 24),
      lastDay: DateTime(2025, 7, 5),
    );

    test('场景 1：当前学期内 (in current semester)', () {
      rxScholar.value.semesters = [semAutumn, semSpring];
      // 2024年10月15日 在秋冬学期内
      final now = DateTime(2024, 10, 15, 10, 0);

      final current = controller.getCurrentSemester(now);
      final upcoming = controller.getUpcomingSemester(now);
      final displayed = controller.getDisplayedSemester(now);

      expect(current?.name, '2024-2025秋冬');
      expect(upcoming?.name, '2024-2025春夏');
      expect(displayed?.name, '2024-2025秋冬');
      expect(controller.getCurrentSemesterDisplayName(now), '24-25秋冬 秋学期');
    });

    test('场景 1b：学期最后一天白天仍属本学期（抹平到日期维度）', () {
      rxScholar.value.semesters = [semAutumn, semSpring];
      // semAutumn 的 lastDay 为 2025-01-15（校历午夜 00:00:00）
      // 当天白天 14:30 仍在秋冬学期内，不应提前切换到下学期或展示未开学横幅
      final lastDayAfternoon = DateTime(2025, 1, 15, 14, 30);

      final current = controller.getCurrentSemester(lastDayAfternoon);
      final upcoming = controller.getUpcomingSemester(lastDayAfternoon);
      final displayed = controller.getDisplayedSemester(lastDayAfternoon);

      expect(current?.name, '2024-2025秋冬');
      expect(upcoming?.name, '2024-2025春夏');
      expect(displayed?.name, '2024-2025秋冬');
      expect(
        controller.getCurrentSemesterDisplayName(lastDayAfternoon),
        isNot(contains('未开学')),
      );
    });

    test('场景 2：假期中 (during vacation between semesters)', () {
      rxScholar.value.semesters = [semAutumn, semSpring];
      // 2025年2月1日 寒假中（秋冬学期已结束，春夏学期尚未开始）
      final now = DateTime(2025, 2, 1, 10, 0);

      final current = controller.getCurrentSemester(now);
      final upcoming = controller.getUpcomingSemester(now);
      final displayed = controller.getDisplayedSemester(now);

      expect(current, isNull);
      expect(upcoming?.name, '2024-2025春夏');
      expect(displayed?.name, '2024-2025春夏');
      expect(
          controller.getCurrentSemesterDisplayName(now), '未开学 · 24-25春夏 春学期');
    });

    test('场景 3：开学前 (before start of upcoming semester)', () {
      rxScholar.value.semesters = [semAutumn, semSpring];
      // 2024年9月1日 开学前几天尚未进入新学期
      final now = DateTime(2024, 9, 1, 10, 0);

      final current = controller.getCurrentSemester(now);
      final upcoming = controller.getUpcomingSemester(now);
      final displayed = controller.getDisplayedSemester(now);

      expect(current, isNull);
      expect(upcoming?.name, '2024-2025秋冬');
      expect(displayed?.name, '2024-2025秋冬');
      expect(
          controller.getCurrentSemesterDisplayName(now), '未开学 · 24-25秋冬 秋学期');
    });

    test('场景 4：无任何学期数据 (no semester data at all)', () {
      rxScholar.value.semesters = [];
      final now = DateTime(2024, 9, 1, 10, 0);

      expect(controller.getCurrentSemester(now), isNull);
      expect(controller.getUpcomingSemester(now), isNull);
      expect(controller.getDisplayedSemester(now), isNull);
      expect(controller.getCurrentSemesterDisplayName(now), '无学期信息');
    });

    test('所有学期均在过去时返回 null 与无学期信息', () {
      rxScholar.value.semesters = [semAutumn, semSpring];
      // 2026年9月，所有学期均已过去
      final now = DateTime(2026, 9, 1);

      expect(controller.getCurrentSemester(now), isNull);
      expect(controller.getUpcomingSemester(now), isNull);
      expect(controller.getDisplayedSemester(now), isNull);
      expect(controller.getCurrentSemesterDisplayName(now), '无学期信息');
    });

    test('多个未来学期按 firstDay 升序取最近一个', () {
      final sem1 = FakeSemester(
        '2025-2026春夏',
        firstDay: DateTime(2026, 2, 23),
        lastDay: DateTime(2026, 7, 5),
      );
      final sem2 = FakeSemester(
        '2025-2026秋冬',
        firstDay: DateTime(2025, 9, 8),
        lastDay: DateTime(2026, 1, 20),
      );
      // 乱序放入
      rxScholar.value.semesters = [sem1, sem2];
      final now = DateTime(2025, 8, 20);

      final upcoming = controller.getUpcomingSemester(now);
      expect(upcoming?.name, '2025-2026秋冬');
      expect(controller.getDisplayedSemester(now)?.name, '2025-2026秋冬');
    });
  });

  group('ScheduleView widget tests', () {
    testWidgets('未开学状态下展示提示横幅与新学期课表', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 设置未来学期（firstDay 在未来），并注入真实排课数据
      final upcomingSem = FakeSemester(
        '2026-2027秋冬',
        firstDay: DateTime.now().add(const Duration(days: 5)),
        lastDay: DateTime.now().add(const Duration(days: 120)),
      );
      final session = Session.empty()
        ..name = '编译原理'
        ..teacher = '张老师'
        ..dayOfWeek = 1
        ..time = [1, 2]
        ..firstHalf = true
        ..secondHalf = true
        ..confirmed = true;
      upcomingSem.addSession(session, '2026-2027-1');

      rxScholar.value.semesters = [upcomingSem];
      rxScholar.refresh();

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: ScheduleView(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 横幅应显示
      expect(find.byKey(const Key('upcoming_semester_banner')), findsOneWidget);
      final expectedDateStr =
          '${upcomingSem.firstDay.month}月${upcomingSem.firstDay.day}日';
      expect(
        find.text('未开学 · 新学期 $expectedDateStr开始，下面是它的课表'),
        findsOneWidget,
      );
      // 不应显示“当前不在学期内”，且应渲染出真实课程卡片
      expect(find.text('当前不在学期内'), findsNothing);
      expect(find.text('编译原理'), findsOneWidget);
    });

    testWidgets('当前学期内不展示未开学横幅', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 设置当前学期（now 在 firstDay 和 lastDay 之间）
      final activeSem = FakeSemester(
        '2026-2027秋冬',
        firstDay: DateTime.now().subtract(const Duration(days: 10)),
        lastDay: DateTime.now().add(const Duration(days: 100)),
      );
      rxScholar.value.semesters = [activeSem];
      rxScholar.refresh();

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: ScheduleView(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 横幅不应出现
      expect(find.byKey(const Key('upcoming_semester_banner')), findsNothing);
      expect(find.text('当前不在学期内'), findsNothing);
    });

    testWidgets('无学期数据时显示当前不在学期内且无横幅', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      rxScholar.value.semesters = [];
      rxScholar.refresh();

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: ScheduleView(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('upcoming_semester_banner')), findsNothing);
      expect(find.text('当前不在学期内'), findsOneWidget);
    });

    testWidgets('暗色模式下未开学横幅正常渲染', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final upcomingSem = FakeSemester(
        '2026-2027秋冬',
        firstDay: DateTime.now().add(const Duration(days: 3)),
        lastDay: DateTime.now().add(const Duration(days: 120)),
      );
      rxScholar.value.semesters = [upcomingSem];
      rxScholar.refresh();

      await tester.pumpWidget(
        CupertinoApp(
          theme: const CupertinoThemeData(brightness: Brightness.dark),
          home: CupertinoPageScaffold(
            child: ScheduleView(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('upcoming_semester_banner')), findsOneWidget);
      final expectedDateStr =
          '${upcomingSem.firstDay.month}月${upcomingSem.firstDay.day}日';
      expect(
        find.text('未开学 · 新学期 $expectedDateStr开始，下面是它的课表'),
        findsOneWidget,
      );

      // 断言暗色模式下横幅背景使用 brandSoft 暗色值 (0xFF252A48)
      final bannerContainer = tester.widget<Container>(
        find.byKey(const Key('upcoming_semester_banner')),
      );
      final decoration = bannerContainer.decoration as BoxDecoration;
      expect(decoration.color?.toARGB32(), const Color(0xFF252A48).toARGB32());
    });
  });
}
