part of 'scholar.dart';

/// Scholar 的登录 / 刷新编排：持有 Spider 会话，把抓取结果合并回 [Scholar]。
class ScholarSyncService {
  ScholarSyncService(this._scholar);

  final Scholar _scholar;
  Spider? _spider;

  void disposeSession() {
    _spider?.logout();
    _spider = null;
  }

  Future<List<String?>> login({
    RefreshOrigin origin = RefreshOrigin.foreground,
  }) {
    return DiagnosticLogService.instance.runRefresh(
      origin: origin,
      action: () => RefreshCoordinator.run(
        account: _scholar.username ?? '<unknown>',
        operation: 'login',
        origin: origin,
        refreshId: DiagnosticLogService.instance.currentRefreshId ?? 'unknown',
        action: _loginInternal,
      ),
    );
  }

  Future<List<String?>> refresh({
    RefreshOrigin origin = RefreshOrigin.foreground,
    void Function()? onPartialUpdate,
    void Function(List<ModuleFetchStatus> statuses)? onFetchStatus,
    void Function()? onBackgroundYield,
  }) async {
    return DiagnosticLogService.instance.runRefresh(
      origin: origin,
      action: () => RefreshCoordinator.run(
        account: _scholar.username ?? '<unknown>',
        operation: 'refresh',
        origin: origin,
        refreshId: DiagnosticLogService.instance.currentRefreshId ?? 'unknown',
        action: () async {
          // 从数据库恢复的 Scholar 只有缓存的登录标记，没有可持久化的 Spider
          // 会话。把会话重建纳入完整刷新，启动自动刷新与手动刷新才能共享
          // 同一个 refresh Future。
          if (!_scholar.isLogan || _spider == null) {
            final loginErrors = await _loginInternal();
            if (loginErrors.any((error) => error != null)) {
              return loginErrors;
            }
          }
          // Workmanager 可能略早于前台 main isolate 启动。后台完成登录后
          // 再检查一次前台租约，避免继续发起整套模块抓取并长期占锁。
          if (origin == RefreshOrigin.background &&
              await RefreshCoordinator.shouldYieldBackground()) {
            DiagnosticLogService.instance.record(
              module: 'refresh',
              operation: 'backgroundYield',
              message: '后台刷新登录完成后检测到活跃前台，已正常让行',
            );
            onBackgroundYield?.call();
            return <String?>[];
          }
          return _refreshInternal(
            onPartialUpdate: onPartialUpdate,
            onFetchStatus: onFetchStatus,
          );
        },
        backgroundYieldResult: () {
          onBackgroundYield?.call();
          return <String?>[];
        },
      ),
    );
  }

  Future<List<String?>> _loginInternal() async {
    final scholar = _scholar;
    final username = scholar.username;
    final password = scholar.password;
    if (username == null || password == null) {
      return ["未登录"];
    }
    if (username == '3200000000') {
      _spider = MockSpider();
    } else if (!scholar.isGrs) {
      _spider = UgrsSpider(username, password);
    } else {
      _spider = GrsSpider(username, password);
    }
    _spider!.db = scholar.db;
    var loginErrorMessage = await _spider!.login();
    if (loginErrorMessage.every((e) => e == null)) {
      scholar.isLogan = true;
      scholar.db?.setScholar(scholar);
    }
    return loginErrorMessage;
  }

