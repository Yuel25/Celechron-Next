import 'package:get/get.dart';
import 'package:flutter/foundation.dart';

import 'package:celechron/http/zjuServices/exceptions.dart';
import 'package:celechron/page/option/option_controller.dart';
import 'package:celechron/services/diagnostic_log_service.dart';
import 'package:celechron/services/refresh_coordinator.dart';
import 'package:celechron/utils/grade_grouping.dart';
import 'package:celechron/utils/json_utils.dart';
import 'package:celechron/model/practice_score_item.dart';

import 'period.dart';
import 'grade.dart';
import 'semester.dart';
import 'todo.dart';
import 'package:celechron/utils/gpa_helper.dart';
import 'package:celechron/http/spider.dart';
import 'package:celechron/http/ugrs_spider.dart';
import 'package:celechron/http/grs_spider.dart';
import 'package:celechron/database/database_helper.dart';

part 'scholar_json.dart';
part 'scholar_sync.dart';

/// 学业领域数据模型。登录/刷新编排在 [ScholarSyncService]（part），
/// 序列化在 scholar_json.dart（part）；对外仍保留 login/refresh 薄封装。
class Scholar {
  Scholar() {
    _sync = ScholarSyncService(this);
  }

  // 构造用户对象
  DatabaseHelper? db;
  late final ScholarSyncService _sync;

  // 登录状态
  bool isLogan = false;
  DateTime lastUpdateTimeGrade = DateTime.parse("20010101");
  DateTime lastUpdateTimeCourse = DateTime.parse("20010101");
  DateTime lastUpdateTimeHomework = DateTime.parse("20010101");

  // 凭据真源在 secure storage；Hive JSON 字段仅为 <=0.2.6 兼容读取。
  String? username;
  String? password;

  bool get isGrs {
    final id = username;
    if (id == null || id.isEmpty) return false;
    // 浙大本科学号以 3 开头；研究生等其它培养层次不以 3 开头。
    return !id.startsWith('3');
  }

  // 按学期整理好的学业信息，包括该学期的所有科目、考试、课表、均绩等
  List<Semester> semesters = <Semester>[];

  // 按课程号整理好的成绩单（方便算重修成绩）
  Map<String, List<Grade>> grades = {};

  // 保研 GPA, 四个数据依次为五分制、四分制（4.3 分制）、原始的四分制、百分制
  List<double> gpa = [0.0, 0.0, 0.0, 0.0];

  // 出国 GPA, 四个数据依次为五分制、四分制（4.3 分制）、原始的四分制、百分制
  List<double> aboardGpa = [0.0, 0.0, 0.0, 0.0];

  // 所获学分
  double credit = 0.0;

  // 特殊日期
  Map<DateTime, String> specialDates = {};

  // 作业（学在浙大）
  List<Todo> todos = [];

  // 素质拓展记点；Jf 是“记点”。
  double pt2 = 0.0; // 第二课堂记点
  double pt3 = 0.0; // 第三课堂记点
  double pt4 = 0.0; // 第四课堂记点
  bool isPracticeScoresGet = false; // 是否有可展示的二三四课堂记点
  List<PracticeScoreItem> practiceScoreItems = [];
  // 明细来源始终只描述 getSqjl，不与外层正式汇总混用。
  PracticeDataSource practiceDataSource = PracticeDataSource.unavailable;
  PracticeSummarySource practiceSummarySource =
      PracticeSummarySource.unavailable;
  DateTime? practiceUpdatedAt;
  DateTime? practiceDetailsUpdatedAt;
  bool practiceDetailsAvailable = false;
  bool practiceDetailsStale = false;
  bool practiceSummaryStale = false;
  bool? practiceMyPassed;
  bool? practiceLyPassed;

  /// 总记点只由第二、第三、第四课堂三个记点字段组成。
  double get practiceTotalJf => pt2 + pt3 + pt4;

