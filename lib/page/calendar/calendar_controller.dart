import 'package:celechron/model/task.dart';
import 'package:celechron/utils/utils.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/model/semester.dart';

enum CalendarViewMode {
  calendar,
  schedule,
}

class CalendarController extends GetxController {
  final selectedDay = DateTime.now().obs;
  final focusedDay = DateTime.now().obs;
  final calendarFormat = CalendarFormat.month.obs;
  final events = <DateTime, List<Period>>{}.obs;
  final scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  final taskList = Get.find<RxList<Task>>(tag: 'taskList');
  final viewMode = CalendarViewMode.calendar.obs;

  static List<String> numToChinese = ['一', '二', '三', '四', '五', '六', '七', '八'];

  String dayDescription(DateTime day) {
    var semester = scholar.value.semesters.firstWhereOrNull(
        (e) => !day.isBefore(e.firstDay) && !day.isAfter(e.lastDay));
    if (semester == null) return '考试周/假期';

    var toFirstWeek = day.difference(semester.firstDay).inDays ~/ 7;
    if (toFirstWeek < 8) {
      return '${semester.name[9]}${numToChinese[toFirstWeek]}周';
    }
    var toLastWeek = 7 - semester.lastDay.difference(day).inDays ~/ 7;
    if (toLastWeek < 8) {
      return '${semester.name[10]}${numToChinese[toLastWeek]}周';
    }
    return '考试周/假期';
  }

  @override
  void onInit() {
    refreshEvents();
    ever(scholar, (callback) => refreshEvents());
    super.onInit();
  }

  void refreshEvents() {
    events.clear();
    Set<DateTime> keySet = {};
    for (var element in Get.find<Rx<Scholar>>(tag: 'scholar').value.periods) {
      DateTime chop = chopDate(element.startTime);
      if (events[chop] == null) events[chop] = <Period>[];
      events[chop]!.add(element);
      keySet.add(chop);
    }
    for (var i in keySet) {
      events[i]!.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
  }

  DateTime chopDate(DateTime day) {
    return DateTime(day.year, day.month, day.day);
  }

  List<Period> getEventsForDay(DateTime day) {
    DateTime chop = chopDate(day);
    var eventsOfDay = <Period>[];
    if (events[chop] != null) {
      for (var event in events[chop]!) {
        eventsOfDay.add(event.copyWith());
      }
    }
    for (var deadline in taskList) {
      if (deadline.type == TaskType.fixed ||
          deadline.type == TaskType.fixedlegacy) {
        List<Period> periods = deadline.getPeriodOfDay(dateOnly(day));
        for (var p in periods) {
          eventsOfDay.add(p);
        }
      }
    }
    eventsOfDay.sort((a, b) => a.startTime.compareTo(b.startTime));
    return eventsOfDay;
  }

  void toggleViewMode() {
    viewMode.value = viewMode.value == CalendarViewMode.calendar
        ? CalendarViewMode.schedule
        : CalendarViewMode.calendar;
  }

  Semester? getCurrentSemester([DateTime? targetTime]) {
    final now = targetTime ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return scholar.value.semesters.firstWhereOrNull((e) {
      final start = DateTime(e.firstDay.year, e.firstDay.month, e.firstDay.day);
      final end = DateTime(e.lastDay.year, e.lastDay.month, e.lastDay.day);
      return !today.isBefore(start) && !today.isAfter(end);
    });
  }

  Semester? getUpcomingSemester([DateTime? targetTime]) {
    final now = targetTime ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final futureSemesters = scholar.value.semesters.where((s) {
      final start = DateTime(s.firstDay.year, s.firstDay.month, s.firstDay.day);
      return start.isAfter(today);
    }).toList();
    if (futureSemesters.isEmpty) return null;
    futureSemesters.sort((a, b) => a.firstDay.compareTo(b.firstDay));
    return futureSemesters.first;
  }

  Semester? getDisplayedSemester([DateTime? targetTime]) {
    return getCurrentSemester(targetTime) ?? getUpcomingSemester(targetTime);
  }

  bool isFirstHalfSemester(Semester semester, [DateTime? targetTime]) {
    final now = targetTime ?? DateTime.now();
    final toFirstWeek = now.difference(semester.firstDay).inDays ~/ 7;
    return toFirstWeek < 8;
  }

  String getCurrentSemesterDisplayName([DateTime? targetTime]) {
    final semester = getCurrentSemester(targetTime);
    if (semester != null) {
      final isFirstHalf = isFirstHalfSemester(semester, targetTime);
      if (semester.name.length >= 11) {
        final semesterName =
            '${semester.name.substring(2, 5)}${semester.name.substring(7, 11)}';
        final halfName =
            isFirstHalf ? semester.firstHalfName : semester.secondHalfName;
        return '$semesterName $halfName学期';
      }
      return semester.name;
    }

    final upcoming = getUpcomingSemester(targetTime);
    if (upcoming != null) {
      if (upcoming.name.length >= 11) {
        final semesterName =
            '${upcoming.name.substring(2, 5)}${upcoming.name.substring(7, 11)}';
        final halfName = upcoming.firstHalfName;
        return '未开学 · $semesterName $halfName学期';
      }
      return '未开学 · ${upcoming.name}';
    }

    return '无学期信息';
  }

  String getDisplayedSemesterDisplayName([DateTime? targetTime]) =>
      getCurrentSemesterDisplayName(targetTime);
}
