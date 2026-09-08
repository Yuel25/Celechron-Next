import 'dart:async';
import 'package:celechron/design/custom_colors.dart';
import 'package:celechron/design/app_empty_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/period.dart';

import 'package:celechron/design/sub_title.dart';
import 'package:celechron/widget/agenda_cards.dart';
import 'package:celechron/page/scholar/course_detail/course_detail_view.dart';
import 'flow_controller.dart';
import 'planning_sheet.dart';

class FlowPage extends StatelessWidget {
  FlowPage({super.key});

  final _flowController = Get.put(FlowController());
  final db = Get.find<DatabaseHelper>(tag: 'db');

  Color _periodColor(BuildContext context, Period period) {
    Color color;
    if (period.type == PeriodType.flow) {
      color = AppSemanticColors.focus;
    } else if (period.type == PeriodType.user) {
      color = AppSemanticColors.schedule;
    } else if (period.type == PeriodType.test) {
      color = AppSemanticColors.exam;
    } else if (period.type == PeriodType.classes) {
      color = TimeColors.colorFromHour(period.startTime.hour);
    } else {
      color = AppSemanticColors.neutral;
    }
    return CupertinoDynamicColor.resolve(color, context);
  }

  Widget _agendaCard(BuildContext context, Period period, String? title,
      {required bool featured}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (title != null) SubtitleRow(subtitle: title, padHorizontal: 0),
      Obx(() => AgendaPeriodCard(
            period: period,
            now: _flowController.timeNow.value,
            color: _periodColor(context, period),
            featured: featured,
            onTap: period.type == PeriodType.classes
                ? () => Navigator.of(context, rootNavigator: true).push(
                    CupertinoPageRoute(
                        builder: (context) =>
                            CourseDetailPage(courseId: period.fromUid)))
                : null,
          )),
    ]);
  }

  Widget createFirst(BuildContext context, Period period, String? title) =>
      _agendaCard(context, period, title, featured: true);

  Widget createCard(BuildContext context, Period period, String? title) =>
      _agendaCard(context, period, title, featured: false);

  Future<void> newFlowList(BuildContext context) async {
    String clock(DateTime time) =>
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final times = db
        .getAllowTime()
        .entries
        .map((entry) => '${clock(entry.key)}–${clock(entry.value)}')
        .join('、');
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => Container(
        height: MediaQuery.sizeOf(sheetContext).height * 0.88,
        decoration: BoxDecoration(
          color: CupertinoDynamicColor.resolve(
              CupertinoColors.systemBackground, sheetContext),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: PlanningSheet(
          workTime: db.getWorkTime(),
          restTime: db.getRestTime(),
          availableTimes: times.isEmpty ? '未设置，请先到设置中添加' : times,
          onGenerate: (start) async {
            final result = _flowController.generateNewFlowList(start);
            if (result >= 0) await _flowController.saveFlowListToDb();
            return result;
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: SafeArea(
        child: CustomScrollView(
          // Allow the list to shrink wrap around the top and bottom bars.
          slivers: [
            SliverToBoxAdapter(
              child: SubtitleRow(
                subtitle: '接下来',
                padHorizontal: 16,
                padVertical: 8,
                fontSize: 32,
                right: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Icon(
                        CupertinoIcons.refresh_circled,
                        semanticLabel: '刷新计划',
                      ),
                      onPressed: () async {
                        await newFlowList(context);
                        _flowController.flowList.refresh();
                      },
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Obx(() {
                if (_flowController.isFlowListOutdated()) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                      decoration: BoxDecoration(
                        color: CupertinoDynamicColor.resolve(
                          CupertinoColors.systemOrange.withValues(alpha: 0.1),
                          context,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: CupertinoColors.systemOrange.withValues(
                            alpha: 0.22,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                CupertinoIcons.exclamationmark_triangle_fill,
                                color: CupertinoColors.systemOrange,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '计划需要更新',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      '任务发生了变化，当前安排可能已不再合适。',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: CupertinoColors.secondaryLabel,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              CupertinoButton(
                                sizeStyle: CupertinoButtonSize.small,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                onPressed: () {
                                  _flowController.updateDeadlineListTime();
                                },
                                child: const Text('暂时忽略'),
                              ),
                              CupertinoButton.filled(
                                sizeStyle: CupertinoButtonSize.small,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                onPressed: () async {
                                  await newFlowList(context);
                                  _flowController.flowList.refresh();
                                },
                                child: const Text('重新规划'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox();
              }),
            ),
            Obx(
              () {
                if (_flowController.flowList.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      icon: CupertinoIcons.sparkles,
                      title: '接下来没有安排',
                      message: '享受空闲时间，或创建一份新的专注计划。',
                      actionLabel: '开始规划',
                      onAction: () async {
                        await newFlowList(context);
                        _flowController.flowList.refresh();
                      },
                      minHeight: 0,
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      var container = Container(
                        padding: EdgeInsets.only(
                            top: index == 0 ? 0 : 5,
                            bottom: 5,
                            left: 16,
                            right: 16),
                        child: index == 0
                            ? createFirst(
                                context,
                                _flowController.flowList[index],
                                index == 0
                                    ? (_flowController
                                            .flowList[index].hasStarted
                                        ? '正在进行'
                                        : '即将开始')
                                    : null,
                              )
                            : createCard(
                                context,
                                _flowController.flowList[index],
                                index == 1 ? '之后的安排' : null),
                      );

                      return container;
                    },
                    childCount: _flowController.flowList.length,
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
