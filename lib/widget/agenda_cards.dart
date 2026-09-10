import 'package:flutter/cupertino.dart';

import '../model/period.dart';
import '../model/task.dart';
import '../utils/utils.dart';
import '../design/app_visual.dart';
import '../design/round_rectangle_card.dart';

/// 纯 Cupertino 细进度条，避免依赖 Material 的 LinearProgressIndicator。
class _ThinProgressBar extends StatelessWidget {
  const _ThinProgressBar({
    required this.value,
    required this.color,
    this.height = 4,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: color.withValues(alpha: 0.12)),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: t,
                child: ColoredBox(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String agendaTime(DateTime value, DateTime now) {
  final date = DateTime(value.year, value.month, value.day);
  final today = DateTime(now.year, now.month, now.day);
  final label = date == today
      ? '今天'
      : date == DateTime(now.year, now.month, now.day + 1)
          ? '明天'
          : value.year == now.year
              ? '${value.month}月${value.day}日'
              : '${value.year}年${value.month}月${value.day}日';
  return '$label ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

String periodLabel(PeriodType type) => switch (type) {
      PeriodType.classes => '课程',
      PeriodType.test => '考试',
      PeriodType.user => '日程',
      PeriodType.flow => '专注',
      PeriodType.virtual => '空闲',
    };

class AgendaPeriodCard extends StatelessWidget {
  const AgendaPeriodCard(
      {super.key,
      required this.period,
      required this.now,
      required this.color,
      this.featured = false,
      this.onTap});
  final Period period;
  final DateTime now;
  final Color color;
  final bool featured;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active =
        !now.isBefore(period.startTime) && now.isBefore(period.endTime);
    final ended = !now.isBefore(period.endTime);
    final remaining =
        (active ? period.endTime : period.startTime).difference(now);
    final minutes = (remaining.inSeconds / 60).ceil().clamp(0, 999999);
    final countdown = minutes < 60
        ? '$minutes 分钟'
        : '${minutes ~/ 60} 小时${minutes % 60 == 0 ? '' : ' ${minutes % 60} 分钟'}';
    final length = period.endTime.difference(period.startTime).inMilliseconds;
    final progress = length <= 0
        ? 0.0
        : (now.difference(period.startTime).inMilliseconds / length)
            .clamp(0.0, 1.0);
    final secondary =
        CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    return RoundRectangleCard(
      onTap: onTap,
      animate: false,
      color: featured
          ? CupertinoDynamicColor.resolve(AppVisual.brandSoft, context)
          : null,
      border:
          featured ? Border.all(color: color.withValues(alpha: 0.22)) : null,
      boxShadow: const [],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${active ? '进行中 · ' : ''}${periodLabel(period.type)}',
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(period.summary,
            maxLines: featured ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: featured ? 24 : 17,
                color: CupertinoDynamicColor.resolve(
                    CupertinoColors.label, context),
                fontWeight: FontWeight.w600,
                height: 1.3)),
        const SizedBox(height: 8),
        Text(
            '${agendaTime(period.startTime, now)} — ${period.startTime.year == period.endTime.year && period.startTime.month == period.endTime.month && period.startTime.day == period.endTime.day ? '${period.endTime.hour.toString().padLeft(2, '0')}:${period.endTime.minute.toString().padLeft(2, '0')}' : agendaTime(period.endTime, now)}',
            style: TextStyle(fontSize: 14, color: secondary)),
        if (period.location.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(CupertinoIcons.location, size: 16, color: secondary),
            const SizedBox(width: 6),
            Expanded(
                child: Text(period.location,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: secondary))),
          ]),
        ],
        if (featured) ...[
          const SizedBox(height: 20),
          Text(
              ended
                  ? '已结束'
                  : active
                      ? '还剩 $countdown'
                      : '$countdown后开始',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600, color: color)),
          if (active) ...[
            const SizedBox(height: 12),
            Semantics(
              label: '当前事项进度',
              value: '${(progress * 100).round()}%',
              child: _ThinProgressBar(value: progress, color: color, height: 5),
            ),
          ],
        ],
      ]),
    );
  }
}

class TaskCardContent extends StatelessWidget {
  const TaskCardContent(
      {super.key,
      required this.task,
      required this.now,
      required this.color,
      required this.onToggle});
  final Task task;
  final DateTime now;
  final Color color;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final completed = task.status == TaskStatus.completed;
    final deadline = task.type == TaskType.deadline;
    final overdue = deadline && !completed && task.endTime.isBefore(now);
    final secondary =
        CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final remaining = task.timeNeeded > task.timeSpent
        ? task.timeNeeded - task.timeSpent
        : Duration.zero;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (deadline) ...[
          Semantics(
              label: '${completed ? '标记未完成' : '完成任务'}：${task.summary}',
              button: true,
              checked: completed,
              child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onToggle,
                  child: ExcludeSemantics(
                      child: Icon(
                          completed
                              ? CupertinoIcons.check_mark_circled_solid
                              : CupertinoIcons.circle,
                          color:
                              completed ? CupertinoColors.systemGreen : color,
                          size: 26)))),
          const SizedBox(width: 8),
        ],
        Expanded(
            child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(task.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: completed
                            ? secondary
                            : CupertinoDynamicColor.resolve(
                                CupertinoColors.label, context),
                        decoration:
                            completed ? TextDecoration.lineThrough : null)))),
      ]),
      const SizedBox(height: 8),
      Text(
          deadline
              ? '${agendaTime(task.endTime, now)} 截止${overdue ? ' · 已过期' : ''}'
              : '${agendaTime(task.startTime, now)} 开始',
          style: TextStyle(
              fontSize: 14,
              color: overdue
                  ? CupertinoDynamicColor.resolve(
                      CupertinoColors.systemRed, context)
                  : secondary)),
      if (!deadline) ...[
        const SizedBox(height: 4),
        Text('${agendaTime(task.endTime, now)} 结束',
            style: TextStyle(fontSize: 14, color: secondary)),
      ],
      if (task.location.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(task.location,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: secondary)),
      ],
      if (deadline) ...[
        const SizedBox(height: 12),
        Text(
            completed
                ? '已完成'
                : '${task.status == TaskStatus.suspended ? '已暂停 · ' : ''}还需 ${durationToString(remaining)}',
            style: TextStyle(fontSize: 13, color: secondary)),
        if (!completed) ...[
          const SizedBox(height: 8),
          Semantics(
            label: '任务完成进度',
            value: '${(task.getProgress().clamp(0.0, 1.0) * 100).round()}%',
            child: _ThinProgressBar(
              value: task.getProgress(),
              color: color,
              height: 4,
            ),
          ),
        ],
      ],
    ]);
  }
}
