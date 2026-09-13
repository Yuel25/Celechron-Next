import 'dart:async';
import 'package:get/get.dart';
import 'package:celechron/database/database_helper.dart';
import 'package:celechron/model/task.dart';
import 'package:celechron/model/period.dart';
import 'package:celechron/model/scholar.dart';
import 'package:celechron/services/diagnostic_log_service.dart';

class FlowController extends GetxController {
  FlowController({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final scholar = Get.find<Rx<Scholar>>(tag: 'scholar');
  final flowList = Get.find<RxList<Period>>(tag: 'flowList');
  final flowListLastUpdate = Get.find<Rx<DateTime>>(tag: 'flowListLastUpdate');
  final taskList = Get.find<RxList<Task>>(tag: 'taskList');
  final taskListLastUpdate = Get.find<Rx<DateTime>>(tag: 'taskListLastUpdate');
  final _db = Get.find<DatabaseHelper>(tag: 'db');
  late var _scholarFlowList = scholar.value.periods;
  var _currentScholarFlowCursor = -1;
  late final timeNow = _now().obs;
  Timer? _timer;
  Worker? _scholarWorker;
  Worker? _taskWorker;
  // 数据变化时置位，下一秒执行完整 walk；平时按 _nextWalkAt 的时间边界调度
  bool _walkPending = false;
  DateTime _nextWalkAt = DateTime.fromMillisecondsSinceEpoch(0);
  int? _lastFlowSig;

  bool get isDuringFlow =>
      flowList.isNotEmpty && flowList.first.startTime.isBefore(_now());

  @override
  void onInit() {
    // 把基本事项给排序好，看目前在上哪节课（和排序有关系）
    refreshScholarFlowList();
    // 按表走，把应用关闭期间的事务项清理掉
    walkFlowList();

    // 每秒只更新时钟；昂贵的完整 walk 只在数据变化或时间边界时执行
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _onTick());

    // 当“学业”页面有更新（例如出现新课程），更新基本Flow列表
    _scholarWorker = ever(scholar, (callback) {
      refreshScholarFlowList();
      _walkPending = true;
    });
    _taskWorker = ever(taskList, (_) => _walkPending = true);

    super.onInit();
  }

  void _onTick() {
    final now = _now();
    timeNow.value = now;
    if (_walkPending || !now.isBefore(_nextWalkAt)) {
      _walkPending = false;
      walkFlowList();
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    _scholarWorker?.dispose();
    _taskWorker?.dispose();
    super.onClose();
  }

  Future<void> saveFlowListToDb() async {
    try {
      await _db.saveTaskFlowSnapshot(
        tasks: taskList,
        flows: flowList,
        taskUpdatedAt: taskListLastUpdate.value,
        flowUpdatedAt: flowListLastUpdate.value,
      );
    } on Object catch (error, stackTrace) {
      _lastFlowSig = null;
      _walkPending = true;
      DiagnosticLogService.instance.record(
        level: CelechronLogLevel.error,
        module: 'storage',
        operation: 'saveTaskFlowSnapshot',
        message: '任务与时间线快照保存失败，将重试',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void loadFlowListLastUpdate() {
    flowListLastUpdate.value = _db.getFlowListUpdateTime();
  }

  // 根据安排走，已完成的就剔除
  void walkFlowList() {
    // 清理存量快照里的历史“专注/空闲”时段
    flowList.removeWhere(
        (e) => e.type == PeriodType.flow || e.type == PeriodType.virtual);

    // 移除所有固定日程、课程与考试，重新按当前时间计算并添加
    flowList.removeWhere((e) =>
        e.type == PeriodType.user ||
        e.type == PeriodType.classes ||
        e.type == PeriodType.test);

    /* 重新添加最近48h内的至多5节课程（防止Flow页面太乱）*/
    _refreshScholarCursor();
    if (_currentScholarFlowCursor != -1) {
      for (var i = 0;
          i < 6 && i + _currentScholarFlowCursor < _scholarFlowList.length;
          i++) {
        // 防止重复添加
        if (!flowList.any((e) =>
                e.uid == _scholarFlowList[i + _currentScholarFlowCursor].uid) &&
            _scholarFlowList[i + _currentScholarFlowCursor]
                    .endTime
                    .difference(_now())
                    .inMinutes <
                2880) {
          flowList
              .add(_scholarFlowList[i + _currentScholarFlowCursor].copyWith());
        }
      }
    }

    /* 每个固定日程添加至多5项 */
    for (var x in taskList) {
      if (x.type == TaskType.fixed) {
        DateTime time = _now();
        DateTime? last;
        for (int i = 0; i < 5; i++) {
          Period? period = x.deadlineOfTime(time, predicting: true);
          if (period != null) {
            if (last == null || last.compareTo(period.startTime) != 0) {
              flowList.add(period);
              last = period.startTime.copyWith();
            }
          }
          time = time.add(const Duration(days: 1));
        }
      }
    }
    flowList.sort((a, b) {
      return a.startTime.compareTo(b.startTime);
    });

    // 内容没变就不写库
    final sig = _computeFlowSig();
    if (sig != _lastFlowSig) {
      _lastFlowSig = sig;
      saveFlowListToDb();
    }
    _nextWalkAt = _computeNextWalkAt(_now());
  }

  int _computeFlowSig() {
    return Object.hashAll(flowList.map((p) => Object.hash(p.uid, p.type,
        p.startTime, p.endTime, p.summary, p.location, p.description)));
  }

  DateTime _computeNextWalkAt(DateTime now) {
    // 60 秒自愈上限：即使漏枚举了某个边界，最迟一分钟后也会有一次完整 walk
    var next = now.add(const Duration(seconds: 60));
    void consider(DateTime t) {
      if (t.isAfter(now) && t.isBefore(next)) next = t;
    }

    for (var p in flowList) {
      consider(p.startTime);
      consider(p.endTime);
    }
    if (_currentScholarFlowCursor != -1) {
      for (var i = 0;
          i < 6 && i + _currentScholarFlowCursor < _scholarFlowList.length;
          i++) {
        var p = _scholarFlowList[i + _currentScholarFlowCursor];
        consider(p.endTime);
        // 距结束 2880 分钟（48 小时）的展示门槛也是一个边界
        consider(p.endTime.subtract(const Duration(minutes: 2880)));
      }
    }
    return next;
  }

  void refreshScholarFlowList() {
    _scholarFlowList = scholar.value.periods;
    _scholarFlowList.sort((a, b) {
      return a.startTime.compareTo(b.startTime);
    });
    _refreshScholarCursor();
  }

  void _refreshScholarCursor() {
    _currentScholarFlowCursor =
        _scholarFlowList.indexWhere((e) => e.endTime.isAfter(_now()));
  }
}
