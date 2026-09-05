bool isWithinDdlReminderWindow(DateTime deadline, DateTime now) {
  final remaining = deadline.difference(now);
  return remaining >= Duration.zero && remaining <= const Duration(hours: 24);
}
