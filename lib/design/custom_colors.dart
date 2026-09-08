import 'package:flutter/cupertino.dart';
import 'package:celechron/design/app_visual.dart';

class UidColors {
  static Color colorFromUid(String? uid) {
    int value = (uid ?? '').hashCode;
    final hue = (20 + (value * 19 + 133) % 310).toDouble();
    return CupertinoDynamicColor.withBrightness(
      color: HSLColor.fromAHSL(1, hue, 0.66, 0.47).toColor(),
      darkColor: HSLColor.fromAHSL(1, hue, 0.7, 0.68).toColor(),
    );
  }
}

abstract final class AppSemanticColors {
  static const courseMorning = CupertinoColors.systemRed;
  static const courseForenoon = CupertinoColors.systemOrange;
  static const courseNoon = CupertinoColors.systemYellow;
  static const courseAfternoon = CupertinoColors.systemGreen;
  static const courseEvening = CupertinoColors.systemBlue;
  static const courseNight = CupertinoColors.systemPurple;

  static const exam = CupertinoColors.systemPink;
  static const focus = CupertinoColors.systemIndigo;
  static const schedule = CupertinoColors.systemTeal;
  static const success = CupertinoColors.systemGreen;
  static const warning = CupertinoColors.systemOrange;
  static const danger = CupertinoColors.systemRed;
  static const neutral = CupertinoColors.systemGrey;
}

class TimeColors {
  static Color colorFromHour(int hour) {
    Color color = AppSemanticColors.courseMorning;
    if (hour <= 8) {
      color = AppSemanticColors.courseMorning;
    } else if (hour >= 9 && hour <= 12) {
      color = AppSemanticColors.courseForenoon;
    } else if (hour == 13) {
      color = AppSemanticColors.courseNoon;
    } else if (hour >= 14 && hour <= 15) {
      color = AppSemanticColors.courseAfternoon;
    } else if (hour >= 16 && hour <= 17) {
      color = AppSemanticColors.schedule;
    } else if (hour >= 18 && hour <= 19) {
      color = AppSemanticColors.courseEvening;
    } else if (hour >= 20) {
      color = AppSemanticColors.courseNight;
    }
    return color;
  }

  static Color colorFromClass(int number) {
    Color color = AppSemanticColors.courseMorning;
    if (number <= 1) {
      color = AppSemanticColors.courseMorning;
    } else if (number >= 2 && number <= 5) {
      color = AppSemanticColors.courseForenoon;
    } else if (number == 6) {
      color = AppSemanticColors.courseNoon;
    } else if (number >= 7 && number <= 8) {
      color = AppSemanticColors.courseAfternoon;
    } else if (number >= 9 && number <= 10) {
      color = AppSemanticColors.schedule;
    } else if (number >= 11 && number <= 12) {
      color = AppSemanticColors.courseEvening;
    } else if (number >= 13) {
      color = AppSemanticColors.courseNight;
    }
    return color;
  }
}

/// 已废弃：旧版动态色集合，请迁移至 [AppVisual] 的前景强调色（如 [AppVisual.fgSpring] 等）或容器色令牌。
@Deprecated('Use AppVisual foreground or container tokens instead.')
class CustomCupertinoDynamicColors {
  static const CupertinoDynamicColor spring =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(230, 255, 226, 1.0),
    darkColor: Color.fromRGBO(147, 251, 56, 1.0),
  );

  static const CupertinoDynamicColor summer =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(255, 218, 238, 1.0),
    darkColor: Color.fromRGBO(255, 25, 69, 1.0),
  );

  static const CupertinoDynamicColor autumn =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(255, 234, 230, 1.0),
    darkColor: Color.fromRGBO(255, 101, 56, 1.0),
  );

  static const CupertinoDynamicColor winter =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(226, 239, 255, 1.0),
    darkColor: Color.fromRGBO(0, 183, 251, 1.0),
  );

  static const CupertinoDynamicColor violet =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(230, 229, 255, 1.0),
    darkColor: Color.fromRGBO(151, 131, 216, 1.0),
  );

  static const CupertinoDynamicColor sakura =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(255, 226, 255, 1.0),
    darkColor: Color.fromRGBO(218, 130, 217, 1.0),
  );

  static const CupertinoDynamicColor sand =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(255, 246, 211, 1.0),
    darkColor: Color.fromRGBO(252, 222, 59, 1.0),
  );

  static const CupertinoDynamicColor cyan =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(218, 234, 255, 1.0),
    darkColor: Color.fromRGBO(0, 140, 255, 1.0),
  );

  static const CupertinoDynamicColor magenta =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(230, 229, 255, 1.0),
    darkColor: Color.fromRGBO(238, 55, 161, 1.0),
  );

  static const CupertinoDynamicColor peach =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(255, 235, 226, 1.0),
    darkColor: Color.fromRGBO(233, 114, 70, 1.0),
  );

  static const CupertinoDynamicColor okGreen =
      CupertinoDynamicColor.withBrightness(
    color: Color.fromRGBO(230, 255, 226, 1.0),
    darkColor: Color.fromRGBO(63, 222, 23, 1.0),
  );
}
