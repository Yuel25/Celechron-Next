part of 'scholar.dart';

/// 从本地缓存 JSON 恢复 Scholar。凭据在 <=0.2.6 曾写入 JSON，现仅作兼容读取，
/// 真源在 secure storage（见 DatabaseHelper.getScholar）。
void applyScholarFromJson(Scholar scholar, Map<String, dynamic> json) {
  scholar.username = asString(json['username']); // <=0.2.6 Compatibility
  scholar.password = asString(json['password']); // <=0.2.6 Compatibility

  scholar.semesters = [];
  for (final rawSemester in asDynamicList(json['semesters']) ?? const []) {
    final semesterMap = asStringMap(rawSemester);
    if (semesterMap == null) continue;
    try {
      scholar.semesters.add(Semester.fromJson(semesterMap));
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('跳过损坏的本地学期数据：${error.runtimeType}: $error\n$stackTrace');
      }
    }
  }

  scholar.grades = {};
  final rawGrades = asStringMap(json['grades']) ?? const {};
  for (final entry in rawGrades.entries) {
    final parsedGrades = <Grade>[];
    for (final rawGrade in asDynamicList(entry.value) ?? const []) {
      final gradeMap = asStringMap(rawGrade);
      if (gradeMap == null) continue;
      try {
        final grade = Grade.fromJson(gradeMap);
        if (grade.id.isNotEmpty) parsedGrades.add(grade);
      } on Object catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('跳过损坏的本地成绩数据：${error.runtimeType}: $error\n$stackTrace');
        }
      }
    }
    if (parsedGrades.isNotEmpty) scholar.grades[entry.key] = parsedGrades;
  }

  List<double> numberList(Object? value, int expectedLength) {
    final parsed = (asDynamicList(value) ?? const [])
        .map(asDouble)
        .whereType<double>()
        .toList();
    if (expectedLength == 4 && parsed.length == 3) {
      parsed.insert(2, 0.0);
    }
    return parsed.length == expectedLength
        ? parsed
        : List<double>.filled(expectedLength, 0.0);
  }

  scholar.gpa = numberList(json['gpa'], 4);
  scholar.aboardGpa = numberList(json['aboardGpa'], 4);
  scholar.credit = asDouble(json['credit']) ?? 0.0;

  scholar.specialDates = {};
  for (final entry in (asStringMap(json['specialDates']) ?? const {}).entries) {
    final date = asDateTime(entry.key);
    final description = asString(entry.value);
    if (date != null && description != null) {
      scholar.specialDates[date] = description;
    }
  }
  scholar.lastUpdateTimeGrade =
      asDateTime(json['lastUpdateTimeGrade']) ?? DateTime(2001);
  scholar.lastUpdateTimeCourse =
      asDateTime(json['lastUpdateTimeCourse']) ?? DateTime(2001);
  scholar.lastUpdateTimeHomework =
      asDateTime(json['lastUpdateTimeHomework']) ?? DateTime(2001);

  scholar.todos = [];
  for (final rawTodo in asDynamicList(json['todos']) ?? const []) {
    final todoMap = asStringMap(rawTodo);
    if (todoMap == null) continue;
    try {
      final todo = Todo.fromJson(todoMap);
      if (todo.id.isNotEmpty) scholar.todos.add(todo);
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('跳过损坏的本地作业数据：${error.runtimeType}: $error\n$stackTrace');
      }
    }
  }
  scholar.pt2 = asDouble(json['pt2']) ?? 0.0;
  scholar.pt3 = asDouble(json['pt3']) ?? 0.0;
  scholar.pt4 = asDouble(json['pt4']) ?? 0.0;
  scholar.isPracticeScoresGet = asBool(json['isPracticeScoresGet']) ?? false;
  // 字段是否存在用于区分旧版缓存与“新版缓存但项目为空”。
  final hasPracticeItemsField = json.containsKey('practiceScoreItems');
  scholar.practiceScoreItems = [];
  for (final rawItem in asDynamicList(json['practiceScoreItems']) ?? const []) {
    final itemMap = asStringMap(rawItem);
    if (itemMap == null) continue;
    try {
      final item = PracticeScoreItem.fromJson(itemMap);
      if (!item.deleted) scholar.practiceScoreItems.add(item);
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('跳过损坏的本地实践项目数据：${error.runtimeType}: $error\n$stackTrace');
      }
    }
  }
  scholar.practiceDataSource = PracticeDataSource.fromJson(
    json['practiceDataSource'],
  );
  final hasPracticeSummarySource = json.containsKey('practiceSummarySource');
  scholar.practiceSummarySource = PracticeSummarySource.fromJson(
    json['practiceSummarySource'],
  );
  scholar.practiceUpdatedAt = asDateTime(json['practiceUpdatedAt'])?.toLocal();
  scholar.practiceDetailsUpdatedAt =
      asDateTime(json['practiceDetailsUpdatedAt'])?.toLocal() ??
          scholar.practiceUpdatedAt;
  scholar.practiceDetailsAvailable = asBool(json['practiceDetailsAvailable']) ??
      (hasPracticeItemsField && scholar.practiceScoreItems.isNotEmpty);
  scholar.practiceDetailsStale = asBool(json['practiceDetailsStale']) ?? false;
  scholar.practiceSummaryStale =
      asBool(json['practiceSummaryStale']) ?? hasPracticeSummarySource;
  scholar.practiceMyPassed = asBool(json['practiceMyPassed']);
  scholar.practiceLyPassed = asBool(json['practiceLyPassed']);
  if (!json.containsKey('practiceDataSource') && scholar.isPracticeScoresGet) {
    // 旧版本只保存教务网汇总，因此恢复为无明细且过期的兼容来源。
    scholar.practiceDataSource = PracticeDataSource.zdbkCache;
    scholar.practiceDetailsAvailable = false;
    scholar.practiceDetailsStale = true;
  }
  if (!hasPracticeSummarySource &&
      hasPracticeItemsField &&
      scholar.practiceDetailsAvailable) {
    // 旧版有明细时，其外层总分原本就是 getSqjl 项目合计。
    final totals = PracticeScoreItem.approvedTotals(scholar.practiceScoreItems);
    scholar.pt2 = totals[1] ?? 0;
    scholar.pt3 = totals[2] ?? 0;
    scholar.pt4 = totals[3] ?? 0;
    scholar.practiceSummarySource = PracticeSummarySource.calculatedFromSqjl;
    scholar.practiceSummaryStale = true;
  } else if (!hasPracticeSummarySource && scholar.isPracticeScoresGet) {
    scholar.practiceSummarySource = PracticeSummarySource.legacyPersisted;
    scholar.practiceSummaryStale = true;
  } else if (scholar.practiceSummarySource ==
      PracticeSummarySource.networkMyInfo) {
    // 从 Scholar 持久化恢复后已不是本次网络结果，按缓存语义展示。
    scholar.practiceSummarySource = PracticeSummarySource.cachedMyInfo;
    scholar.practiceSummaryStale = true;
  }
  scholar.isLogan = true;
}

