import 'package:celechron/design/custom_colors.dart';
import 'package:celechron/design/app_empty_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:celechron/model/period.dart';

import 'package:celechron/design/sub_title.dart';
import 'package:celechron/widget/agenda_cards.dart';
import 'package:celechron/page/scholar/course_detail/course_detail_view.dart';
import 'flow_controller.dart';

class FlowPage extends StatelessWidget {
  FlowPage({super.key});

  final _flowController = Get.put(FlowController());

  Color _periodColor(BuildContext context, Period period) {
    Color color;
    if (period.type == PeriodType.user) {
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

  Widget createFirst(BuildContext context, Period period) {
    return Obx(() {
      final now = _flowController.timeNow.value;
      final isStarted = !period.startTime.isAfter(now);
      final title = isStarted ? '正在进行' : '即将开始';
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SubtitleRow(subtitle: title, padHorizontal: 0),
        AgendaPeriodCard(
          period: period,
          now: now,
          color: _periodColor(context, period),
          featured: true,
          onTap: period.type == PeriodType.classes
              ? () => Navigator.of(context, rootNavigator: true).push(
                  CupertinoPageRoute(
                      builder: (context) =>
                          CourseDetailPage(courseId: period.fromUid)))
              : null,
        ),
      ]);
    });
  }

  Widget createCard(BuildContext context, Period period, String? title) =>
      _agendaCard(context, period, title, featured: false);

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: SafeArea(
        child: CustomScrollView(
          // Allow the list to shrink wrap around the top and bottom bars.
          slivers: [
            const SliverToBoxAdapter(
              child: SubtitleRow(
                subtitle: '接下来',
                padHorizontal: 16,
                padVertical: 8,
                fontSize: 32,
              ),
            ),
            Obx(
              () {
                if (_flowController.flowList.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      icon: CupertinoIcons.sparkles,
                      title: '接下来没有安排',
                      message: '享受空闲时间，或前往日程页添加日程。',
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
