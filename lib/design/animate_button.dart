import 'package:flutter/cupertino.dart';

class AnimateButton extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final CupertinoDynamicColor backgroundColor;
  final String? semanticLabel;

  const AnimateButton({
    super.key,
    required this.text,
    this.onTap,
    this.backgroundColor = CupertinoColors.systemBackground,
    this.semanticLabel,
  });

  @override
  State<AnimateButton> createState() => _AnimateButtonState();
}

class _AnimateButtonState extends State<AnimateButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isDown = false;

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

  bool get isDown => _isDown;

  void _handleTapDown(TapDownDetails _) {
    _isDown = true;
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    if (_isDown) {
      _isDown = false;
      _animationController.reverse();
    }
  }

  void _handleTapCancel() {
    if (_isDown) {
      _isDown = false;
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isClickable = widget.onTap != null;

    final childWidget = Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: CupertinoDynamicColor.resolve(
            widget.backgroundColor, context),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.text,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: CupertinoTheme.of(context)
                      .textTheme
                      .textStyle
                      .color,
                ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      enabled: isClickable,
      label: widget.semanticLabel ?? widget.text,
      child: GestureDetector(
        onTapDown: isClickable ? _handleTapDown : null,
        onTapUp: isClickable ? _handleTapUp : null,
        onTapCancel: isClickable ? _handleTapCancel : null,
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: childWidget,
        ),
      ),
    );
  }
}
