// Official packages
import 'package:celechron/page/scholar/todo/todo_card.dart';
import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:extended_sliver/extended_sliver.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:get/get.dart';

// Custom widgets and colors
import 'package:celechron/design/multiple_columns.dart';
import 'package:celechron/design/two_line_card.dart';
import 'package:celechron/design/round_rectangle_card.dart';
import 'package:celechron/design/refresh_status_indicator.dart';
import 'package:celechron/design/app_empty_state.dart';
import 'package:celechron/design/app_visual.dart';

import 'package:celechron/page/search/search_view.dart';
import 'course_list/course_list_view.dart';
import 'course_schedule/course_schedule_view.dart';
import 'exam_list/exam_list_view.dart';
import 'grade_detail/grade_detail_view.dart';
import 'practice_score/practice_score_page.dart';
import 'scholar_controller.dart';
import 'package:celechron/design/data_updated_label.dart';
import 'package:celechron/page/option/option_controller.dart';

Future<void> showRefreshResultDialog(
    BuildContext context, List<String?> results) async {
  final messages = results.whereType<String>().toList();
  // 完全成功只通过数据、更新时间和页面状态反馈，不主动打断用户。
  if (messages.isEmpty) return;
  final degraded =
      messages.where(isDegradedRefreshText).toList(growable: false);
  final failures = messages
      .where((message) => !isDegradedRefreshText(message))
      .toList(growable: false);
  if (!context.mounted) return;
  final summaryLines = messages.map((error) {
    final compact =
        shortErrorText(error).replaceAll(RegExp(r'\s+'), ' ').trim();
    final prefix = isDegradedRefreshText(error) ? '降级：' : '失败：';
    final line = '$prefix$compact';
    return line.length <= 100 ? line : '${line.substring(0, 100)}…';
  }).toList();

  await showCupertinoDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(
        '刷新遇到问题：${degraded.length} 项降级，${failures.length} 项失败',
      ),
      content: Text(summaryLines.join('\n')),
      actions: [
        if (messages.isNotEmpty)
          CupertinoDialogAction(
            child: const Text('查看详情'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              showCupertinoDialog<void>(
                context: context,
                builder: (detailContext) => CupertinoAlertDialog(
                  title: const Text('刷新详情'),
                  content: SingleChildScrollView(
                    child: Text(
                      messages.map((error) {
                        final short = shortErrorText(error);
                        final details = detailedErrorText(error);
                        return details == short ? short : '$short\n$details';
                      }).join('\n\n'),
                    ),
                  ),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text('确定'),
                      onPressed: () => Navigator.of(detailContext).pop(),
                    ),
                  ],
                ),
              );
            },
          ),
        CupertinoDialogAction(
          child: const Text('确定'),
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    ),
  );
}

class ScholarErrorHandler extends StatelessWidget {
  final FlutterErrorDetails errorDetails;
  final _scholarController = Get.put(ScholarController());

  ScholarErrorHandler({
    super.key,
    required this.errorDetails,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildListDelegate([
        CupertinoListSection.insetGrouped(
          header: Container(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: Text(
              '获取数据时遇到问题。请检查网络连接情况，并尝试重新获取数据。\n注意：你需要完成所有的教学评价才能获取成绩信息。',
              style: TextStyle(
                  color: CupertinoDynamicColor.resolve(
                      CupertinoColors.secondaryLabel, context),
                  fontSize: 14),
            ),
          ),
          children: [
            CupertinoButton(
              onPressed: () async {
                final results = await _scholarController.fetchData();
                if (context.mounted &&
                    results.any((result) => result != null)) {
                  await showRefreshResultDialog(context, results);
                }
              },
              child: const Text('重新获取数据'),
            ),
          ],
        ),
      ]),
    );
  }
}

