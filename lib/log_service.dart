import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:archive/archive.dart';
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
  bool get isDarkMode => _prefs.getBool('is_dark_mode') ?? false;

  Future<void> setDarkMode(bool value) async {
    await _prefs.setBool('is_dark_mode', value);
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
  
  // Export to CSV function 
  Future<void> exportToCsv(BuildContext context) async {
    try {
      final Map<DateTime, DailyLog> allLogs = await getAllLogs();
      // Note that use of temp directory does not work for web apps
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
        "Sleep Sessions Total",
        "Notes",
        "Caffeine Total (Cups)",
        "Meds Log Total (Entries)",
        "Exercise Total (Mins)"
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

        int sleepSessionsTotal = log.sleepLog.length;

        for (var i = 0; i < log.sleepLog.length; i++) {
          var e = log.sleepLog[i];
          totalLatency += e.sleepLatencyMinutes;
          totalAwakenings += e.awakeningsCount;
          totalAwakeDur += e.awakeDurationMinutes;
          if (e.outOfBedTime != null) {
            lastOutTime = DateFormat('HH:mm').format(e.outOfBedTime!);
          }
        }

        int averageLatency = totalLatency ~/ (sleepSessionsTotal==0 ? 1 : sleepSessionsTotal);

        int caffeineTotal = log.substanceLog.where((e) => e.substanceTypeId == 'coffee').fold(0, (sum, e) => sum + (int.tryParse(e.amount) ?? 0));

        int medsLogTotal = log.medicationLog.length;

        int exerciseTotalMins = log.exerciseLog.fold(0, (sum, e) => sum + e.finishTime.difference(e.startTime).inMinutes);

        mainRows.add([
          DateFormat('yyyy-MM-dd').format(date),
          category?.displayName ?? "",
          log.totalSleepHours.toStringAsFixed(2),
          averageLatency,
          totalAwakenings,
          totalAwakeDur,
          lastOutTime,
          sleepSessionsTotal,
          log.notes ?? "",
          caffeineTotal,
          medsLogTotal,
          exerciseTotalMins
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
            entry.substanceTypeId,
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

- `main_daily_log.csv`: Summary statistics for each day, including total sleep, average latency, awakenings, and summary logs.
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

## Column Descriptions

### main_daily_log.csv
- **Date**: The date of the log entry in YYYY-MM-DD format.
- **Day Type**: The type of day (e.g., Work, Relax, Travel, Social), based on user-selected category.
- **Total Sleep (Hours)**: Total hours of sleep for the day, calculated as the sum of all sleep session durations.
- **Sleep Latency (Mins)**: Average time in minutes taken to fall asleep across all sleep sessions (truncated to integer).
- **Awakenings (Count)**: Total number of awakenings during sleep across all sessions (self-reported).
- **Awake Duration (Mins)**: Overall duration of awakenings during sleep periods across all sessions (self-reported).
- **Out Of Bed Time**: The time the user got out of bed for the last sleep session, in HH:mm format (empty if not recorded).
- **Sleep Sessions Total**: The number of sleep sessions logged for the day.
- **Notes**: Any additional notes entered by the user for the day.
- **Caffeine Total (Cups)**: Total number of cups of coffee (or other caffeine/alcohol) consumed.
- **Meds Log Total (Entries)**: Total number of medication entries for the day.
- **Exercise Total (Mins)**: Total minutes spent exercising for the day.

### sleep_log.csv
- **Date**: The date of the sleep session in YYYY-MM-DD format.
- **Bed Time**: The time the user went to bed, in HH:mm format.
- **Fell Asleep Time**: The time the user fell asleep, in HH:mm format.
- **Wake Time**: The time the user woke up, in HH:mm format.
- **Out Of Bed Time**: The time the user got out of bed (i.e. Rise Time), in HH:mm format (empty if not recorded).
- **Duration Hours**: The duration of the sleep session in hours (calculated from fell asleep to wake time).
- **Sleep Latency Mins**: Time in minutes taken to fall asleep (bed time to fell asleep time).
- **Awakenings Count**: Number of times the user woke up during this session (self-reported).
- **Awake Duration Mins**: Overall duration of awakenings during this sleep session (self-reported).
- **Sleep Location**: The location where the user slept (e.g., Bed, Couch, In Transit).

### substance_log.csv
- **Date**: The date of the substance entry in YYYY-MM-DD format.
- **Substance Type**: The type of substance (e.g., coffee, tea, cola, alcohol).
- **Amount**: The amount consumed (number of cups).
- **Time**: The time the substance was consumed, in HH:mm format.

### medication_log.csv
- **Date**: The date of the medication entry in YYYY-MM-DD format.
- **Medication Type**: The type of medication taken (e.g., Melatonin).
- **Dosage**: The dosage amount (mg).
- **Time**: The time the medication was taken, in HH:mm format.

### exercise_log.csv
- **Date**: The date of the exercise session in YYYY-MM-DD format.
- **Exercise Type**: The type of exercise (e.g., Light, Medium, Heavy).
- **Start Time**: The start time of the exercise session, in HH:mm format.
- **Finish Time**: The finish time of the exercise session, in HH:mm format.
- **Duration Mins**: The duration of the exercise session in minutes.

## Notes

- All times are in 24-hour format (HH:mm).
- Dates are in YYYY-MM-DD format. Please use dates to link files for database analysis.
- Durations are in hours or minutes as specified.
- Empty fields indicate no data or N/A.
- exercise_types and substance_types are not editable in this version of the app.
''';
      final readmeFile = File("${exportDir.path}/README.md");
      await readmeFile.writeAsString(readmeContent);

      // Create zip archive
      final archive = Archive();

      // Add all files to the archive
      await for (var entity in exportDir.list(recursive: true)) {
        if (entity is File) {
          final fileName = entity.path.replaceFirst('${exportDir.path}/', '');
          final fileBytes = await entity.readAsBytes();
          final archiveFile = ArchiveFile(fileName, fileBytes.length, fileBytes);
          archive.addFile(archiveFile);
        }
      }

      // Encode the archive as a zip
      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);

      // Save the zip file
      final zipFileName = 'sleep_data_export_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now())}.zip';
      final zipFile = File("${directory.path}/$zipFileName");
      await zipFile.writeAsBytes(zipData);
      print('Zip file created: ${zipFile.path}');

      // Share the zip file
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(zipFile.path)], 
          text: 'Here is your sleep data export as a zip file.'
          )
        );

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting CSV: $e. Note that use of temp directory does not work on web app.')),
        );
      }
    }
  }
}
