import 'package:celechron/worker/ddl_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2030, 1, 1);
  for (final offset in [
    const Duration(microseconds: -1),
    const Duration(minutes: -30),
    const Duration(hours: 24, microseconds: 1),
    const Duration(hours: 24, minutes: 59)
  ]) {
    test('excludes deadline offset $offset', () {
      expect(isWithinDdlReminderWindow(now.add(offset), now), isFalse);
    });
  }
  for (final offset in [
    Duration.zero,
    const Duration(minutes: 30),
    const Duration(hours: 24)
  ]) {
    test('includes deadline offset $offset', () {
      expect(isWithinDdlReminderWindow(now.add(offset), now), isTrue);
    });
  }
}
