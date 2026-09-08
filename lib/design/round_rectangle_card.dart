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
  final String? semanticLabel;

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
    this.semanticLabel,
  });

  @override
  State<RoundRectangleCard> createState() => _RoundRectangleCardState();
}

class _RoundRectangleCardState extends State<RoundRectangleCard>
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
  void didUpdateWidget(covariant RoundRectangleCard oldWidget) {
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
    final brightness = CupertinoTheme.of(context).brightness ??
        MediaQuery.of(context).platformBrightness;
    final isClickable = widget.onTap != null;

    final core = Container(
      padding: widget.padding,
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
      child: widget.child,
    );

    Widget interactiveWidget;
    if (isClickable) {
      interactiveWidget = GestureDetector(
        onTapDown: widget.animate ? _handleTapDown : null,
        onTapUp: widget.animate ? _handleTapUp : null,
        onTapCancel: widget.animate ? _handleTapCancel : null,
        onTap: widget.onTap,
        child: widget.animate
            ? ScaleTransition(scale: _scaleAnimation, child: core)
            : core,
      );
    } else {
      interactiveWidget = widget.animate
          ? ScaleTransition(scale: _scaleAnimation, child: core)
          : core;
    }

    return Semantics(
      button: isClickable,
      enabled: isClickable,
      label: widget.semanticLabel,
      child: interactiveWidget,
    );
  }
}

class RoundRectangleCardWithForehead extends StatelessWidget {
  final Widget child;
  final Widget forehead;
  final Color foreheadColor;
  final Function()? onTap;
  final bool animate;
  final String? semanticLabel;

  const RoundRectangleCardWithForehead({
    super.key,
    required this.child,
    required this.forehead,
    this.foreheadColor = CupertinoColors.systemFill,
    this.onTap,
    this.animate = true,
    this.semanticLabel,
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
            ),
          ),
        ),
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
                semanticLabel: semanticLabel,
                child: child,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
