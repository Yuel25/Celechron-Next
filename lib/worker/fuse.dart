import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';

import 'package:celechron/database/database_helper.dart';

class Fuse {
  static List<int> _packageVersion = const [0, 0, 0];
  static int _packageBuild = 0;

  late DateTime lastUpdateTime;

  final bool isBeta = false;
  List<int> get version => _packageVersion;
  int get build => _packageBuild;
  List<int>? remoteVersion;
  int? remoteBuild;
  bool hasNewVersion = false;

  final HttpClient _httpClient = HttpClient();
  final DatabaseHelper _db = Get.find<DatabaseHelper>(tag: 'db');

  String get displayVersion => version.join('.') + (isBeta ? ' beta' : '');

  static void configurePackageVersion({
    required String version,
    required String buildNumber,
  }) {
    final parsedVersion = version.split('.').map(int.tryParse).toList();
    if (parsedVersion.length != 3 ||
        parsedVersion.any((part) => part == null)) {
      throw FormatException('Invalid package version: $version');
    }

    final parsedBuild = int.tryParse(buildNumber);
    if (parsedBuild == null) {
      throw FormatException('Invalid package build number: $buildNumber');
    }

    _packageVersion = parsedVersion.cast<int>();
    _packageBuild = parsedBuild;
  }

  Fuse() {
    lastUpdateTime = DateTime(2001, 1, 1);
  }

  Future<String?> checkUpdate() async {
    try {
      if (lastUpdateTime
          .isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
        return null;
      }

      // 通过 GitHub Releases 检查更新；无发布、限流或无网络时静默跳过
      var request = await _httpClient
          .getUrl(Uri.parse(
              'https://api.github.com/repos/Yuel25/Celechron-Next/releases/latest'))
          .timeout(const Duration(seconds: 8));
      request.headers
          .set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      var response = await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode != HttpStatus.ok) {
        return null;
      }
      var release = jsonDecode(await response.transform(utf8.decoder).join())
          as Map<String, dynamic>;

      // 标签格式为 vX.Y.Z（无 build 段），与 pubspec 的 version 对应
      var match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$')
          .firstMatch(release['tag_name'] as String? ?? '');
      if (match == null) {
        return null;
      }
      remoteVersion = [
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      ];
      remoteBuild = match.group(4) != null ? int.parse(match.group(4)!) : 0;

      hasNewVersion = _compareVersion((release['prerelease'] as bool?) ?? false);
      lastUpdateTime = DateTime.now();
      await _db.setFuse(this);

      if (hasNewVersion) {
        return '有新版本可用：${release['tag_name']}';
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  bool _compareVersion(bool remoteIsBeta) {
    if (remoteVersion == null || remoteBuild == null) {
      return false;
    }
    if (remoteVersion![0] > version[0]) {
      return true;
    } else if (remoteVersion![0] == version[0]) {
      if (remoteVersion![1] > version[1]) {
        return true;
      } else if (remoteVersion![1] == version[1]) {
        if (remoteVersion![2] > version[2]) {
          return true;
        } else if (remoteVersion![2] == version[2]) {
          if (remoteBuild! > build) {
            return true;
          } else if (remoteBuild == build) {
            if (isBeta && !remoteIsBeta) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  Map<String, dynamic> toJson() => {
        'lastUpdateTime': lastUpdateTime.toIso8601String(),
      };

  Fuse.fromJson(Map<String, dynamic> json) {
    lastUpdateTime = DateTime.parse(json['lastUpdateTime']);
  }
}
