import 'package:flutter/cupertino.dart';

/// Celechron 的基础视觉令牌。
///
/// 页面只在确有信息语义时覆盖这些值，避免各自形成一套圆角、阴影和间距。
abstract final class AppVisual {
  static const double pagePadding = 16;
  static const double cardRadius = 16;
  static const double controlRadius = 10;
  static const double cardPadding = 16;
  static const double itemGap = 12;
  static const double sectionGap = 24;

  static const Color brand = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF5367D9),
    darkColor: Color(0xFF8D9BFF),
  );

  static const Color brandSoft = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFEFF1FF),
    darkColor: Color(0xFF252A48),
  );

  static const List<BoxShadow> surfaceShadow = [
    BoxShadow(
      color: Color.fromRGBO(24, 32, 56, 0.035),
      blurRadius: 14,
      offset: Offset(0, 4),
    ),
  ];

  static Border subtleBorder(BuildContext context) => Border.all(
        color: CupertinoDynamicColor.resolve(
          CupertinoColors.separator.withValues(alpha: 0.18),
          context,
        ),
        width: 0.5,
      );
}
