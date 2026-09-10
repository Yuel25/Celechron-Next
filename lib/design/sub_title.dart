import 'package:flutter/cupertino.dart';

import 'package:celechron/design/app_visual.dart';

/// 按字号映射到 [AppVisual] 排版令牌，保证一级/二级标题字重与字距一致。
TextStyle _mappedTitleStyle(BuildContext context, double fontSize) {
  final token = fontSize >= 30
      ? AppVisual.largeTitle
      : fontSize >= 17
          ? AppVisual.sectionTitle
          : AppVisual.body;
  return CupertinoTheme.of(context)
      .textTheme
      .navLargeTitleTextStyle
      .merge(token)
      .copyWith(fontSize: fontSize);
}

class SubtitleRow extends StatelessWidget {
  final String subtitle;
  final Widget? right;
  final double padHorizontal;
  final double padVertical;
  final double fontSize;
  final String? heroTag;

  const SubtitleRow({
    super.key,
    required this.subtitle,
    this.right,
    this.padHorizontal = 2,
    this.fontSize = 20, // 对齐 AppVisual.sectionTitle.fontSize
    this.padVertical = 12,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      subtitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _mappedTitleStyle(context, fontSize),
    );

    final titleWidget = heroTag != null
        ? Hero(
            tag: heroTag!,
            child: textWidget,
          )
        : textWidget;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padHorizontal),
      child: Row(
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.symmetric(vertical: padVertical),
              child: titleWidget,
            ),
          ),
          const SizedBox(width: 8),
          right == null ? const SizedBox(height: 0) : right!,
        ],
      ),
    );
  }
}

class SubSubtitleRow extends StatelessWidget {
  final String subtitle;
  final Widget? right;
  final double padHorizontal;
  final String? heroTag;

  const SubSubtitleRow({
    super.key,
    required this.subtitle,
    this.right,
    this.padHorizontal = 2,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      subtitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _mappedTitleStyle(context, 18),
    );

    final titleWidget = heroTag != null
        ? Hero(
            tag: heroTag!,
            child: textWidget,
          )
        : textWidget;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padHorizontal),
      child: Row(
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: titleWidget,
            ),
          ),
          const SizedBox(width: 8),
          right == null ? const SizedBox(height: 0) : right!,
        ],
      ),
    );
  }
}
