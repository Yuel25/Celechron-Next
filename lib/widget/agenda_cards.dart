import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';

import '../model/period.dart';
import '../model/task.dart';
import '../utils/utils.dart';
import '../design/round_rectangle_card.dart';

/// 针对进度条填充色的可读性增强函数。
///
/// 亮色模式下白底卡片上较浅颜色（如系统黄）对比度严重不足，通过降低亮度并略提饱和度，
/// 确保在白色背景上的对比度满足 WCAG 图形元素 3:1 要求；暗色模式下暗底上浅色本身可见，保持原色不动。
Color readableBarColor(Color color, Brightness brightness) {
  if (brightness == Brightness.dark) {
    return color;
  }
  final hsl = HSLColor.fromColor(color);
  final targetLightness = hsl.lightness > 0.34 ? 0.34 : hsl.lightness;
  final targetSaturation = (hsl.saturation * 1.05).clamp(0.0, 1.0);
  return hsl
      .withLightness(targetLightness)
      .withSaturation(targetSaturation)
      .toColor();
}

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
    final brightness = CupertinoTheme.of(context).brightness ??
        MediaQuery.platformBrightnessOf(context);
    final resolvedColor = CupertinoDynamicColor.resolve(color, context);
    final fillColor = readableBarColor(resolvedColor, brightness);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: resolvedColor.withValues(alpha: 0.12)),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: t,
                heightFactor: 1.0,
                child: ColoredBox(color: fillColor),
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

/// 方案 A · 浅彩底 + 强调描边的卡片视觉样式。
@visibleForTesting
class FeaturedCardStyle {
  const FeaturedCardStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.accentColor,
  });

  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final Color accentColor;

  Border get border => Border.all(color: borderColor, width: borderWidth);

  factory FeaturedCardStyle.from({
    required Color color,
    required Brightness brightness,
    Color darkBaseColor = CupertinoColors.black,
  }) {
    if (brightness == Brightness.dark) {
      return FeaturedCardStyle(
        backgroundColor: Color.alphaBlend(
          color.withValues(alpha: 0.16),
          darkBaseColor,
        ),
        borderColor: color.withValues(alpha: 0.6),
        borderWidth: 1.0,
        accentColor: color,
      );
    } else {
      final enhanced = readableBarColor(color, Brightness.light);
      return FeaturedCardStyle(
        backgroundColor: Color.alphaBlend(
          color.withValues(alpha: 0.10),
          CupertinoColors.white,
        ),
        borderColor: enhanced,
        borderWidth: 1.5,
        accentColor: enhanced,
      );
    }
  }

  factory FeaturedCardStyle.resolve({
    required Color color,
    required BuildContext context,
  }) {
    final brightness = CupertinoTheme.of(context).brightness ??
        MediaQuery.platformBrightnessOf(context);
    final resolvedColor = CupertinoDynamicColor.resolve(color, context);
    final darkBase = CupertinoDynamicColor.resolve(
      CupertinoColors.systemBackground,
      context,
    );
    return FeaturedCardStyle.from(
      color: resolvedColor,
      brightness: brightness,
      darkBaseColor: darkBase,
    );
  }
}

typedef _FeaturedCardStyle = FeaturedCardStyle;

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
    final featuredStyle = featured
        ? _FeaturedCardStyle.resolve(color: color, context: context)
        : null;
    return RoundRectangleCard(
      onTap: onTap,
      animate: false,
      color: featuredStyle?.backgroundColor,
      border: featuredStyle?.border,
      boxShadow: const [],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${active ? '进行中 · ' : ''}${periodLabel(period.type)}',
            style: TextStyle(
                fontSize: 12,
                color: featuredStyle?.accentColor ?? color,
                fontWeight: FontWeight.w600)),
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
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: featuredStyle?.accentColor ?? color)),
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
  const TaskCardContent({
    super.key,
    required this.task,
    required this.now,
    required this.color,
    required this.onToggle,
    this.onToggleFocus,
    this.isFocusing = false,
  });
  final Task task;
  final DateTime now;
  final Color color;
  final VoidCallback onToggle;
  final VoidCallback? onToggleFocus;
  final bool isFocusing;

  @override
  Widget build(BuildContext context) {
    final completed = task.status == TaskStatus.completed;
    final deadline = task.type == TaskType.deadline;
    final overdue = deadline && !completed && task.endTime.isBefore(now);
    final secondary =
        CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final remaining = task.timeNeeded > task.effectiveTimeSpentAt(now)
        ? task.timeNeeded - task.effectiveTimeSpentAt(now)
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
        if (deadline &&
            (task.status == TaskStatus.running ||
                task.status == TaskStatus.suspended) &&
            onToggleFocus != null) ...[
          const SizedBox(width: 8),
          Semantics(
            label: '${isFocusing ? '暂停专注' : '开始专注'}：${task.summary}',
            button: true,
            toggled: isFocusing,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                final wasFocusing = isFocusing;
                onToggleFocus!();
                final msg = wasFocusing ? '已暂停专注' : '已开始专注';
                final direction =
                    Directionality.maybeOf(context) ?? TextDirection.ltr;
                try {
                  SemanticsService.sendAnnouncement(
                      View.of(context), msg, direction);
                } catch (_) {}
              },
              child: ExcludeSemantics(
                child: Icon(
                  isFocusing
                      ? CupertinoIcons.pause_fill
                      : CupertinoIcons.play_fill,
                  color: isFocusing ? CupertinoColors.systemOrange : color,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
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
            value: '${(task.getProgress(now).clamp(0.0, 1.0) * 100).round()}%',
            child: _ThinProgressBar(
              value: task.getProgress(now),
              color: color,
              height: 4,
            ),
          ),
        ],
      ],
    ]);
  }
}
