import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Format double-precision floating point number of hours as {HH}h{MM}m
///
/// e.g. formatHoursToHHhMMm(1.5) = 01h30m
///
/// [hours] is the double-precision floating point number of hours to format.
///
/// Returns a string in the format {HH}h{MM}m.
String formatHoursToHHhMMm(double hours) {
  int h = hours.floor();
  int m = ((hours - h) * 60).round();
  return '${h.toString().padLeft(2, '0')}h${m.toString().padLeft(2, '0')}m';
}

/// Format a DateTime object as a string in the format {HH}:{MM} {AM/PM}.
///
/// If [dt] is null, returns 'Not set'.
///
/// [dt] is the DateTime object to format.
///
/// Returns a string in the format {HH}:{MM} {AM/PM}.
String formatTime(DateTime? dt) {
  if (dt == null) return 'Not set';
  return DateFormat('h:mm a').format(dt);
}

/// Select a date and time from a date and time picker dialog.
///
/// If [initialDate] is null, defaults to the current date and time.
///
/// If [helpText] is not null, displays [helpText] as the help text above the date picker and time picker.
///
/// Returns a DateTime object representing the selected date and time, or null if the user cancels the dialog.
Future<DateTime?> selectDateTime(BuildContext context, DateTime? initialDate, {String? helpText}) async {
  DateTime now = DateTime.now();
  initialDate = initialDate ?? now;
  final DateTime? date = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(2020),
    lastDate: DateTime(now.year + 5),
    helpText: helpText
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
