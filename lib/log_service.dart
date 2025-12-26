import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'models.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- THEME PERSISTENCE ---
  bool get isDarkMode => _prefs.getBool('is_dark_mode') ?? false;

  Future<void> setDarkMode(bool value) async {
    await _prefs.setBool('is_dark_mode', value);
  }

  // --- NOTIFICATION PERSISTENCE ---
  bool get areNotificationsEnabled => _prefs.getBool('notifications_enabled') ?? true;

  Future<void> setNotificationsEnabled(bool value) async {
    await _prefs.setBool('notifications_enabled', value);
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
        // ignore error
      }
    }
    return allLogs;
  }

  Future<void> clearAllData() async {
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('log_')) {
        await _prefs.remove(key);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // --- EXPORT TO CSV (Multiple Files) ---
  // ---------------------------------------------------------------------------

  Future<void> exportToCsv(BuildContext context) async {
    try {
      final Map<DateTime, DailyLog> allLogs = await getAllLogs();
      final directory = await getTemporaryDirectory();
      final exportDir = Directory("${directory.path}/sleep_data_export");
      
      // Clean up previous exports
      if (await exportDir.exists()) {
        await exportDir.delete(recursive: true);
      }
      await exportDir.create(recursive: true);

      final categoryLogsDir = Directory("${exportDir.path}/category_logs");
      await categoryLogsDir.create();

      final userCategoriesDir = Directory("${exportDir.path}/user_categories");
      await userCategoriesDir.create();

      final sortedKeys = allLogs.keys.toList()..sort();
      final dayTypes = await CategoryManager().getCategories('day_types');

      // 1. Main Daily Log
      List<List<dynamic>> mainRows = [];
      mainRows.add([
        "Date", "Day Type", "Total Sleep (Hrs)", "Sleep Latency (Mins)", 
        "Awakenings (Count)", "Awake Duration (Mins)", "Out Of Bed Time", 
        "Sleep Sessions Detail", "Notes", "Substance Log", "Medication Log", "Exercise Log"
      ]);

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
          return "${DateFormat('HH:mm').format(e.bedTime)}-${DateFormat('HH:mm').format(e.wakeTime)}";
        }).join(" | ");

        String substanceStr = log.substanceLog.map((e) => "${e.name} ${e.amount}").join(" | ");
        String medsStr = log.medicationLog.map((e) => "${e.medicationTypeId} ${e.dosage}").join(" | ");
        String exerciseStr = log.exerciseLog.map((e) => e.type).join(" | ");

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
      await File("${exportDir.path}/main_daily_log.csv").writeAsString(mainCsvData);

      // 2. Sleep Log
      List<List<dynamic>> sleepRows = [];
      sleepRows.add(["Date", "Bed Time", "Fell Asleep Time", "Wake Time", "Out Of Bed Time", "Sleep Location", "Sleep Latency Mins", "Awakenings Count", "Awake Duration Mins"]);
      for (var date in sortedKeys) {
        final log = allLogs[date]!;
        for (var entry in log.sleepLog) {
          sleepRows.add([
            DateFormat('yyyy-MM-dd').format(date),
            DateFormat('HH:mm').format(entry.bedTime),
            DateFormat('HH:mm').format(entry.fellAsleepTime),
            DateFormat('HH:mm').format(entry.wakeTime),
            entry.outOfBedTime != null ? DateFormat('HH:mm').format(entry.outOfBedTime!) : "",
            entry.sleepLocationId ?? 'bed',
            entry.sleepLatencyMinutes,
            entry.awakeningsCount,
            entry.awakeDurationMinutes,
          ]);
        }
      }
      String sleepCsvData = const ListToCsvConverter().convert(sleepRows);
      await File("${categoryLogsDir.path}/sleep_log.csv").writeAsString(sleepCsvData);

      // 3. Substance Log
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
      await File("${categoryLogsDir.path}/substance_log.csv").writeAsString(substanceCsvData);

      // 4. Medication Log
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
      await File("${categoryLogsDir.path}/medication_log.csv").writeAsString(medicationCsvData);

      // 5. Exercise Log
      List<List<dynamic>> exerciseRows = [];
      exerciseRows.add(["Date", "Exercise Type", "Start Time", "Finish Time", "Duration Mins"]);
      for (var date in sortedKeys) {
        final log = allLogs[date]!;
        for (var entry in log.exerciseLog) {
          exerciseRows.add([
            DateFormat('yyyy-MM-dd').format(date),
            entry.exerciseTypeId,
            DateFormat('HH:mm').format(entry.startTime),
            DateFormat('HH:mm').format(entry.finishTime),
            entry.finishTime.difference(entry.startTime).inMinutes
          ]);
        }
      }
      String exerciseCsvData = const ListToCsvConverter().convert(exerciseRows);
      await File("${categoryLogsDir.path}/exercise_log.csv").writeAsString(exerciseCsvData);

      // 6. User Categories
      final categoryTypes = ['day_types', 'sleep_locations', 'medication_types', 'exercise_types', 'substance_types'];
      for (var type in categoryTypes) {
        final categories = await CategoryManager().getCategories(type);
        List<List<dynamic>> catRows = [];
        catRows.add(["id", "name", "iconName", "colorHex", "defaultDosage"]);
        for (var cat in categories) {
          catRows.add([cat.id, cat.name, cat.iconName, cat.colorHex, cat.defaultDosage?.toString() ?? ""]);
        }
        String catCsvData = const ListToCsvConverter().convert(catRows);
        await File("${userCategoriesDir.path}/$type.csv").writeAsString(catCsvData);
      }

      // 7. README
      const readmeContent = '''
# Sleep Data Export
- main_daily_log.csv: Summary.
- category_logs/: Detailed entries.
- user_categories/: Category definitions.
''';
      await File("${exportDir.path}/README.md").writeAsString(readmeContent);

      // 8. Share
      final files = <XFile>[];
      await for (var entity in exportDir.list(recursive: true)) {
        if (entity is File) files.add(XFile(entity.path));
      }

      await Share.shareXFiles(files, text: 'Your Sleep Tracker Data (CSV format)');

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting CSV: $e')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // --- IMPORT FROM CSV ---
  // ---------------------------------------------------------------------------

  Future<void> importFromCsv(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        final input = await file.readAsString();
        final List<List<dynamic>> rows = const CsvToListConverter().convert(input, eol: '\n');

        if (rows.isEmpty) throw Exception("Empty file");

        final headers = rows.first.map((e) => e.toString().trim()).toList();
        int importCount = 0;

        // Determine File Type
        if (headers.contains('Bed Time') && headers.contains('Fell Asleep Time')) {
          importCount = await _importSleepLog(rows);
        } else if (headers.contains('Medication Type') && headers.contains('Dosage')) {
          importCount = await _importMedicationLog(rows);
        } else if (headers.contains('Substance Type') && headers.contains('Amount')) {
          importCount = await _importSubstanceLog(rows);
        } else if (headers.contains('Exercise Type') && headers.contains('Duration Mins')) {
          importCount = await _importExerciseLog(rows);
        } else {
          throw Exception("Unknown CSV format. Use specific logs like sleep_log.csv.");
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported $importCount new entries.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- Helper: Same Minute Check for Deduplication ---
  bool _isSameMinute(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day &&
           a.hour == b.hour && a.minute == b.minute;
  }

  Future<int> _importSleepLog(List<List<dynamic>> rows) async {
    int count = 0;
    for (int i = 1; i < rows.length; i++) {
      var row = rows[i];
      if (row.length < 5) continue;
      try {
        DateTime date = DateTime.parse(row[0].toString().trim());
        DateTime utcDate = DateTime.utc(date.year, date.month, date.day);
        DailyLog log = await getDailyLog(utcDate);
        
        DateTime parseT(String t) {
             t = t.trim();
             if (t.isEmpty) return date; 
             final p = t.split(':');
             return DateTime(date.year, date.month, date.day, int.parse(p[0]), int.parse(p[1]));
        }

        DateTime bed = parseT(row[1].toString());
        DateTime asleep = parseT(row[2].toString());
        DateTime wake = parseT(row[3].toString());
        DateTime? out = row[4].toString().trim().isNotEmpty ? parseT(row[4].toString()) : null;

        // Fix rollovers for display times
        if (asleep.isBefore(bed)) asleep = asleep.add(const Duration(days: 1));
        if (wake.isBefore(asleep)) wake = wake.add(const Duration(days: 1));
        if (out != null && out.isBefore(wake)) out = out.add(const Duration(days: 1));

        SleepEntry newEntry = SleepEntry(
          bedTime: bed,
          fellAsleepTime: asleep,
          wakeTime: wake,
          outOfBedTime: out,
          sleepLocationId: row.length > 5 ? row[5].toString().trim() : 'bed',
          awakeningsCount: row.length > 7 ? (row[7] as num).toInt() : 0,
          awakeDurationMinutes: row.length > 8 ? (row[8] as num).toInt() : 0,
        );

        // Check for duplicates (same bed/wake/asleep time down to the minute)
        bool exists = log.sleepLog.any((e) =>
          _isSameMinute(e.bedTime, newEntry.bedTime) &&
          _isSameMinute(e.wakeTime, newEntry.wakeTime) &&
          _isSameMinute(e.fellAsleepTime, newEntry.fellAsleepTime)
        );

        if (!exists) {
          log.sleepLog.add(newEntry);
          await saveDailyLog(utcDate, log);
          count++;
        }
      } catch (_) {}
    }
    return count;
  }

  Future<int> _importMedicationLog(List<List<dynamic>> rows) async {
    int count = 0;
    for (int i = 1; i < rows.length; i++) {
      var row = rows[i];
      try {
        DateTime date = DateTime.parse(row[0].toString().trim());
        DateTime utcDate = DateTime.utc(date.year, date.month, date.day);
        
        final parts = row[3].toString().trim().split(':');
        DateTime time = DateTime(date.year, date.month, date.day, int.parse(parts[0]), int.parse(parts[1]));
        
        String medType = row[1].toString().trim();
        String dosage = row[2].toString().trim();

        DailyLog log = await getDailyLog(utcDate);
        
        // Deduplicate
        bool exists = log.medicationLog.any((e) => 
           e.medicationTypeId == medType && 
           e.dosage == dosage && 
           _isSameMinute(e.time, time)
        );

        if (!exists) {
          log.medicationLog.add(MedicationEntry(
            medicationTypeId: medType, 
            dosage: dosage, 
            time: time
          ));
          await saveDailyLog(utcDate, log);
          count++;
        }
      } catch (_) {}
    }
    return count;
  }

  Future<int> _importSubstanceLog(List<List<dynamic>> rows) async {
    int count = 0;
    for (int i = 1; i < rows.length; i++) {
      var row = rows[i];
      try {
        DateTime date = DateTime.parse(row[0].toString().trim());
        DateTime utcDate = DateTime.utc(date.year, date.month, date.day);
        
        final parts = row[3].toString().trim().split(':');
        DateTime time = DateTime(date.year, date.month, date.day, int.parse(parts[0]), int.parse(parts[1]));
        
        String subType = row[1].toString().trim();
        String amount = row[2].toString().trim();

        DailyLog log = await getDailyLog(utcDate);
        
        bool exists = log.substanceLog.any((e) => 
           e.substanceTypeId == subType && 
           e.amount == amount && 
           _isSameMinute(e.time, time)
        );

        if (!exists) {
          log.substanceLog.add(SubstanceEntry(
            substanceTypeId: subType, 
            amount: amount, 
            time: time
          ));
          await saveDailyLog(utcDate, log);
          count++;
        }
      } catch (_) {}
    }
    return count;
  }

  Future<int> _importExerciseLog(List<List<dynamic>> rows) async {
    int count = 0;
    for (int i = 1; i < rows.length; i++) {
      var row = rows[i];
      try {
        DateTime date = DateTime.parse(row[0].toString().trim());
        DateTime utcDate = DateTime.utc(date.year, date.month, date.day);
        
        final startP = row[2].toString().trim().split(':');
        final endP = row[3].toString().trim().split(':');
        DateTime start = DateTime(date.year, date.month, date.day, int.parse(startP[0]), int.parse(startP[1]));
        DateTime end = DateTime(date.year, date.month, date.day, int.parse(endP[0]), int.parse(endP[1]));
        if (end.isBefore(start)) end = end.add(const Duration(days: 1));

        String exType = row[1].toString().trim();

        DailyLog log = await getDailyLog(utcDate);

        bool exists = log.exerciseLog.any((e) => 
           e.exerciseTypeId == exType && 
           _isSameMinute(e.startTime, start) &&
           _isSameMinute(e.finishTime, end)
        );

        if (!exists) {
          log.exerciseLog.add(ExerciseEntry(
            exerciseTypeId: exType, 
            startTime: start, 
            finishTime: end
          ));
          await saveDailyLog(utcDate, log);
          count++;
        }
      } catch (_) {}
    }
    return count;
  }
}