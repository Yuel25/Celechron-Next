import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';

class CelechronSliverTextHeader extends StatelessWidget {
  final String subtitle;
  final Widget? right;
  final Widget? bottom;
  final double fontSize;
  final bool firstPage;
  final String? heroTag;

  const CelechronSliverTextHeader({
    super.key,
    required this.subtitle,
    this.right,
    this.bottom,
    this.fontSize = 20,
    this.firstPage = false,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: CelechronHeader(
        fontSize: fontSize,
        firstPage: firstPage,
        subtitle: subtitle,
        right: right,
        bottom: bottom,
        padding: MediaQuery.of(context).padding.top,
        textScaler: MediaQuery.textScalerOf(context),
        heroTag: heroTag,
      ),
    );
  }
}

class CelechronHeader extends SliverPersistentHeaderDelegate {
  final String subtitle;
  final Widget? bottom;
  final Widget? right;
  final double padding;
  final double fontSize;
  final bool firstPage;
  final String? heroTag;
  final TextScaler textScaler;

  CelechronHeader({
    required this.subtitle,
    this.right,
    this.bottom,
    required this.padding,
    this.fontSize = 20,
    this.firstPage = false,
    this.heroTag,
    this.textScaler = TextScaler.noScaling,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final Widget titleWidget = Column(
      children: [
        Text(
          subtitle,
          style: CupertinoTheme.of(context)
              .textTheme
              .navTitleTextStyle
              .copyWith(
                fontSize: fontSize - (bottom == null ? 0 : 2),
              ),
        ),
        if (bottom != null) bottom!,
      ],
    );

    final Widget heroOrTitle = heroTag != null
        ? Hero(
            tag: heroTag!,
            child: titleWidget,
          )
        : titleWidget;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: shrinkOffset > 12 ? 10 : shrinkOffset / 1.2,
            sigmaY: shrinkOffset > 12 ? 10 : shrinkOffset / 1.2),
        child: Container(
          padding: EdgeInsets.only(top: padding),
          color: shrinkOffset > 12
              ? CupertinoDynamicColor.resolve(
                      CupertinoColors.systemBackground, context)
                  .withValues(alpha: 0.5)
              : CupertinoDynamicColor.resolve(
                      CupertinoColors.systemBackground, context)
                  .withValues(alpha: shrinkOffset / 24),
          child: Column(
            children: [
              Stack(
                children: [
                  // Back button if not first page
                  if (!firstPage)
                    Container(
                      alignment: Alignment.centerLeft,
                      child: CupertinoButton(
                        padding: const EdgeInsets.only(left: 2),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Icon(
                          CupertinoIcons.back,
                          color: CupertinoDynamicColor.resolve(
                              CupertinoColors.label, context),
                        ),
                      ),
                    ),
                  // Title at the center
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: heroOrTitle,
                      ),
                    ],
                  ),
                  // Right button
                  if (right != null)
                    Container(alignment: Alignment.centerRight, child: right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double get _extent {
    final double base = 48.0 + (bottom == null ? 0.0 : 48.0);
    return math.max(base, textScaler.scale(base)) + padding;
  }

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}
