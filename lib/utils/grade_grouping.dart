import 'package:flutter/foundation.dart';

import 'package:celechron/model/grade.dart';

/// 成绩按课程号归类：体育课用班级编号，其余用课程号，并套用用户自定义映射。
String gradeGroupKey(String gradeId, Map<String, String> courseIdMappingMap) {
  final matchClass = RegExp(r'(\(.*\)-(.*?))-.*').firstMatch(gradeId);
  if (matchClass == null && gradeId.length < 22) {
    throw const FormatException('成绩课程编号长度不足');
  }
  var key = matchClass?.group(2) ?? gradeId.substring(14, 22);
  if (key.startsWith('PPAE') || key.startsWith('401')) {
    key = matchClass?.group(1) ?? gradeId.substring(0, 22);
  }
  return courseIdMappingMap[key] ?? key;
}

/// 按 [gradeGroupKey] 归类；单条无法归类的成绩跳过，不中断整体。
Map<String, List<Grade>> groupGradesByCourseKey(
  Iterable<Grade> grades,
  Map<String, String> courseIdMappingMap,
) {
  final grouped = <String, List<Grade>>{};
  for (final grade in grades) {
    try {
      final key = gradeGroupKey(grade.id, courseIdMappingMap);
      grouped.putIfAbsent(key, () => <Grade>[]).add(grade);
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
            '跳过无法归类的成绩 ${grade.id}：${error.runtimeType}: $error\n$stackTrace');
      }
    }
  }
  return grouped;
}
