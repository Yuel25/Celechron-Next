import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

import '../utils/utils.dart';

/// 仅由 iOS 初始化调用；Android 不存在 Keychain group 的迁移。
Future<void> migrateLegacySecureStorage(
    FlutterSecureStorage storage, Box options) async {
  final marker =
      'secureStorageGroupMigrationV1:${secureStorageIOSOptions.toMap()['groupId']}';
  if (options.get(marker) == true) return;
  const legacy = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
    accountName: 'Celechron',
  );
  final items = await storage.readAll(iOptions: legacy);
  for (final entry in items.entries) {
    // 重试时保留目标位置已有的凭据，避免用旧账号覆盖新账号。
    final existing =
        await storage.read(key: entry.key, iOptions: secureStorageIOSOptions);
    if (existing == null) {
      await storage.write(
          key: entry.key,
          value: entry.value,
          iOptions: secureStorageIOSOptions);
    }
    final expected = existing ?? entry.value;
    final actual =
        await storage.read(key: entry.key, iOptions: secureStorageIOSOptions);
    if (actual != expected) {
      throw StateError('Secure storage migration verification failed');
    }
    // 不带 groupId 的旧查询可能同时匹配新 group，不能据此安全删除旧项。
    // 保留旧项，仅迁移缺失值，完成标记避免后续启动重复读写。
  }
  await options.put(marker, true);
}
