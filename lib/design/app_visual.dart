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

  // --- 排版令牌 (Typography) ---
  /// 大标题（32, w700）
  static const TextStyle largeTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );
  static const TextStyle titleLarge = largeTitle;

  /// 区块标题（20, w600）
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );

  /// 正文（17, normal）
  static const TextStyle body = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.normal,
    letterSpacing: -0.4,
  );

  /// 辅助（15, normal）
  static const TextStyle secondary = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    letterSpacing: -0.2,
  );
  static const TextStyle subheadline = secondary;

  /// 说明（13, normal）
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );
  static const TextStyle footnote = caption;

  // --- 容器与主题色 (Container & Brand Colors) ---
  static const Color brand = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF5367D9),
    darkColor: Color(0xFF8D9BFF),
  );

  static const Color brandSoft = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFEFF1FF),
    darkColor: Color(0xFF252A48),
  );

  static const Color moduleGrade = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFEFF3FF),
    darkColor: Color(0xFF252E47),
  );

  static const Color moduleCourse = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFECF8F7),
    darkColor: Color(0xFF223735),
  );

  static const Color moduleHomework = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF5EEFA),
    darkColor: Color(0xFF352A3D),
  );

  static const Color modulePractice = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFF3E9),
    darkColor: Color(0xFF3B2E25),
  );

  static const Color metricBlue = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFEAF2FF),
    darkColor: Color(0xFF263449),
  );

  static const Color metricPeach = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFF0E8),
    darkColor: Color(0xFF3A2A25),
  );

  static const Color metricGreen = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFEDF8EA),
    darkColor: Color(0xFF263528),
  );

  static const Color metricViolet = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF1EEFF),
    darkColor: Color(0xFF302C45),
  );

  static const Color seasonAutumn = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFF1EB),
    darkColor: Color(0xFF3B2B26),
  );

  static const Color seasonWinter = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFEAF3FF),
    darkColor: Color(0xFF253448),
  );

  // --- 前景强调色令牌 (Foreground Accent Colors) ---
  /// 春季绿前景色
  static const CupertinoDynamicColor fgSpring =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF2B821A),
    darkColor: Color(0xFF93FB38),
  );

  /// 夏季红前景色
  static const CupertinoDynamicColor fgSummer =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFD6183C),
    darkColor: Color(0xFFFF1945),
  );

  /// 秋季橙前景色
  static const CupertinoDynamicColor fgAutumn =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFCC4A18),
    darkColor: Color(0xFFFF6538),
  );

  /// 冬季蓝前景色
  static const CupertinoDynamicColor fgWinter =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0082BD),
    darkColor: Color(0xFF00B7FB),
  );

  /// 紫罗兰前景色
  static const CupertinoDynamicColor fgViolet =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF6B54B8),
    darkColor: Color(0xFF9783D8),
  );

  /// 樱花粉前景色
  static const CupertinoDynamicColor fgSakura =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFA644A5),
    darkColor: Color(0xFFDA82D9),
  );

  /// 沙黄前景色
  static const CupertinoDynamicColor fgSand =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF9E7700),
    darkColor: Color(0xFFFCDE3B),
  );

  /// 青蓝前景色
  static const CupertinoDynamicColor fgCyan =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0075D1),
    darkColor: Color(0xFF008CFF),
  );

  /// 品红前景色
  static const CupertinoDynamicColor fgMagenta =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFB81B77),
    darkColor: Color(0xFFEE37A1),
  );

  /// 桃色前景色
  static const CupertinoDynamicColor fgPeach =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFFB84518),
    darkColor: Color(0xFFE97246),
  );

  /// 确认绿前景色
  static const CupertinoDynamicColor fgOkGreen =
      CupertinoDynamicColor.withBrightness(
    color: Color(0xFF1E8208),
    darkColor: Color(0xFF3FDE17),
  );

  /// 前景强调色集合
  static const List<CupertinoDynamicColor> fgAccents = [
    fgSpring,
    fgSummer,
    fgAutumn,
    fgWinter,
    fgViolet,
    fgSakura,
    fgSand,
    fgCyan,
    fgMagenta,
    fgPeach,
    fgOkGreen,
  ];

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
