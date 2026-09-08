import 'package:flutter/cupertino.dart';

class MultipleColumns extends StatelessWidget {
  final List<Widget> contents;
  final List<String> titles;
  final List<VoidCallback?> onTaps;
  final Color color;
  final List<String?>? semanticLabels;

  const MultipleColumns({
    super.key,
    required this.contents,
    required this.titles,
    required this.onTaps,
    this.color = CupertinoColors.white,
    this.semanticLabels,
  });

  @override
  Widget build(BuildContext context) {
    final columnCount = titles.length;

    var children = <Widget>[];
    for (var i = 0; i < columnCount; i++) {
      children.add(
        _ColumnWidget(
          content: contents[i],
          title: titles[i],
          onTap: onTaps[i],
          color: color,
          semanticLabel: semanticLabels != null && i < semanticLabels!.length
              ? semanticLabels![i]
              : null,
        ),
      );
      children.add(const _VerticalLine(color: CupertinoColors.systemFill));
    }
    if (children.isNotEmpty) {
      children.removeLast();
    }

    return SizedBox(
      child: Row(
        children: children,
      ),
    );
  }
}

class _ColumnWidget extends StatelessWidget {
  final Widget content;
  final String title;
  final Color color;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const _ColumnWidget({
    required this.content,
    required this.title,
    required this.color,
    required this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isClickable = onTap != null;
    final effectiveLabel = semanticLabel ?? title;

    final columnChild = Column(
      children: [
        content,
        Text(
          title,
          style: const TextStyle(
            color: CupertinoColors.systemGrey,
            fontSize: 14,
          ),
        ),
      ],
    );

    return Expanded(
      child: Semantics(
        button: isClickable,
        enabled: isClickable,
        label: effectiveLabel,
        child: isClickable
            ? GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: columnChild,
              )
            : columnChild,
      ),
    );
  }
}

class _VerticalLine extends StatelessWidget {
  final Color color;

  const _VerticalLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      color: color,
    );
  }
}
