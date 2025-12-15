import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String formatHoursToHHhMMm(double hours) {
  int h = hours.floor();
  int m = ((hours - h) * 60).round();
  return '${h.toString().padLeft(2, '0')}h${m.toString().padLeft(2, '0')}m';
}

String formatTime(DateTime? dt) {
  if (dt == null) return 'Not set';
  return DateFormat('h:mm a').format(dt);
}

Future<DateTime?> selectDateTime(BuildContext context, DateTime? initialDate, {String? helpText}) async {
  DateTime now = DateTime.now();
  initialDate = initialDate ?? now;
  final DateTime? date = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(2020),
    lastDate: DateTime(now.year + 5),
  );
  if (date == null) return null;
  final TimeOfDay? time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initialDate),
    helpText: helpText
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
