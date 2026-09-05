import 'dart:async';

import 'package:flutter/cupertino.dart';
import '../../design/app_visual.dart';
import '../../utils/utils.dart';

class PlanningSheet extends StatefulWidget {
  const PlanningSheet(
      {super.key,
      required this.workTime,
      required this.restTime,
      required this.availableTimes,
      required this.onGenerate,
      this.now});
  final Duration workTime;
  final Duration restTime;
  final String availableTimes;
  final FutureOr<int> Function(DateTime start) onGenerate;
  final DateTime Function()? now;

  @override
  State<PlanningSheet> createState() => _PlanningSheetState();
}

class _PlanningSheetState extends State<PlanningSheet> {
  late DateTime _start;
  bool _busy = false;
  String? _error;
  int? _result;
  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _start = _now
        .add(const Duration(minutes: 2))
        .copyWith(second: 0, millisecond: 0, microsecond: 0);
  }

  Future<void> _generate() async {
    if (_busy) return;
    if (!_start.isAfter(_now)) {
      setState(() => _error = '开始时间已过去，请选择一个稍后的时间。');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.onGenerate(_start);
      if (!mounted) return;
      setState(() {
        if (result < 0) {
          _error = '可用时间不足。请提前开始，或减少任务预计用时后再试。现有安排已保留。';
        } else {
          _result = result;
        }
      });
    } on Object {
      if (mounted) setState(() => _error = '暂时无法完成规划，请稍后重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondary =
        CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Expanded(
                      child: Text('安排专注时间',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w600))),
                  CupertinoButton(
                      padding: const EdgeInsets.all(10),
                      onPressed:
                          _busy ? null : () => Navigator.of(context).pop(),
                      child: const Icon(CupertinoIcons.xmark,
                          semanticLabel: '关闭规划')),
                ]),
                Flexible(
                    child: SingleChildScrollView(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                      Text('根据待办任务和已有日程，安排合适的专注时段。',
                          style: TextStyle(fontSize: 14, color: secondary)),
                      const SizedBox(height: 20),
                      Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: CupertinoDynamicColor.resolve(
                                  AppVisual.brandSoft, context),
                              borderRadius: BorderRadius.circular(14)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '专注 ${durationToString(widget.workTime)} · 休息 ${durationToString(widget.restTime)}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Text('可用时段：${widget.availableTimes}',
                                    style: TextStyle(
                                        fontSize: 13, color: secondary)),
                                const SizedBox(height: 6),
                                Text('可在「设置 → 时间规划」调整。',
                                    style: TextStyle(
                                        fontSize: 13, color: secondary)),
                              ])),
                      const SizedBox(height: 20),
                      if (_result == null) ...[
                        const Text('开始时间',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        SizedBox(
                            height: 190,
                            child: IgnorePointer(
                                ignoring: _busy,
                                child: CupertinoDatePicker(
                                    initialDateTime: _start,
                                    use24hFormat: true,
                                    mode: CupertinoDatePickerMode.dateAndTime,
                                    onDateTimeChanged: (value) => setState(() {
                                          _start = value;
                                          _error = null;
                                        })))),
                      ],
                      if (_result != null)
                        Semantics(
                            liveRegion: true,
                            child: Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('规划已生成',
                                          style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 8),
                                      Text(
                                          _result == widget.restTime.inMinutes
                                              ? '专注时段已添加到「接下来」。'
                                              : '为完成全部任务，本次休息缩短为 ${durationToString(Duration(minutes: _result!))}。原来的休息设置保持不变。',
                                          style: TextStyle(
                                              fontSize: 14, color: secondary)),
                                    ]))),
                    ]))),
                if (_error != null)
                  Semantics(
                      liveRegion: true,
                      child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(_error!,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: CupertinoDynamicColor.resolve(
                                      CupertinoColors.systemRed, context))))),
                const SizedBox(height: 12),
                CupertinoButton.filled(
                    onPressed: _busy
                        ? null
                        : _result == null
                            ? _generate
                            : () => Navigator.of(context).pop(),
                    child: _busy
                        ? const CupertinoActivityIndicator()
                        : Text(_result == null ? '生成规划' : '查看安排')),
              ]),
        ));
  }
}
