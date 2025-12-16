import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'models.dart';

// -------------------------------------------------------------------
// --- 2. LogService (Data Persistence & Export) ---
// -------------------------------------------------------------------

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String _getKeyForDate(DateTime date) {
    return 'log_${DateFormat('yyyy-MM-dd').format(date)}';
  }

  Future<DailyLog> getDailyLog(DateTime date) async {
    final String key = _getKeyForDate(date);
    final String? logJson = _prefs.getString(key);
    if (logJson != null) {
      try {
        return DailyLog.fromJson(jsonDecode(logJson));
      } catch (e) {
        // print("Error parsing log for $date: $e");
        return DailyLog();
      }
    } else {
      return DailyLog();
    }
  }

  Future<void> saveDailyLog(DateTime date, DailyLog log) async {
    final String key = _getKeyForDate(date);
    final String logJson = jsonEncode(log.toJson());
    await _prefs.setString(key, logJson);
  }

  Future<Map<DateTime, DailyLog>> getAllLogs() async {
    final Map<DateTime, DailyLog> allLogs = {};
    final allKeys = _prefs.getKeys().where((key) => key.startsWith('log_'));

    for (final key in allKeys) {
      try {
        final dateString = key.substring(4);
        final date = DateTime.parse(dateString);
        final utcDate = DateTime.utc(date.year, date.month, date.day);
        final log = await getDailyLog(utcDate);
        allLogs[utcDate] = log;
      } catch (e) {
        // print("Error parsing log for key $key: $e");
      }
    }
    return allLogs;
  }

  Future<void> clearAllData() async {
    // Fix: Only remove log entries (keys starting with 'log_')
    // This preserves categories (day_types, etc.) so the app doesn't break.
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('log_')) {
        await _prefs.remove(key);
      }
    }
  }

  Future<void> exportToCsv(BuildContext context) async {
    try {
      final Map<DateTime, DailyLog> allLogs = await getAllLogs();
      final directory = await getTemporaryDirectory();
      final exportDir = Directory("${directory.path}/sleep_data_export");
      await exportDir.create(recursive: true);

      final categoryLogsDir = Directory("${exportDir.path}/category_logs");
      await categoryLogsDir.create();

      final userCategoriesDir = Directory("${exportDir.path}/user_categories");
      await userCategoriesDir.create();

      // Main daily log CSV
      List<List<dynamic>> mainRows = [];
      mainRows.add([
        "Date",
        "Day Type",
        "Total Sleep (Hours)",
        "Sleep Latency (Mins)",
        "Awakenings (Count)",
        "Awake Duration (Mins)",
        "Out Of Bed Time",
        "Sleep Sessions Detail",
        "Notes",
        "Substance Log",
        "Medication Log",
        "Exercise Log"
      ]);

      final sortedKeys = allLogs.keys.toList()..sort();
      final dayTypes = await CategoryManager().getCategories('day_types');

      for (var date in sortedKeys) {
        final log = allLogs[date]!;
        final category = dayTypes.where((c) => c.id == log.dayTypeId).firstOrNull;

        int totalLatency = 0;
        int totalAwakenings = 0;
        int totalAwakeDur = 0;
        String lastOutTime = "";

        String sleepStr = log.sleepLog.map((e) {
          totalLatency += e.sleepLatencyMinutes;
          totalAwakenings += e.awakeningsCount;
          totalAwakeDur += e.awakeDurationMinutes;
          if (e.outOfBedTime != null) {
             lastOutTime = DateFormat('HH:mm').format(e.outOfBedTime!);
          }

          String base = "${DateFormat('HH:mm').format(e.bedTime)}-${DateFormat('HH:mm').format(e.wakeTime)} (${e.sleepLocationDisplayName})";
          return "$base (Lat: ${e.sleepLatencyMinutes}m, Awake: ${e.awakeDurationMinutes}m/${e.awakeningsCount}x)";
        }).join(" | ");

        String substanceStr = log.substanceLog.map((e) =>
          "${e.name}: ${e.amount} @ ${DateFormat('HH:mm').format(e.time)}").join(" | ");

        String medsStr = log.medicationLog.map((e) =>
          "${e.medicationTypeId} (${e.dosage}mg) @ ${DateFormat('HH:mm').format(e.time)}").join(" | ");

        String exerciseStr = log.exerciseLog.map((e) =>
          "${e.type} (${DateFormat('HH:mm').format(e.startTime)}-${DateFormat('HH:mm').format(e.finishTime)})").join(" | ");

        mainRows.add([
          DateFormat('yyyy-MM-dd').format(date),
          category?.displayName ?? "",
          log.totalSleepHours.toStringAsFixed(2),
          totalLatency,
          totalAwakenings,
          totalAwakeDur,
          lastOutTime,
          sleepStr,
          log.notes ?? "",
          substanceStr,
          medsStr,
          exerciseStr
        ]);
      }

      String mainCsvData = const ListToCsvConverter().convert(mainRows);
      final mainFile = File("${exportDir.path}/main_daily_log.csv");
      await mainFile.writeAsString(mainCsvData);

      // Sleep log CSV
      List<List<dynamic>> sleepRows = [];
      sleepRows.add(["Date", "Bed Time", "Fell Asleep Time", "Wake Time", "Out Of Bed Time", "Duration Hours", "Sleep Latency Mins", "Awakenings Count", "Awake Duration Mins", "Sleep Location"]);
      for (var date in sortedKeys) {
        final log = allLogs[date]!;
        for (var entry in log.sleepLog) {
          sleepRows.add([
            DateFormat('yyyy-MM-dd').format(date),
            DateFormat('HH:mm').format(entry.bedTime),
            DateFormat('HH:mm').format(entry.fellAsleepTime),
            DateFormat('HH:mm').format(entry.wakeTime),
            entry.outOfBedTime != null ? DateFormat('HH:mm').format(entry.outOfBedTime!) : "",
            entry.durationHours.toStringAsFixed(2),
            entry.sleepLatencyMinutes,
            entry.awakeningsCount,
            entry.awakeDurationMinutes,
            entry.sleepLocationDisplayName
          ]);
        }
      }
      String sleepCsvData = const ListToCsvConverter().convert(sleepRows);
      final sleepFile = File("${categoryLogsDir.path}/sleep_log.csv");
      await sleepFile.writeAsString(sleepCsvData);

      // Substance log CSV
      List<List<dynamic>> substanceRows = [];
      substanceRows.add(["Date", "Substance Type", "Amount", "Time"]);
      for (var date in sortedKeys) {
        final log = allLogs[date]!;
        for (var entry in log.substanceLog) {
          substanceRows.add([
            DateFormat('yyyy-MM-dd').format(date),
            entry.name,
            entry.amount,
            DateFormat('HH:mm').format(entry.time)
          ]);
        }
      }
      String substanceCsvData = const ListToCsvConverter().convert(substanceRows);
      final substanceFile = File("${categoryLogsDir.path}/substance_log.csv");
      await substanceFile.writeAsString(substanceCsvData);

      // Medication log CSV
      List<List<dynamic>> medicationRows = [];
      medicationRows.add(["Date", "Medication Type", "Dosage", "Time"]);
      for (var date in sortedKeys) {
        final log = allLogs[date]!;
        for (var entry in log.medicationLog) {
          medicationRows.add([
            DateFormat('yyyy-MM-dd').format(date),
            entry.medicationTypeId,
            entry.dosage,
            DateFormat('HH:mm').format(entry.time)
          ]);
        }
      }
      String medicationCsvData = const ListToCsvConverter().convert(medicationRows);
      final medicationFile = File("${categoryLogsDir.path}/medication_log.csv");
      await medicationFile.writeAsString(medicationCsvData);

      // Exercise log CSV
      List<List<dynamic>> exerciseRows = [];
      exerciseRows.add(["Date", "Exercise Type", "Start Time", "Finish Time", "Duration Mins"]);
      for (var date in sortedKeys) {
        final log = allLogs[date]!;
        for (var entry in log.exerciseLog) {
          exerciseRows.add([
            DateFormat('yyyy-MM-dd').format(date),
            entry.type,
            DateFormat('HH:mm').format(entry.startTime),
            DateFormat('HH:mm').format(entry.finishTime),
            entry.finishTime.difference(entry.startTime).inMinutes
          ]);
        }
      }
      String exerciseCsvData = const ListToCsvConverter().convert(exerciseRows);
      final exerciseFile = File("${categoryLogsDir.path}/exercise_log.csv");
      await exerciseFile.writeAsString(exerciseCsvData);

      // User categories CSVs
      final categoryTypes = ['day_types', 'sleep_locations', 'medication_types', 'exercise_types', 'substance_types'];
      for (var type in categoryTypes) {
        final categories = await CategoryManager().getCategories(type);
        List<List<dynamic>> catRows = [];
        catRows.add(["id", "name", "iconName", "colorHex"]);
        for (var cat in categories) {
          catRows.add([cat.id, cat.name, cat.iconName, cat.colorHex]);
        }
        String catCsvData = const ListToCsvConverter().convert(catRows);
        final catFile = File("${userCategoriesDir.path}/$type.csv");
        await catFile.writeAsString(catCsvData);
      }

      // README.md
      const readmeContent = '''
# Sleep Data Export

This export contains your sleep tracking data in a structured folder format.

## Files

- `main_daily_log.csv`: Summary statistics for each day, including total sleep, latency, awakenings, and detailed logs.
- `category_logs/`: Detailed logs for each category.
  - `sleep_log.csv`: Individual sleep sessions with times and metrics.
  - `substance_log.csv`: Caffeine and alcohol consumption entries.
  - `medication_log.csv`: Medication intake entries.
  - `exercise_log.csv`: Exercise session entries.
- `user_categories/`: Definitions of user-defined categories.
  - `day_types.csv`: Day type categories.
  - `sleep_locations.csv`: Sleep location categories.
  - `medication_types.csv`: Medication type categories.
  - `exercise_types.csv`: Exercise type categories.
  - `substance_types.csv`: Substance type categories.

## Notes

- All times are in 24-hour format (HH:mm).
- Dates are in YYYY-MM-DD format.
- Durations are in hours or minutes as specified.
- Empty fields indicate no data or N/A.
''';
      final readmeFile = File("${exportDir.path}/README.md");
      await readmeFile.writeAsString(readmeContent);

      // Collect all files
      final files = <XFile>[];
      await for (var entity in exportDir.list(recursive: true)) {
        if (entity is File) {
          files.add(XFile(entity.path));
        }
      }

      await Share.shareXFiles(files, text: 'Here is your sleep data export with folder structure.');

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting CSV: $e')),
        );
      }
    }
  }
}
