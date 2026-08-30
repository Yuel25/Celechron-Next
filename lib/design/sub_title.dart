import 'package:flutter/cupertino.dart';

class SubtitleRow extends StatelessWidget {
  final String subtitle;
  final Widget? right;
  final double padHorizontal;
  final double padVertical;
  late final String heroTag = subtitle;
  final double fontSize;

  SubtitleRow(
      {super.key,
      required this.subtitle,
      this.right,
      this.padHorizontal = 2,
      this.fontSize = 20,
      this.padVertical = 12});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: padHorizontal),
        child: Row(children: [
          Expanded(
            child: Container(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.symmetric(vertical: padVertical),
                child: Hero(
                  tag: heroTag,
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .navLargeTitleTextStyle
                        .copyWith(fontSize: fontSize),
                  ),
                )),
          ),
          const SizedBox(width: 8),
          right == null ? const SizedBox(height: 0) : right!,
        ]));
  }
}

class SubSubtitleRow extends StatelessWidget {
  final String subtitle;
  final Widget? right;
  final double padHorizontal;
  late final String heroTag = subtitle;

  SubSubtitleRow(
      {super.key, required this.subtitle, this.right, this.padHorizontal = 2});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: padHorizontal),
        child: Row(children: [
          Expanded(
            child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Hero(
                  tag: heroTag,
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .navLargeTitleTextStyle
                        .copyWith(fontSize: 18),
                  ),
                )),
          ),
          const SizedBox(width: 8),
          right == null ? const SizedBox(height: 0) : right!,
        ]));
  }
}