  int get gradedCourseCount {
    return grades.values.fold(0, (p, e) => p + e.length);
  }

  List<Period> get periods {
    return semesters.fold(<Period>[], (p, e) => p + e.periods);
  }

  Semester get thisSemester {
    if (semesters.length > 1) {
      if (semesters[1]
          .periods
          .last
          .endTime
          .isAfter(DateTime.now().subtract(const Duration(days: 14)))) {
        return semesters[1];
      } else {
        return semesters[0];
      }
    } else {
      return semesters.isEmpty ? Semester('未刷新') : semesters.first;
    }
  }

  bool get isNearExamWeek {
    var thisSem = thisSemester;
    for (var exam in thisSem.exams) {
      var now = DateTime.now();
      if (now.isAfter(exam.time[0].subtract(const Duration(days: 3))) &&
          now.isBefore(exam.time[0].add(const Duration(days: 3)))) {
        return true;
      }
    }
    return false;
  }

  Future<List<String?>> login({
    RefreshOrigin origin = RefreshOrigin.foreground,
  }) {
    return _sync.login(origin: origin);
  }

  Future<bool> logout() async {
    username = "";
    password = "";
    semesters = [];
    grades = {};
    gpa = [0.0, 0.0, 0.0, 0.0];
    aboardGpa = [0.0, 0.0, 0.0, 0.0];
    credit = 0.0;
    pt2 = 0.0;
    pt3 = 0.0;
    pt4 = 0.0;
    isPracticeScoresGet = false;
    practiceScoreItems = [];
    practiceDataSource = PracticeDataSource.unavailable;
    practiceSummarySource = PracticeSummarySource.unavailable;
    practiceUpdatedAt = null;
    practiceDetailsUpdatedAt = null;
    practiceDetailsAvailable = false;
    practiceDetailsStale = false;
    practiceSummaryStale = false;
    practiceMyPassed = null;
    practiceLyPassed = null;
    isLogan = false;
    lastUpdateTimeGrade = DateTime.parse("20010101");
    lastUpdateTimeCourse = DateTime.parse("20010101");
    lastUpdateTimeHomework = DateTime.parse("20010101");
    _sync.disposeSession();
    await db?.removeScholar();
    await db?.removeAllCachedWebPage();
    return true;
  }

  Future<List<String?>> refresh({
    RefreshOrigin origin = RefreshOrigin.foreground,
    void Function()? onPartialUpdate,
    void Function(List<ModuleFetchStatus> statuses)? onFetchStatus,
    void Function()? onBackgroundYield,
  }) {
    return _sync.refresh(
      origin: origin,
      onPartialUpdate: onPartialUpdate,
      onFetchStatus: onFetchStatus,
      onBackgroundYield: onBackgroundYield,
    );
  }

  void updateLastUpdateTime(List<String?> errorMessage) {
    var errorItems = ["成绩", "课表", "作业"];
    var errorResult = [false, false, false];

    for (int i = 0; i < errorItems.length; i++) {
      for (var e in errorMessage) {
        if (e != null && e.contains(errorItems[i])) {
          errorResult[i] = true;
          break;
        }
      }
    }
    if (!errorResult[0]) {
      lastUpdateTimeGrade = DateTime.now();
    }
    if (!errorResult[1]) {
      lastUpdateTimeCourse = DateTime.now();
    }
    if (!errorResult[2]) {
      lastUpdateTimeHomework = DateTime.now();
    }
  }

