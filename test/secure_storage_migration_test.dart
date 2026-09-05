import 'dart:io';

import 'package:celechron/database/database_helper.dart';
import 'package:celechron/database/secure_storage_migration.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'task_flow_fixture.dart';

// 模拟 Keychain 访问组；插件按 dart:io 的宿主平台选择 options，
// Windows 上不能通过 defaultTargetPlatform 模拟 iOS MethodChannel。
class KeychainStorage implements FlutterSecureStorage {
  final legacy = {'username': 'old-user', 'password': 'old-password'};
  final target = <String, String>{};
  final calls = <String>[];
  bool failWrite = false;
  bool loseWrite = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final options = invocation.namedArguments[#iOptions] as IOSOptions;
    final values = options.toMap()['groupId'] == null ? legacy : target;
    final key = invocation.namedArguments[#key] as String?;
    switch (invocation.memberName) {
      case #readAll:
        calls.add('readAll');
        return Future<Map<String, String>>.value(Map.of(values));
      case #read:
        calls.add('read');
        return Future<String?>.value(values[key]);
      case #write:
        calls.add('write');
        if (failWrite) {
          return Future<void>.error(PlatformException(code: 'write_failed'));
        }
        if (!loseWrite) {
          values[key!] = invocation.namedArguments[#value] as String;
        }
        return Future<void>.value();
      case #delete:
        fail('Migration must not issue an unscoped Keychain delete');
      default:
        return super.noSuchMethod(invocation);
    }
  }
}

void main() {
  late KeychainStorage storage;
  late Directory directory;
  late DatabaseHelper db;
  late Map<String, String> legacy;
  late Map<String, String> target;
  late List<String> calls;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('secure_migration_');
    db = await openTaskFlowDatabase(directory);
    storage = KeychainStorage();
    legacy = storage.legacy;
    target = storage.target;
    calls = storage.calls;
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('verified migration runs once and leaves legacy credentials intact',
      () async {
    await migrateLegacySecureStorage(storage, db.optionsBox);
    expect(target, legacy);
    expect(legacy, hasLength(2));
    final count = calls.length;
    await migrateLegacySecureStorage(storage, db.optionsBox);
    expect(calls, hasLength(count));
  });

  test('write failure preserves credentials and allows retry', () async {
    storage.failWrite = true;
    await expectLater(migrateLegacySecureStorage(storage, db.optionsBox),
        throwsA(isA<PlatformException>()));
    expect(legacy, hasLength(2));
    expect(db.optionsBox.values.where((value) => value == true), isEmpty);
    storage.failWrite = false;
    await migrateLegacySecureStorage(storage, db.optionsBox);
    expect(target, legacy);
  });

  test('verification failure does not mark migration complete', () async {
    storage.loseWrite = true;
    await expectLater(
        migrateLegacySecureStorage(storage, db.optionsBox), throwsStateError);
    expect(legacy, hasLength(2));
    expect(db.optionsBox.values.where((value) => value == true), isEmpty);
  });

  test('existing target credentials are not overwritten by legacy values',
      () async {
    target.addAll({'username': 'new-user', 'password': 'new-password'});
    await migrateLegacySecureStorage(storage, db.optionsBox);
    expect(target['username'], 'new-user');
    expect(target['password'], 'new-password');
    expect(calls, isNot(contains('write')));
  });
}
