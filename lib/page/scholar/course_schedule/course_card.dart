import 'package:celechron/page/scholar/course_detail/course_detail_view.dart';
import 'package:celechron/design/custom_colors.dart';
import 'package:celechron/design/app_visual.dart';
import 'package:flutter/cupertino.dart';

import 'package:celechron/model/session.dart';

class SessionCard extends StatefulWidget {
  final List<Session> sessionList;
  final bool hideInfomation;

  const SessionCard({
    super.key,
    required this.sessionList,
    this.hideInfomation = false,
  });

  @override
  State<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<SessionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.98).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var isDown = false;
    var isCancel = false;

    String sessionName = "";
    String sessionLocation = "";
    String sessionTeacher = "";
    final hasConflict = widget.sessionList.length > 1;
    if (!widget.hideInfomation) {
      if (!hasConflict) {
        sessionName = widget.sessionList[0].name;
        sessionLocation = widget.sessionList[0].location ?? '未知地点';
        sessionTeacher = widget.sessionList[0].teacher;
      } else {
        sessionName = '课程冲突';
        sessionLocation = '${widget.sessionList.length} 门课程重叠';
      }
    }

    final brightness = CupertinoTheme.of(context).brightness ??
        MediaQuery.platformBrightnessOf(context);
    final accent = CupertinoDynamicColor.resolve(
      hasConflict
          ? AppSemanticColors.danger
          : UidColors.colorFromUid(
              widget.sessionList.first.id ?? widget.sessionList.first.name,
            ),
      context,
    );

    return GestureDetector(
      onTapDown: (_) async {
        isDown = true;
        isCancel = false;
        _animationController.forward();
        await Future.delayed(const Duration(milliseconds: 125));
        isDown = false;
        if (isCancel) {
          _animationController.reverse();
          isCancel = false;
        }
      },
      onTapUp: (_) async {
        isCancel = true;
        if (!isDown) _animationController.reverse();
      },
      onTapCancel: () => _animationController.reverse(),
      onTap: () async {
        if (widget.sessionList.length == 1) {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) =>
                  CourseDetailPage(courseId: widget.sessionList[0].id),
              title: widget.sessionList[0].name,
            ),
          );
        } else {
          await showCupertinoDialog(
            context: context,
            builder: (BuildContext context) {
              return CupertinoAlertDialog(
                title: const Text(
                  '要查看哪一个？',
                ),
                content: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var s in widget.sessionList)
                      CupertinoButton(
                        minimumSize: const Size(22.0, 22.0),
                        padding:
                            const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
                        child: Text(
                          s.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) =>
                                  CourseDetailPage(courseId: s.id),
                              title: s.name,
                            ),
                          );
                        },
                      ),
                  ],
                ),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('返回'),
                    onPressed: () async {
                      Navigator.of(context).pop();
                    },
                  )
                ],
              );
            },
          );
        }
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.only(
            top: 1.5,
            bottom: 1.5,
            left: 1.5,
            right: 1.5,
          ),
          child: Container(
            alignment: Alignment.topCenter,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppVisual.controlRadius),
              color: accent.withValues(
                alpha: brightness == Brightness.dark ? 0.2 : 0.12,
              ),
              border: Border(
                left: BorderSide(color: accent, width: 3),
                top: hasConflict
                    ? BorderSide(color: accent.withValues(alpha: 0.55))
                    : BorderSide.none,
                right: hasConflict
                    ? BorderSide(color: accent.withValues(alpha: 0.55))
                    : BorderSide.none,
                bottom: hasConflict
                    ? BorderSide(color: accent.withValues(alpha: 0.55))
                    : BorderSide.none,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppVisual.controlRadius - 1),
              child: LayoutBuilder(
                builder: (context, constraints) => Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 3, 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasConflict)
                        Icon(
                          CupertinoIcons.exclamationmark_triangle_fill,
                          color: accent,
                          size: 11,
                        ),
                      Flexible(
                        child: Text(
                          sessionName,
                          maxLines: constraints.maxHeight > 72 ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: CupertinoTheme.of(context)
                              .textTheme
                              .textStyle
                              .copyWith(
                                fontSize: 10,
                                height: 1.12,
                                fontWeight: FontWeight.w700,
                                color: CupertinoDynamicColor.resolve(
                                  CupertinoColors.label,
                                  context,
                                ),
                              ),
                        ),
                      ),
                      if (!widget.hideInfomation &&
                          sessionLocation.isNotEmpty &&
                          constraints.maxHeight > 42) ...[
                        const SizedBox(height: 2),
                        Text(
                          sessionLocation,
                          maxLines: constraints.maxHeight > 85 ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            height: 1.1,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      ],
                      if (!widget.hideInfomation &&
                          !hasConflict &&
                          sessionTeacher.isNotEmpty &&
                          constraints.maxHeight > 92) ...[
                        const SizedBox(height: 2),
                        Text(
                          sessionTeacher,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 8.5,
                            color: CupertinoColors.tertiaryLabel,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
