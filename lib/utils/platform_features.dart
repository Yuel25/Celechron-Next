import 'dart:io';

final class PlatformFeatures {
  static bool get hasBackgroundRefresh {
    return Platform.isAndroid;
  }
}