  Future<List<String?>> _refreshInternal({
    void Function()? onPartialUpdate,
    void Function(List<ModuleFetchStatus> statuses)? onFetchStatus,
  }) async {
    final scholar = _scholar;
    final db = scholar.db;
    if (!scholar.isLogan) {
      return ["未登录"];
    }
    try {
      // 异步刷新：每完成一部分抓取就先合并进内存并通知界面，
      // 全部完成后仍会走下面的完整合并（含实践学分、时间戳、持久化与报错）
      var useAsyncRefresh =
          onPartialUpdate != null && (db?.getAsyncRefresh() ?? false);
      // 刷新状态文案：与数据合并解耦，只要有人监听就照常上报各模块进度，
      // 不受异步刷新开关影响；后台刷新两个回调都不传，行为与原来完全一致
      var fetchLabels = _spider?.fetchLabels ?? const <String>[];
      void emitStatuses(List<String?> fetchErrors) {
        if (onFetchStatus == null || fetchLabels.isEmpty) return;
        try {
          var statuses = moduleStatusesFromErrors(fetchErrors, fetchLabels);
          if (statuses.isNotEmpty) onFetchStatus(statuses);
        } catch (error, stackTrace) {
          DiagnosticLogService.instance.record(
            level: CelechronLogLevel.warning,
            module: 'refresh',
            operation: 'fetchStatus',
            message: '刷新状态上报失败',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      // 起始状态：全部「进行中」（覆盖登录阶段，此时尚无任何任务完成回调）
      if (onFetchStatus != null && fetchLabels.isNotEmpty) {
        onFetchStatus([
          for (var label in fetchLabels)
            ModuleFetchStatus(label, FetchModuleState.pending)
        ]);
      }
      var wantProgress = useAsyncRefresh || onFetchStatus != null;
      return await _spider
              ?.getEverything(
                  onProgress: wantProgress
                      ? (partial) {
                          if (useAsyncRefresh) {
                            try {
                              _applyFetchResult(partial, partial: true);
                              // 已成功板块立即打上“更新于”时间戳；
                              // 未完成/失败的板块被 updateLastUpdateTime 的
                              // 关键字守卫（“查询进行中”/“查询出错”）拦下
                              if (partial.loginErrors.every((e) => e == null)) {
                                scholar
                                    .updateLastUpdateTime(partial.fetchErrors);
                              }
                              onPartialUpdate();
                            } catch (error, stackTrace) {
                              DiagnosticLogService.instance.record(
                                level: CelechronLogLevel.warning,
                                module: 'refresh',
                                operation: 'partialMerge',
                                message: '异步刷新中间态合并失败',
                                error: error,
                                stackTrace: stackTrace,
                              );
                            }
                          }
                          emitStatuses(partial.fetchErrors);
                        }
                      : null)
              .then((value) async {
            for (var e in value.loginErrors) {
              if (e != null) {
                DiagnosticLogService.instance.record(
                  level: CelechronLogLevel.warning,
                  module: '登录',
                  operation: 'result',
                  message: e,
                );
              }
            }
            for (var e in value.fetchErrors) {
              if (e != null) {
                DiagnosticLogService.instance.record(
                  level: isDegradedRefreshText(e)
                      ? CelechronLogLevel.warning
                      : CelechronLogLevel.error,
                  module: '刷新聚合',
                  operation: 'moduleResult',
                  message: e,
                );
              }
            }
            if (value.loginErrors.every((e) => e == null)) {
              scholar.updateLastUpdateTime(value.fetchErrors);
            }
            _applyFetchResult(value);

            // 终态补发：最后完成的模块不会触发 onProgress，只能在这里定论
            emitStatuses(value.fetchErrors);

            await db?.setScholar(scholar);
            return value.fetchErrors;
          }) ??
          ['未登录'];
    } on Object catch (error, stackTrace) {
      // 网络异常等情况下保留已有数据，不清空
      final exception = exceptionFrom(
        error,
        context: '刷新聚合',
        stackTrace: stackTrace,
      );
      return [exception.toString()];
    }
  }

  // 把一次抓取结果合并进当前对象。partial 为 true 表示异步刷新的中间态：
  // 空数据、有报错或尚未抓完的部分会被 setScholar 的守卫拦下，保留原值；
  // 实践学分成功与否要等全部抓完才能判定，中间态一律保持不变。
  void _applyFetchResult(EverythingResult value, {bool partial = false}) {
    final scholar = _scholar;
    final courseIdMappingMap = {
      for (final mapping in Get.find<OptionController>(tag: 'optionController')
          .courseIdMappingList)
        mapping.id1: mapping.id2
    };
    final tempGrades = groupGradesByCourseKey(value.grades, courseIdMappingMap);

    PracticeScoreSnapshot? tempPracticeSnapshot;
    if (!partial && _spider is UgrsSpider && !scholar.isGrs) {
      tempPracticeSnapshot = (_spider as UgrsSpider).practiceSnapshot;
    }

    scholar.setScholar(value.fetchErrors, value.semesters, tempGrades,
        value.specialDates, value.todos, tempPracticeSnapshot);

    scholar.recomputeGpaFromGrades();
  }
}
