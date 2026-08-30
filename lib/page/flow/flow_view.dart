import 'dart:async';
import 'dart:math';
import 'package:celechron/design/custom_colors.dart';
import 'package:celechron/design/custom_decoration.dart';
import 'package:celechron/design/app_empty_state.dart';
import 'package:celechron/utils/time_helper.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/utils/utils.dart';

import 'package:celechron/design/sub_title.dart';
import 'package:celechron/design/round_rectangle_card.dart';
import 'package:celechron/page/scholar/course_detail/course_detail_view.dart';
import 'flow_controller.dart';

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

  String _periodTypeLabel(PeriodType type) => switch (type) {
        PeriodType.classes => '课程',
        PeriodType.test => '考试',
        PeriodType.user => '日程',
        PeriodType.flow => '专注',
        PeriodType.virtual => '空闲',
      };

  Widget createFirst(context, Period period, String? title) {
    final themeColor = _periodColor(context, period);
    final brightness = CupertinoTheme.of(context).brightness ??
        MediaQuery.platformBrightnessOf(context);
    return Column(
      children: [
        title == null
            ? const SizedBox(height: 0)
            : SubtitleRow(subtitle: title, padHorizontal: 0),
        RoundRectangleCard(
          borderRadius: 16,
          color: themeColor.withValues(
            alpha: brightness == Brightness.dark ? 0.16 : 0.08,
          ),
          border: Border.all(
            color: themeColor.withValues(
              alpha: brightness == Brightness.dark ? 0.42 : 0.22,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: themeColor.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          padding: const EdgeInsets.all(16),
          onTap: period.type == PeriodType.classes
              ? () async => Navigator.of(context, rootNavigator: true).push(
                  CupertinoPageRoute(
                      builder: (context) =>
                          CourseDetailPage(courseId: period.fromUid)))
              : null,
          child: Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Column(children: [
                      Row(children: [
                        Container(
                          width: 12.0,
                          height: 12.0,
                          decoration: customDecoration(
                            color: themeColor,
                            shape: periodTypeShape[period.type]!,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            period.summary,
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _periodTypeLabel(period.type),
                            style: TextStyle(
                              color: themeColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ]),
                      Divider(
                        thickness: 0,
                        color: CupertinoDynamicColor.resolve(
                            CupertinoColors.separator, context),
                        height: 14,
                      ),
                      Row(
                        children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Row(children: [
                                  Icon(
                                    CupertinoIcons.location_solid,
                                    size: 14,
                                    color: themeColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                      child: Text(period.location,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures()
                                            ],
                                            color: CupertinoTheme.of(context)
                                                .textTheme
                                                .textStyle
                                                .color!,
                                            overflow: TextOverflow.ellipsis,
                                          ))),
                                ]),
                              ])),
                        ],
                      ),
                    ])),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.time_solid,
                              size: 14,
                              color: themeColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              period.friendlyTimeTodayBased,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                color: CupertinoTheme.of(context)
                                    .textTheme
                                    .textStyle
                                    .color!
                                    .withValues(alpha: 0.75),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Obx(
                                () => period.startTime
                                        .isBefore(_flowController.timeNow.value)
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '离结束还有',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.normal,
                                              color: CupertinoTheme.of(context)
                                                  .textTheme
                                                  .textStyle
                                                  .color!
                                                  .withValues(alpha: 0.75),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            TimeHelper.toHMS(period.endTime
                                                .difference(_flowController
                                                    .timeNow.value)),
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: CupertinoTheme.of(context)
                                                  .textTheme
                                                  .textStyle
                                                  .color!,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '开始还有',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.normal,
                                              color: CupertinoTheme.of(context)
                                                  .textTheme
                                                  .textStyle
                                                  .color!
                                                  .withValues(alpha: 0.75),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            TimeHelper.toHMS(period.startTime
                                                .difference(_flowController
                                                    .timeNow.value)),
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures()
                                              ],
                                              color: CupertinoTheme.of(context)
                                                  .textTheme
                                                  .textStyle
                                                  .color!,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                    builder: (context, constraints) => Stack(
                          children: [
                            SizedBox(
                              height: 8,
                              width: (constraints.maxWidth),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: CupertinoDynamicColor.resolve(
                                      CupertinoColors.separator, context),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            Obx(() => SizedBox(
                                  height: 8,
                                  width: _flowController.isDuringFlow
                                      ? (max(
                                              (constraints.maxWidth) *
                                                  _flowController.timeNow.value
                                                      .difference(
                                                          period.startTime)
                                                      .inMilliseconds /
                                                  period.endTime
                                                      .difference(
                                                          period.startTime)
                                                      .inMilliseconds,
                                              0.0)
                                          .clamp(
                                          0.0,
                                          constraints.maxWidth,
                                        ))
                                      : (constraints.maxWidth),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: CupertinoDynamicColor.resolve(
                                          themeColor, context),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ))
                          ],
                        )),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget createCard(context, Period period, String? title) {
    final themeColor = _periodColor(context, period);
    return Column(
      children: [
        title == null
            ? const SizedBox(height: 0)
            : SubtitleRow(subtitle: title, padHorizontal: 0),
        RoundRectangleCard(
            onTap: period.type == PeriodType.classes
                ? () async => Navigator.of(context, rootNavigator: true).push(
                    CupertinoPageRoute(
                        builder: (context) =>
                            CourseDetailPage(courseId: period.fromUid)))
                : null,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: Row(
                children: [
                  Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 12.0,
                                height: 12.0,
                                decoration: customDecoration(
                                  color: themeColor,
                                  shape: periodTypeShape[period.type]!,
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(
                                  child: Text(period.summary,
                                      style: CupertinoTheme.of(context)
                                          .textTheme
                                          .textStyle
                                          .copyWith(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            overflow: TextOverflow.ellipsis,
                                          ))),
                            ],
                          ),
                          const SizedBox(height: 4.0),
                          Row(children: [
                            Icon(
                              CupertinoIcons.time_solid,
                              size: 14,
                              color: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle
                                  .color!
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(
                              period.friendlyTimeTodayBased,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                color: CupertinoTheme.of(context)
                                    .textTheme
                                    .textStyle
                                    .color!
                                    .withValues(alpha: 0.75),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                          ]),
                          if (period.location.isNotEmpty) ...[
                            Row(children: [
                              Icon(
                                CupertinoIcons.location_solid,
                                size: 14,
                                color: CupertinoTheme.of(context)
                                    .textTheme
                                    .textStyle
                                    .color!
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(period.location,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.normal,
                                        color: CupertinoTheme.of(context)
                                            .textTheme
                                            .textStyle
                                            .color!
                                            .withValues(alpha: 0.75),
                                        overflow: TextOverflow.ellipsis,
                                      )))
                            ]),
                          ],
                        ],
                      )),
                  // If the period starts before now and ends after now, it is ongoing. Then, we show time to end
                  /*Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (period.startTime.isBefore(DateTime.now()) &&
                              period.endTime.isAfter(DateTime.now()))
                            Text(
                              '结束还有\n${durationToString(period.endTime.difference(DateTime.now()))}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                color: CupertinoTheme.of(context)
                                    .textTheme
                                    .textStyle
                                    .color!
                                    .withValues(alpha: 0.75),
                              ),
                              textAlign: TextAlign.right,
                            )
                          else
                            Text(
                              '开始还有\n${durationToString(period.startTime.difference(DateTime.now()))}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                color: CupertinoTheme.of(context)
                                    .textTheme
                                    .textStyle
                                    .color!
                                    .withValues(alpha: 0.75),
                              ),
                              textAlign: TextAlign.right,
                            ),
                        ],
                      )),*/
                ],
              ),
            ))
      ],
    );
  }

  Future<void> newFlowList(context) async {
    DateTime newTime = DateTime.now()
        .add(const Duration(seconds: 90))
        .copyWith(second: 0, millisecond: 0, microsecond: 0);
    await showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text(
            '开始规划',
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 8,
                    ),
                    const Text(
                      '点击修改开始时间',
                    ),
                    CupertinoButton(
                      onPressed: () async {
                        await showCupertinoModalPopup(
                            context: context,
                            builder: (BuildContext context) {
                              return CupertinoPageScaffold(
                                child: SizedBox(
                                  height: MediaQuery.of(context)
                                          .copyWith()
                                          .size
                                          .height /
                                      3,
                                  child: CupertinoDatePicker(
                                    initialDateTime: newTime,
                                    use24hFormat: true,
                                    minuteInterval: 1,
                                    mode: CupertinoDatePickerMode.dateAndTime,
                                    onDateTimeChanged: (DateTime val) {
                                      setState(() {
                                        newTime = val;
                                      });
                                    },
                                  ),
                                ),
                              );
                            });
                      },
                      child: Text(TimeHelper.chineseDateTime(newTime)),
                    ),
                    Text(
                      '工作 ${durationToString(db.getWorkTime())} - 休息 ${durationToString(db.getRestTime())}',
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => navigator!.pop(),
              child: const Text('返回'),
            ),
            CupertinoDialogAction(
              onPressed: () {
                if (newTime.isAfter(DateTime.now())) {
                  int ret = _flowController.generateNewFlowList(newTime);
                  if (ret < 0) {
                    showCupertinoDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return CupertinoAlertDialog(
                          title: const Text(
                            '时间不够了！',
                          ),
                          content: const Text(
                              '即使是完全不休息也有任务无法完成。请压缩任务的预期时间，或者检查是否有任务在规划开始时间之前就结束。'),
                          actions: [
                            CupertinoDialogAction(
                              child: const Text('确定'),
                              onPressed: () async {
                                Navigator.of(context).pop();
                              },
                            )
                          ],
                        );
                      },
                    );
                  } else if (ret != db.getRestTime().inMinutes) {
                    navigator!.pop();
                    showCupertinoDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return CupertinoAlertDialog(
                          title: const Text(
                            '休息时间已压缩',
                          ),
                          content: Text(
                              '因为任务过多，你需要把休息时间压缩到 ${durationToString(Duration(minutes: ret))}才能完成任务。'),
                          actions: [
                            CupertinoDialogAction(
                              child: const Text('确定'),
                              onPressed: () async {
                                Navigator.of(context).pop();
                              },
                            )
                          ],
                        );
                      },
                    );
                  } else {
                    navigator!.pop();
                  }
                } else {
                  showCupertinoDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return CupertinoAlertDialog(
                        title: const Text(
                          '开始时间必须晚于现在',
                        ),
                        content: const Text('请调整开始时间。'),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text('确定'),
                            onPressed: () async {
                              Navigator.of(context).pop();
                            },
                          )
                        ],
                      );
                    },
                  );
                }
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
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

                int? lastWaitingFlowIndex;
                for (int i = 0; i < _flowController.flowList.length; i++) {
                  if (!_flowController.flowList[i].hasStarted) {
                    lastWaitingFlowIndex = i;
                    break;
                  }
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
                        child: (_flowController.flowList[index].hasStarted ||
                                index == 0)
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
                                index == lastWaitingFlowIndex ? '之后的安排' : null),
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
