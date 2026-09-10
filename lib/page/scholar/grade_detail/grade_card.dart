import 'dart:math';

import 'package:celechron/design/app_visual.dart';
import 'package:celechron/page/scholar/grade_detail/grade_detail_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'package:celechron/model/grade.dart';
import 'package:celechron/page/scholar/course_detail/course_detail_view.dart';

class GradeCard extends StatefulWidget {
  final Grade grade;
  final CupertinoDynamicColor backgroundColor;

  const GradeCard({
    super.key,
    required this.grade,
    this.backgroundColor = CupertinoColors.systemBackground,
  });

  @override
  State<GradeCard> createState() => _GradeCardState();
}

class _GradeCardState extends State<GradeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final _gradeDetailController = Get.find<GradeDetailController>();
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.95).animate(
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

  bool isHighlighted() {
    return !_gradeDetailController.customGpaMode.value ||
        (_gradeDetailController.customGpaSelected[widget.grade.id] ?? false);
  }

  void _handleTapDown(TapDownDetails _) {
    _isPressed = true;
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    if (_isPressed) {
      _isPressed = false;
      _animationController.reverse();
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      _isPressed = false;
      _animationController.reverse();
    }
  }

  void _handleTap() {
    if (_gradeDetailController.customGpaMode.value) {
      var cur =
          _gradeDetailController.customGpaSelected[widget.grade.id] ?? false;
      _gradeDetailController.customGpaSelected[widget.grade.id] = !cur;
    } else {
      navigator!.push(CupertinoPageRoute(
          builder: (context) => CourseDetailPage(courseId: widget.grade.id)));
    }
  }

  void _handleLongPress() {
    navigator!.push(CupertinoPageRoute(
        builder: (context) => CourseDetailPage(courseId: widget.grade.id)));
  }

  @override
  Widget build(BuildContext context) {
    var brightness = CupertinoTheme.of(context).brightness ??
        MediaQuery.of(context).platformBrightness;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      onLongPress: _handleLongPress,
      child: Obx(
        () => ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding:
                const EdgeInsets.only(left: 12, right: 12, bottom: 8, top: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppVisual.cardRadius),
              color: brightness == Brightness.dark
                  ? CupertinoColors.systemFill
                  : CupertinoDynamicColor.resolve(
                      widget.backgroundColor, context),
              boxShadow: AppVisual.shadowFor(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_gradeDetailController.customGpaMode.value)
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        child: SizedBox(
                          height: 32.0,
                          width: 32.0,
                          child: CupertinoCheckbox(
                            value: _gradeDetailController
                                    .customGpaSelected[widget.grade.id] ??
                                false,
                            onChanged: (bool? value) {
                              if (value != null) {
                                _gradeDetailController
                                    .customGpaSelected[widget.grade.id] = value;
                                _gradeDetailController.refreshCustomGpa();
                              }
                            },
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.grade.name,
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.normal,
                                  color: CupertinoTheme.of(context)
                                      .textTheme
                                      .textStyle
                                      .color!
                                      .withValues(
                                          alpha: isHighlighted() ? 1.0 : 0.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                          ),
                          Text(
                            '${widget.grade.realId} / ${widget.grade.credit.toStringAsFixed(1)} 学分',
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(
                                  color: CupertinoTheme.of(context)
                                      .textTheme
                                      .textStyle
                                      .color!
                                      .withValues(alpha: 0.5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.normal,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${widget.grade.original} / ${widget.grade.fivePoint.toStringAsFixed(1)}',
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.normal,
                            color: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .color!
                                .withValues(alpha: isHighlighted() ? 1.0 : 0.5),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 8,
                  width: max(
                      (context.width - 60) *
                          (widget.grade.fivePoint - 1.4) /
                          3.6,
                      0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoDynamicColor.resolve(
                          isHighlighted()
                              ? CupertinoColors.systemTeal
                              : CupertinoColors.systemGrey,
                          context),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
