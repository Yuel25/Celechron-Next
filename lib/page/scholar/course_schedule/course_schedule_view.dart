import 'dart:math';

import 'package:celechron/utils/tuple.dart';
import 'package:celechron/model/session.dart';
import 'package:celechron/design/persistent_headers.dart';
import 'package:celechron/design/app_visual.dart';
import 'course_schedule_controller.dart';
import 'package:get/get.dart';
import 'package:celechron/design/round_rectangle_card.dart';
import 'course_card.dart';
import 'package:flutter/cupertino.dart';

class CourseSchedulePage extends StatelessWidget {
  late final CourseScheduleController _courseScheduleController;

  CourseSchedulePage(String name, bool first, {super.key}) {
    bool initialHideCourseInfomation = false;
    try {
      initialHideCourseInfomation =
          Get.find<CourseScheduleController>().hideCourseInfomation.value;
    } catch (e) {
      // not initialized
    }
    Get.delete<CourseScheduleController>();
    _courseScheduleController = Get.put(CourseScheduleController(
      initialName: name,
      initialFirstOrSecondSemester: first,
      initialHideCourseInfomation: initialHideCourseInfomation,
    ));
  }

  Widget _semesterPicker(BuildContext context) {
    return RoundRectangleCard(
      animate: false,
      padding: const EdgeInsets.all(AppVisual.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '选择学年',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(14) + 22,
            child: Obx(
              () {
                final selectedIndex =
                    _courseScheduleController.semesterIndex.value;
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _courseScheduleController.semesters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final semester = _courseScheduleController.semesters[index];
                    final selected = selectedIndex == index;
                    return GestureDetector(
                      onTap: () =>
                          _courseScheduleController.semesterIndex.value = index,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
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
          const SizedBox(height: 14),
          Obx(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '学期阶段',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<bool>(
                    groupValue:
                        _courseScheduleController.firstOrSecondSemester.value,
                    children: {
                      true: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '${_courseScheduleController.semester.firstHalfName}学期',
                        ),
                      ),
                      false: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '${_courseScheduleController.semester.secondHalfName}学期',
                        ),
                      ),
                    },
                    onValueChanged: (value) {
                      if (value != null) {
                        _courseScheduleController.firstOrSecondSemester.value =
                            value;
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _courseScheduleController.firstOrSecondSemester.value
                      ? '每两周 ${_courseScheduleController.semester.firstHalfSessionCount} 节课'
                      : '每两周 ${_courseScheduleController.semester.secondHalfSessionCount} 节课',
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _courseSchedule(BuildContext context) {
    const List<String> courseStartTime = [
      "08:00",
      "08:50",
      "10:00",
      "10:50",
      "11:40",
      "13:25",
      "14:15",
      "15:05",
      "16:15",
      "17:05",
      "18:50",
      "19:40",
      "20:30"
    ];
    return RoundRectangleCard(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      border: AppVisual.subtleBorder(context),
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(flex: 1),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    '一',
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 14,
                            ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    '二',
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 14,
                            ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    '三',
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 14,
                            ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    '四',
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 14,
                            ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    '五',
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 14,
                            ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    '六',
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 14,
                            ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    '日',
                    style:
                        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 14,
                            ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 560,
            child: Obx(
              () {
                var sessionsByDayOfWeek =
                    _courseScheduleController.sessionsByDayOfWeek;
                return Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          for (var i = 1; i <= 13; i++)
                            Expanded(
                              child: Center(
                                child: Column(
                                  // mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.fitWidth,
                                      child: Text(
                                        courseStartTime[i - 1],
                                        style: CupertinoTheme.of(context)
                                            .textTheme
                                            .textStyle
                                            .copyWith(
                                              fontSize: 10,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 2,
                                    ),
                                    Text(
                                      i.toString(),
                                      style: CupertinoTheme.of(context)
                                          .textTheme
                                          .textStyle
                                          .copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (var i = 1; i <= 7; i++)
                      Expanded(
                        flex: 2,
                        child: LayoutBuilder(
                          builder: (context, constraints) => Stack(
                            children: [
                              ..._buildCourseScheduleByDayOfWeek(
                                  sessionsByDayOfWeek, i, constraints)
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCourseScheduleByDayOfWeek(
      List<List<Session>> sessionsByDayOfWeek,
      int day,
      BoxConstraints constraints) {
    List<Tuple<int, int>> period = [];
    for (var i = 1; i <= 13; i++) {
      period.add(Tuple(i, i));
    }
    for (var s in sessionsByDayOfWeek[day]) {
      int sl = s.time.first, sr = s.time.last;
      int xl = sl, xr = sr;
      for (var i in period) {
        if (!(i.item2 < sl || sr < i.item1)) {
          xl = min(xl, i.item1);
          xr = max(xr, i.item2);
        }
      }
      period.removeWhere((x) => xl <= x.item1 && x.item2 <= xr);
      period.add(Tuple(xl, xr));
    }
    List<List<Session>> sessionList = [];
    for (var _ in period) {
      sessionList.add([]);
    }
    for (var s in sessionsByDayOfWeek[day]) {
      int sl = s.time.first, sr = s.time.last;
      for (int i = 0; i < period.length; i++) {
        if (!(period[i].item2 < sl || sr < period[i].item1)) {
          bool added = false;
          for (var t in sessionList[i]) {
            if (t.id == s.id) {
              added = true;
              Set<int> timeSet = Set.from(t.time);
              timeSet.addAll(s.time);
              t.time = List.from(timeSet);
              t.time.sort();
              break;
            }
          }
          if (!added) {
            sessionList[i].add(Session.fromJson(s.toJson()));
          }
        }
      }
    }

    List<Widget> cardList = [];
    for (int i = 0; i < period.length; i++) {
      if (sessionList[i].isNotEmpty) {
        cardList.add(
          Positioned.fromRelativeRect(
            rect: RelativeRect.fromLTRB(
              0,
              (period[i].item1 - 1) * constraints.maxHeight / 13,
              0,
              (13 - period[i].item2) * constraints.maxHeight / 13,
            ),
            child: Obx(
              () => SessionCard(
                sessionList: sessionList[i],
                hideInfomation:
                    _courseScheduleController.hideCourseInfomation.value,
              ),
            ),
          ),
        );
      }
    }

    return cardList;

    // return sessionsByDayOfWeek[day]
    //     .map((e) => Positioned.fromRelativeRect(
    //           rect: RelativeRect.fromLTRB(
    //             0,
    //             (e.time.first - 1) * constraints.maxHeight / 13,
    //             0,
    //             (13 - e.time.last) * constraints.maxHeight / 13,
    //           ),
    //           child: SessionCard(sessionList: [e]),
    //         ))
    //     .toList();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(
          CupertinoColors.systemGroupedBackground, context),
      child: CustomScrollView(
        slivers: [
          const CelechronSliverTextHeader(subtitle: '课表'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _semesterPicker(context),
                  const SizedBox(height: 8),
                  // Container(
                  //   padding: const EdgeInsets.only(left: 16, right: 16),
                  //   child: Text(
                  //     '请前往教务网查看冲突选课课表',
                  //     style: TextStyle(
                  //         color: CupertinoDynamicColor.resolve(
                  //             CupertinoColors.secondaryLabel, context),
                  //         fontSize: 14),
                  //   ),
                  // ),
                  // const SizedBox(height: 8),
                  _courseSchedule(context),
                  const SizedBox(height: 20),
                  Obx(
                    () => CupertinoListSection.insetGrouped(
                      margin: const EdgeInsetsDirectional.fromSTEB(
                          0.0, 0.0, 0.0, 10.0),
                      additionalDividerMargin: 2,
                      children: <CupertinoListTile>[
                        CupertinoListTile(
                            title: const Text('隐藏课程信息'),
                            trailing: CupertinoSwitch(
                              value: _courseScheduleController
                                  .hideCourseInfomation.value,
                              onChanged: (value) async {
                                _courseScheduleController
                                    .hideCourseInfomation.value = value;
                              },
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
