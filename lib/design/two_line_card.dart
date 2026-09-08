import 'package:flutter/cupertino.dart';

import 'package:celechron/design/app_visual.dart';

class TwoLineCard extends StatefulWidget {
  final String title;
  final String content;
  final String? extraContent;
  final bool withColoredFont;
  final bool animate;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color backgroundColor;
  final bool transparent;
  final double? height;
  final double? width;
  final Color? accentColor;
  final String? semanticLabel;

  const TwoLineCard({
    super.key,
    required this.title,
    required this.content,
    this.extraContent,
    this.animate = false,
    this.withColoredFont = false,
    this.onTap,
    this.onLongPress,
    this.backgroundColor = CupertinoColors.systemBackground,
    this.transparent = false,
    this.height,
    this.width,
    this.accentColor,
    this.semanticLabel,
  });

  static Widget dummy(String title, String content) =>
      const TwoLineCard(title: 'title', content: 'content');

  @override
  State<TwoLineCard> createState() => _TwoLineCardState();
}

class _TwoLineCardState extends State<TwoLineCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isDown = false;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _initAnimation();
    }
  }

  void _initAnimation() {
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
  void didUpdateWidget(covariant TwoLineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.animate && widget.animate) {
      _initAnimation();
    } else if (oldWidget.animate && !widget.animate) {
      _animationController.dispose();
    }
  }

  @override
  void dispose() {
    if (widget.animate) {
      _animationController.dispose();
    }
    super.dispose();
  }

  bool get isDown => _isDown;

  void _handleTapDown(TapDownDetails _) {
    _isDown = true;
    if (widget.animate) {
      _animationController.forward();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (_isDown) {
      _isDown = false;
      if (widget.animate) {
        _animationController.reverse();
      }
    }
  }

  void _handleTapCancel() {
    if (_isDown) {
      _isDown = false;
      if (widget.animate) {
        _animationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transparent) {
      return Container(
        height: widget.height,
        width: widget.width,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    color: const Color.fromRGBO(0, 0, 0, 0),
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.content,
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [const FontFeature.tabularFigures()],
                        color: const Color.fromRGBO(0, 0, 0, 0),
                      ),
                ),
                if (widget.extraContent != null)
                  Text(
                    ' / ${widget.extraContent}',
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                          fontSize: 12,
                          fontFeatures: [const FontFeature.tabularFigures()],
                          color: const Color.fromRGBO(0, 0, 0, 0),
                        ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    final defaultTextColor =
        CupertinoTheme.of(context).textTheme.textStyle.color;
    final contentColor = widget.accentColor != null
        ? CupertinoDynamicColor.resolve(widget.accentColor!, context)
        : defaultTextColor;

    final core = Container(
      height: widget.height,
      width: widget.width,
      padding: const EdgeInsets.all(AppVisual.cardPadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppVisual.cardRadius),
        color: CupertinoDynamicColor.resolve(widget.backgroundColor, context),
        boxShadow: AppVisual.surfaceShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              widget.title,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    color: CupertinoTheme.of(context)
                        .textTheme
                        .textStyle
                        .color!
                        .withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
            ),
          ),
          const SizedBox(height: 2),
          widget.withColoredFont
              ? const SizedBox(height: 4)
              : SizedBox(
                  height: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.accentColor != null
                          ? CupertinoDynamicColor.resolve(
                              widget.accentColor!, context)
                          : CupertinoDynamicColor.resolve(
                              widget.backgroundColor, context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.content,
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: contentColor,
                      ),
                ),
                if (widget.extraContent != null)
                  Text(
                    ' / ${widget.extraContent}',
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                          fontSize: 12,
                          color: contentColor,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final hasAction = widget.onTap != null || widget.onLongPress != null;
    Widget interactiveWidget;
    if (hasAction) {
      interactiveWidget = GestureDetector(
        onTapDown: widget.animate ? _handleTapDown : null,
        onTapUp: widget.animate ? _handleTapUp : null,
        onTapCancel: widget.animate ? _handleTapCancel : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: widget.animate
            ? ScaleTransition(scale: _scaleAnimation, child: core)
            : core,
      );
    } else {
      interactiveWidget = widget.animate
          ? ScaleTransition(scale: _scaleAnimation, child: core)
          : core;
    }

    final effectiveSemanticLabel = widget.semanticLabel ??
        (widget.extraContent != null
            ? '${widget.title}，${widget.content} / ${widget.extraContent}'
            : '${widget.title}，${widget.content}');

    return Semantics(
      button: hasAction,
      enabled: hasAction,
      label: effectiveSemanticLabel,
      child: interactiveWidget,
    );
  }
}