class ScholarPage extends StatelessWidget {
  ScholarPage({super.key}) {
    ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
      return ScholarErrorHandler(errorDetails: errorDetails);
    };
  }

  final _scholarController = Get.put(ScholarController());

  // 让页内横向列表在桌面端也响应鼠标拖动。外层 PageView 为支持鼠标切页开启了
  // 鼠标拖动，横向列表若不响应鼠标，拖动会漏到 PageView 上造成误切页；
  // 内层可滚动组件在手势竞技中优先，包上后拖动由列表自己消费（触屏行为不变）
  Widget _mouseDraggable(BuildContext context, Widget child) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
        dragDevices: {
          ...ScrollConfiguration.of(context).dragDevices,
          PointerDeviceKind.mouse,
        },
      ),
      child: child,
    );
  }

  Widget _buildGradeBrief(BuildContext context) {
    final optionController =
        Get.find<OptionController>(tag: 'optionController');

    String maskGPA(String s) {
      // 绩点隐藏功能
      if (!optionController.hideHomeGpa) return s;
      return s.replaceAll('.', '').replaceAll(RegExp(r'[\d.]'), '*');
    }

    return RoundRectangleCard(
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: Hero(
                        tag: 'gradeBrief',
                        child: RoundRectangleCardWithForehead(
                            foreheadColor: AppVisual.moduleGrade,
                            forehead: Obx(() => Row(children: [
                                  // University Icon
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 12, top: 6, bottom: 6),
                                    child: Icon(
                                      CupertinoIcons.chart_bar_alt_fill,
                                      color: CupertinoDynamicColor.resolve(
                                          CupertinoColors.label, context),
                                      size: 18,
                                    ),
                                  ),
                                  Padding(
                                      padding: const EdgeInsets.only(
                                          left: 6, top: 6, bottom: 6),
                                      child: Text('成绩',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            overflow: TextOverflow.ellipsis,
                                            color:
                                                CupertinoDynamicColor.resolve(
                                                    CupertinoColors.label,
                                                    context),
                                          ))),
                                  const Spacer(),
                                  // 缓存时间使用中性文案，异常由刷新结果提示。
                                  Flexible(
                                      child: DataUpdatedLabel(
                                          age: _scholarController
                                              .durationToLastUpdateGrade)),
                                ])),
                            onTap: () async =>
                                Navigator.of(context, rootNavigator: true).push(
                                    CupertinoPageRoute(
                                        builder: (context) => GradeDetailPage(),
                                        fullscreenDialog: true)),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Obx(() => TwoLineCard(
                                          title: '五分制',
                                          content: maskGPA(_scholarController
                                              .gpa[0]
                                              .toStringAsFixed(2)),
                                          backgroundColor:
                                              AppVisual.metricBlue)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Obx(() => TwoLineCard(
                                          title: '获得学分',
                                          content: maskGPA(_scholarController
                                              .scholar.credit
                                              .toStringAsFixed(1)),
                                          backgroundColor:
                                              AppVisual.metricPeach)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Obx(() => TwoLineCard(
                                          title: '四分制',
                                          content: maskGPA(_scholarController
                                              .gpa[1]
                                              .toStringAsFixed(2)),
                                          extraContent: maskGPA(
                                              _scholarController.gpa[2]
                                                  .toStringAsFixed(2)),
                                          backgroundColor:
                                              AppVisual.metricGreen)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Obx(() => TwoLineCard(
                                          title: '百分制',
                                          content: maskGPA(_scholarController
                                              .gpa[3]
                                              .toStringAsFixed(2)),
                                          backgroundColor:
                                              AppVisual.metricViolet)),
                                    ),
                                  ],
                                ),
                              ],
                            )))),
              ],
            ),
          ],
        ));
  }

  Widget _buildSemester(BuildContext context) {
    return RoundRectangleCard(
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: RoundRectangleCardWithForehead(
                        animate: false,
                        foreheadColor: AppVisual.moduleCourse,
                        forehead: Obx(() => Row(children: [
                              // University Icon
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 12, top: 6, bottom: 6),
                                child: Icon(
                                  CupertinoIcons.calendar,
                                  color: CupertinoDynamicColor.resolve(
                                      CupertinoColors.label, context),
                                  size: 18,
                                ),
                              ),
                              Padding(
                                  padding: const EdgeInsets.only(
                                      left: 6, top: 6, bottom: 6),
                                  child: Text('课程',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        overflow: TextOverflow.ellipsis,
                                        color: CupertinoDynamicColor.resolve(
                                            CupertinoColors.label, context),
                                      ))),
                              const Spacer(),
                              // 缓存时间使用中性文案，异常由刷新结果提示。
                              Flexible(
                                  child: DataUpdatedLabel(
                                      age: _scholarController
                                          .durationToLastUpdateCourse)),
                            ])),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            MultipleColumns(
                              contents: [
                                Text(
                                    _scholarController
                                        .selectedSemester.courses.length
                                        .toString(),
                                    style: CupertinoTheme.of(context)
                                        .textTheme
                                        .navTitleTextStyle
                                        .copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                Text(
                                    _scholarController
                                        .selectedSemester.courseCredit
                                        .toString(),
                                    style: CupertinoTheme.of(context)
                                        .textTheme
                                        .navTitleTextStyle
                                        .copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                Text(
                                    _scholarController
                                        .selectedSemester.examCount
                                        .toString(),
                                    style: CupertinoTheme.of(context)
                                        .textTheme
                                        .navTitleTextStyle
                                        .copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                              ],
                              titles: const ['课程', '学分', '考试'],
                              onTaps: [
                                () => Navigator.of(context, rootNavigator: true)
                                    .push(CupertinoPageRoute(
                                        builder: (context) => CourseListPage(
                                            initialSemesterName:
                                                _scholarController
                                                    .selectedSemester.name),
                                        title: '课程')),
                                null,
                                () => Navigator.of(context, rootNavigator: true)
                                    .push(CupertinoPageRoute(
                                        builder: (context) => ExamListPage(
                                            initialSemesterName:
                                                _scholarController
                                                    .selectedSemester.name),
                                        title: '考试'))
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TwoLineCard(
                                      animate: true,
                                      // With CupertinoPageTransition
                                      onTap: () => Navigator.of(context,
                                                  rootNavigator: true)
                                              .push(
                                            CupertinoPageRoute(
                                              builder: (context) =>
                                                  CourseSchedulePage(
                                                      _scholarController
                                                          .selectedSemester
                                                          .name,
                                                      true),
                                              title: '课表',
                                            ),
                                          ),
                                      title:
                                          '${_scholarController.selectedSemester.firstHalfName}学期课时',
                                      content:
                                          '${_scholarController.selectedSemester.firstHalfSessionCount}节/两周',
                                      backgroundColor: AppVisual.seasonAutumn),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TwoLineCard(
                                      animate: true,
                                      onTap: () => Navigator.of(context,
                                                  rootNavigator: true)
                                              .push(
                                            CupertinoPageRoute(
                                              builder: (context) =>
                                                  CourseSchedulePage(
                                                      _scholarController
                                                          .selectedSemester
                                                          .name,
                                                      false),
                                              title: '课表',
                                            ),
                                          ),
                                      title:
                                          '${_scholarController.selectedSemester.secondHalfName}学期课时',
                                      content:
                                          '${_scholarController.selectedSemester.secondHalfSessionCount}节/两周',
                                      backgroundColor: AppVisual.seasonWinter),
                                ),
                              ],
                            ),
                          ],
                        ))),
              ],
            ),
          ],
        ));
  }

  Widget _buildTodos(BuildContext context) {
    return RoundRectangleCard(
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: RoundRectangleCardWithForehead(
                        animate: false,
                        foreheadColor: AppVisual.moduleHomework,
                        forehead: Obx(() => Row(children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 12, top: 6, bottom: 6),
                                child: Icon(
                                  CupertinoIcons.checkmark_square_fill,
                                  color: CupertinoDynamicColor.resolve(
                                      CupertinoColors.label, context),
                                  size: 18,
                                ),
                              ),
                              Padding(
                                  padding: const EdgeInsets.only(
                                      left: 6, top: 6, bottom: 6),
                                  child: Text('作业',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        overflow: TextOverflow.ellipsis,
                                        color: CupertinoDynamicColor.resolve(
                                            CupertinoColors.label, context),
                                      ))),
                              const Spacer(),
                              Flexible(
                                  child: DataUpdatedLabel(
                                      age: _scholarController
                                          .durationToLastUpdateHomework)),
                            ])),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            MultipleColumns(
                              contents: [
                                Text(_scholarController.todos.length.toString(),
                                    style: CupertinoTheme.of(context)
                                        .textTheme
                                        .navTitleTextStyle
                                        .copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                Text(
                                    _scholarController.todosInOneDay.length
                                        .toString(),
                                    style: CupertinoTheme.of(context)
                                        .textTheme
                                        .navTitleTextStyle
                                        .copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                Text(
                                    _scholarController.todosInOneWeek.length
                                        .toString(),
                                    style: CupertinoTheme.of(context)
                                        .textTheme
                                        .navTitleTextStyle
                                        .copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                              ],
                              titles: const ["总计", "一天内", "本周截止"],
                              onTaps: [() {}, () {}, () {}],
                            ),
                            const SizedBox(height: 16),
                            if (_scholarController.todos.isNotEmpty)
                              SizedBox(
                                  height: 102,
                                  child: _mouseDraggable(
                                      context,
                                      ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          itemCount:
                                              _scholarController.todos.length,
                                          separatorBuilder: (context, index) =>
                                              const SizedBox(width: 8),
                                          itemBuilder: (context, index) {
                                            final todo =
                                                _scholarController.todos[index];
                                            return SizedBox(
                                                width: 200,
                                                child: TodoCard(todo: todo));
                                          })))
                          ],
                        ))),
              ],
            ),
          ],
        ));
  }

  Widget _buildPractice(BuildContext context) {
    return RoundRectangleCard(
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: RoundRectangleCardWithForehead(
                        animate: false,
                        foreheadColor: AppVisual.modulePractice,
                        forehead: Obx(() => Row(children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 12, top: 6, bottom: 6),
                                child: Icon(
                                  CupertinoIcons.star_fill,
                                  color: CupertinoDynamicColor.resolve(
                                      CupertinoColors.label, context),
                                  size: 18,
                                ),
                              ),
                              Padding(
                                  padding: const EdgeInsets.only(
                                      left: 6, top: 6, bottom: 6),
                                  child: Text('实践',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        overflow: TextOverflow.ellipsis,
                                        color: CupertinoDynamicColor.resolve(
                                            CupertinoColors.label, context),
                                      ))),
                              const Spacer(),
                              if (!_scholarController
                                  .scholar.isPracticeScoresGet)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 4, bottom: 4),
                                  child: Icon(
                                    CupertinoIcons.exclamationmark_circle_fill,
                                    color: CupertinoDynamicColor.resolve(
                                        CupertinoColors.systemOrange, context),
                                    size: 13,
                                  ),
                                ),
                              if (!_scholarController
                                  .scholar.isPracticeScoresGet)
                                Flexible(
                                  child: Padding(
                                      padding: const EdgeInsets.only(
                                          left: 4,
                                          top: 4,
                                          bottom: 4,
                                          right: 16),
                                      child: Text('获取实践记点时遇到问题',
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.normal,
                                            overflow: TextOverflow.ellipsis,
                                            color:
                                                CupertinoDynamicColor.resolve(
                                                    CupertinoColors
                                                        .systemOrange,
                                                    context),
                                          ))),
                                ),
                            ])),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            Obx(
                              () => PracticeScoreColumns(
                                scholar: _scholarController.scholar,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ))),
              ],
            ),
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        /*backgroundColor: CupertinoDynamicColor.resolve(
            CupertinoColors.systemGroupedBackground, context),*/
        child: CustomScrollView(
          slivers: [
            SliverPinnedToBoxAdapter(
                child: Container(
              decoration: BoxDecoration(
                color: CupertinoDynamicColor.resolve(
                    CupertinoColors.systemGroupedBackground, context),
                border: Border(
                  bottom: BorderSide(
                    color: CupertinoDynamicColor.resolve(
                      CupertinoColors.separator.withValues(alpha: 0.28),
                      context,
                    ),
                  ),
                ),
                /*boxShadow: [
              BoxShadow(
                color: CupertinoDynamicColor.resolve(
                    CupertinoColors.systemGrey5, context),
                offset: const Offset(0, 0),
                blurRadius: 4,
              ),
            ],
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16)),*/
              ),
              child: Padding(
                  padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 4,
                      top: 8 + MediaQuery.of(context).padding.top),
                  child: Column(children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '学业',
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .navLargeTitleTextStyle
                                .copyWith(fontSize: 32),
                          ),
                        ),
                        CupertinoButton(
                          sizeStyle: CupertinoButtonSize.small,
                          padding: const EdgeInsets.all(8),
                          color: CupertinoDynamicColor.resolve(
                            AppVisual.brandSoft,
                            context,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).push(
                              CupertinoPageRoute(
                                builder: (context) => SearchPage(),
                              ),
                            );
                          },
                          child: const Icon(
                            CupertinoIcons.search,
                            size: 19,
                            color: AppVisual.brand,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: MediaQuery.textScalerOf(context).scale(14) + 22,
                      child: _mouseDraggable(
                        context,
                        Obx(
                          () {
                            final selectedIndex =
                                _scholarController.semesterIndex.value;
                            return ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _scholarController.semesters.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final semester =
                                    _scholarController.semesters[index];
                                final selected = selectedIndex == index;
                                return GestureDetector(
                                  onTap: () => _scholarController
                                      .semesterIndex.value = index,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? AppVisual.brand
                                          : CupertinoDynamicColor.resolve(
                                              CupertinoColors
                                                  .secondarySystemGroupedBackground,
                                              context,
                                            ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: selected
                                            ? AppVisual.brand
                                            : CupertinoDynamicColor.resolve(
                                                CupertinoColors.separator
                                                    .withValues(alpha: 0.35),
                                                context,
                                              ),
                                      ),
                                    ),
                                    child: Text(
                                      '${semester.name.substring(2, 5)}${semester.name.substring(7, 11)}',
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: selected
                                            ? CupertinoColors.white
                                            : CupertinoColors.label,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ])),
            )),
            if (_scholarController.scholar.isLogan)
              CupertinoSliverRefreshControl(
                // 复刻原生转圈，刷新超过 5 秒后在其右侧滚动展示状态文案。
                // Obx 是必需的：刷新驻留期间 sliver 高度不变、builder 不会被重调，
                // 文案更新只能靠响应式重建
                builder: (context, refreshState, pulledExtent,
                        refreshTriggerPullDistance, refreshIndicatorExtent) =>
                    Obx(() => RefreshStatusIndicator(
                          refreshState: refreshState,
                          pulledExtent: pulledExtent,
                          refreshTriggerPullDistance:
                              refreshTriggerPullDistance,
                          refreshIndicatorExtent: refreshIndicatorExtent,
                          message:
                              _scholarController.refreshStatusMessage.value,
                        )),
                onRefresh: () async {
                  final results = await _scholarController.fetchData();
                  if (context.mounted &&
                      results.any((result) => result != null)) {
                    await showRefreshResultDialog(context, results);
                  }
                },
              ),
            SliverToBoxAdapter(
              child: Obx(() {
                if (_scholarController.scholar.semesters.isNotEmpty) {
                  return Padding(
                    padding: EdgeInsets.only(
                        top: 8,
                        right: 16,
                        left: 16,
                        bottom: MediaQuery.of(context).padding.bottom + 4),
                    child: Column(
                      children: _scholarController.scholar.isGrs
                          ? [
                              const SizedBox(height: 12),
                              _buildSemester(context),
                              const SizedBox(height: 20),
                              _buildTodos(context),
                            ]
                          : [
                              _buildGradeBrief(context),
                              const SizedBox(height: 20),
                              _buildSemester(context),
                              const SizedBox(height: 20),
                              _buildTodos(context),
                              const SizedBox(height: 20),
                              _buildPractice(context),
                              const SizedBox(height: 20),
                            ],
                    ),
                  );
                } else {
                  return AppEmptyState(
                    icon: _scholarController.scholar.isLogan
                        ? CupertinoIcons.arrow_clockwise
                        : CupertinoIcons.person_crop_circle,
                    title: _scholarController.scholar.isLogan ? '等待同步' : '尚未登录',
                    message: _scholarController.scholar.isLogan
                        ? '下拉刷新以获取学业数据；同步失败时会自动使用离线缓存。'
                        : '登录后即可查看课程、成绩、考试和实践分。',
                    minHeight: 460,
                  );
                }
              }),
            ),
          ],
        ));
  }
}

class AlwaysDisabledFocusNode extends FocusNode {
  @override
  bool get hasFocus => false;
}