  void setScholar(
      List<String?> errorMessage,
      List<Semester> tempSemesters,
      Map<String, List<Grade>> tempGrades,
      Map<DateTime, String> tempSpecialDates,
      List<Todo> tempTodos,
      PracticeScoreSnapshot? tempPracticeSnapshot) {
    // 各模块独立降级：某一来源失败时保留该模块旧数据，不阻断其它成功结果。
    var errorItems = ["成绩", "课表", "作业", "实践"];
    var errorResult = [false, false, false, false];

    for (int i = 0; i < errorItems.length; i++) {
      for (var e in errorMessage) {
        if (e != null &&
            !isDegradedRefreshText(e) &&
            e.contains(errorItems[i])) {
          errorResult[i] = true;
          break;
        }
      }
    }

    if (tempSpecialDates.isNotEmpty) {
      specialDates = tempSpecialDates;
    }
    if (errorResult[0] == false && tempGrades.isNotEmpty) {
      grades = tempGrades;
    }
    if (errorResult[1] == false && tempSemesters.isNotEmpty) {
      semesters = tempSemesters;
    } else if (tempSemesters.isNotEmpty) {
      // 降级刷新只合并可用片段，避免不完整新对象覆盖已有课表明细。
      for (final incoming in tempSemesters) {
        final existingIndex =
            semesters.indexWhere((semester) => semester.name == incoming.name);
        if (existingIndex < 0) {
          semesters.add(incoming);
        } else {
          semesters[existingIndex].mergePartialFrom(incoming);
        }
      }
      semesters.sort((a, b) => b.name.compareTo(a.name));
    }
    if (errorResult[2] == false) {
      todos = tempTodos;
    }
    if (tempPracticeSnapshot != null) {
      // 详情仍只采用 getSqjl；汇总独立采用 getMyInfo 的三级回退结果。
      final snapshot = tempPracticeSnapshot;
      if (snapshot.detailsAvailable) {
        practiceScoreItems = List<PracticeScoreItem>.from(snapshot.items);
        practiceDataSource = snapshot.source;
        practiceDetailsUpdatedAt = snapshot.updatedAt;
        practiceDetailsAvailable = true;
        practiceDetailsStale = snapshot.stale;
      } else if (snapshot.source == PracticeDataSource.unavailable) {
        // getSqjl 失败不能清空上一次成功明细。
        practiceDetailsAvailable = practiceScoreItems.isNotEmpty;
        practiceDetailsStale = true;
      }

      final summary = snapshot.summary;
      if (summary != null) {
        isPracticeScoresGet = true;
        practiceSummarySource = summary.source;
        practiceUpdatedAt = summary.updatedAt;
        practiceSummaryStale = summary.stale;
        practiceMyPassed = summary.myPassed;
        practiceLyPassed = summary.lyPassed;
        pt2 = summary.dektJf;
        pt3 = summary.dsktJf;
        pt4 = summary.dsiktJf;
      }
    }
  }

  Map<String, dynamic> toJson() => buildScholarToJson(this);

  /// 按当前 [grades] 重算保研/出国 GPA 与学分，不触发持久化。
  void recomputeGpaFromGrades() {
    // 保研成绩，只取第一次
    var netGrades = grades.values.map((e) => e.first);
    if (netGrades.isNotEmpty) {
      gpa = GpaHelper.calculateGpa(netGrades).item1;
    }
    // 出国成绩，取最高的一次
    var aboardNetGrades = grades.values.map((e) {
      e.sort((a, b) => a.hundredPoint.compareTo(b.hundredPoint));
      return e.last;
    });
    if (aboardNetGrades.isNotEmpty) {
      var result = GpaHelper.calculateGpa(aboardNetGrades);
      aboardGpa = result.item1;
      // 所获学分，不包括挂科的。
      credit = result.item2;
    } else {
      credit = 0.0;
    }
  }

  Future<void> recalculateGpa() async {
    final courseIdMappingMap = {
      for (final mapping in Get.find<OptionController>(tag: 'optionController')
          .courseIdMappingList)
        mapping.id1: mapping.id2
    };
    grades = groupGradesByCourseKey(
      grades.values.expand((e) => e),
      courseIdMappingMap,
    );

    recomputeGpaFromGrades();
    await db?.setScholar(this);
  }

  Scholar.fromJson(Map<String, dynamic> json) {
    _sync = ScholarSyncService(this);
    applyScholarFromJson(this, json);
  }
}
