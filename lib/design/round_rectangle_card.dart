import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:celechron/design/app_visual.dart';

class RoundRectangleCard extends StatefulWidget {
  final Widget child;
  final Function()? onTap;
  final bool animate;
  final List<BoxShadow> boxShadow;
  final EdgeInsets padding;
  final Color? color;
  final Border? border;
  final double borderRadius;

  const RoundRectangleCard({
    super.key,
    required this.child,
    this.onTap,
    this.animate = true,
    this.padding = const EdgeInsets.all(AppVisual.cardPadding),
    this.color,
    this.border,
    this.borderRadius = AppVisual.cardRadius,
    this.boxShadow = AppVisual.surfaceShadow,
  });

  @override
  State<RoundRectangleCard> createState() => _RoundRectangleCardState();
}

class _RoundRectangleCardState extends State<RoundRectangleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
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
  }

  @override
  void dispose() {
    if (widget.animate) {
      _animationController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ??
        MediaQuery.of(context).platformBrightness;
    var isDown = false;
    var isCancel = false;
    var core = Container(
        padding: widget.padding,
        // decoration: BoxDecoration(
        //     borderRadius: BorderRadius.circular(12),
        //     // In light mode, color is white; in dark mode, color is black
        //     color: SchedulerBinding
        //                 .instance.platformDispatcher.platformBrightness ==
        //             Brightness.dark
        //         ? CupertinoDynamicColor.resolve(
        //             CupertinoColors.secondarySystemBackground, context)
        //         : CupertinoDynamicColor.resolve(CupertinoColors.white, context),
        //     boxShadow: SchedulerBinding
        //                 .instance.platformDispatcher.platformBrightness ==
        //             Brightness.dark
        //         ? null
        //         : widget.boxShadow),
        // 修改了颜色控制逻辑，应该跟随应用设置而非系统设置
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: widget.border,
          boxShadow: brightness == Brightness.dark ? null : widget.boxShadow,
          color: widget.color == null
              ? brightness == Brightness.dark
                  ? CupertinoDynamicColor.resolve(
                      CupertinoColors.secondarySystemBackground, context)
                  : CupertinoDynamicColor.resolve(
                      CupertinoColors.white, context)
              : CupertinoDynamicColor.resolve(widget.color!, context),
        ),
        child: widget.child);
    return widget.animate
        ? GestureDetector(
            onTapDown: (_) async {
              isDown = true;
              isCancel = false;
              _animationController.forward();
              await Future.delayed(const Duration(milliseconds: 125));
              isDown = false;
              if (isCancel) {
                if (widget.onTap != null) {
                  widget.onTap?.call();
                }
                _animationController.reverse();
                isCancel = false;
              }
            },
            onTapUp: (_) async {
              isCancel = true;
              if (!isDown) _animationController.reverse();
            },
            onTapCancel: () async => _animationController.reverse(),
            child: ScaleTransition(scale: _scaleAnimation, child: core),
          )
        : GestureDetector(onTap: widget.onTap, child: core);
  }
}

class RoundRectangleCardWithForehead extends StatelessWidget {
  final Widget child;
  final Widget forehead;
  final Color foreheadColor;
  final Function()? onTap;
  final bool animate;

  const RoundRectangleCardWithForehead({
    super.key,
    required this.child,
    required this.forehead,
    this.foreheadColor = CupertinoColors.systemFill,
    this.onTap,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
            child: SizedBox(
                child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppVisual.cardRadius),
            color: CupertinoDynamicColor.resolve(foreheadColor, context),
            boxShadow: const [],
          ),
        ))),
        SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              forehead,
              RoundRectangleCard(
                onTap: onTap,
                animate: animate,
                boxShadow: const [],
                child: child,
              ),
            ],
          ),
        )
      ],
    );
  }
}