Map<String, dynamic> buildScholarToJson(Scholar scholar) {
  return {
    'semesters': scholar.semesters,
    'grades': scholar.grades,
    'gpa': scholar.gpa,
    'aboardGpa': scholar.aboardGpa,
    'credit': scholar.credit,
    'specialDates':
        scholar.specialDates.map((k, v) => MapEntry(k.toIso8601String(), v)),
    'lastUpdateTimeGrade': scholar.lastUpdateTimeGrade.toIso8601String(),
    'lastUpdateTimeCourse': scholar.lastUpdateTimeCourse.toIso8601String(),
    'lastUpdateTimeHomework': scholar.lastUpdateTimeHomework.toIso8601String(),
    'todos': scholar.todos,
    'pt2': scholar.pt2,
    'pt3': scholar.pt3,
    'pt4': scholar.pt4,
    'isPracticeScoresGet': scholar.isPracticeScoresGet,
    'practiceScoreItems':
        scholar.practiceScoreItems.map((item) => item.toJson()).toList(),
    'practiceDataSource': scholar.practiceDataSource.name,
    'practiceSummarySource': scholar.practiceSummarySource.name,
    'practiceUpdatedAt': scholar.practiceUpdatedAt?.toIso8601String(),
    'practiceDetailsUpdatedAt':
        scholar.practiceDetailsUpdatedAt?.toIso8601String(),
    'practiceDetailsAvailable': scholar.practiceDetailsAvailable,
    'practiceDetailsStale': scholar.practiceDetailsStale,
    'practiceSummaryStale': scholar.practiceSummaryStale,
    'practiceMyPassed': scholar.practiceMyPassed,
    'practiceLyPassed': scholar.practiceLyPassed,
  };
}
