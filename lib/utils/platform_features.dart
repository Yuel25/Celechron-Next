import 'dart:io';

final class PlatformFeatures {
  static bool get hasBackgroundRefresh {
    return Platform.isAndroid;
  }

  static bool get hasWidgetSupport {
    return Platform.isAndroid;
  }

  static bool get isDesktop {
    return Platform.isWindows;
  }
}
