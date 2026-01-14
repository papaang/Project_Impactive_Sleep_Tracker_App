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
import 'package:archive/archive.dart';

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
        "Sleep Sessions Total", "Notes",   "Caffeine Total (Cups)",
        "Meds Log Total (Entries)",
        "Exercise Total (Mins)"
      ]);
      

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

        
        //String substanceStr = log.substanceLog.map((e) => "${e.name} ${e.amount}").join(" | ");
        int caffeineTotal = log.substanceLog.where((e) => e.substanceTypeId == 'coffee').fold(0, (sum, e) => sum + (int.tryParse(e.amount) ?? 0));
        //String medsStr = log.medicationLog.map((e) => "${e.medicationTypeId} ${e.dosage}").join(" | ");
        int medsLogTotal = log.medicationLog.length;
        //String exerciseStr = log.exerciseLog.map((e) => e.type).join(" | ");

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
      await mainFile.writeAsString('\uFEFF$mainCsvData'); //this is for reading emojis. restore old version (next line) if issues
      //await mainFile.writeAsString(mainCsvData);
      

      // 2. Sleep Log
      List<List<dynamic>> sleepRows = [];
      sleepRows.add(["Date", "Bed Time", "Fell Asleep Time", "Wake Time", "Out Of Bed Time", "Sleep Duration (Hrs)", "Sleep Latency Mins", "Awakenings Count", "Awake Duration Mins", "Sleep Location"]);
      for (var date in sortedKeys) {
        final log = allLogs[date]!;
        for (var entry in log.sleepLog) {
          int totalMinutes = (entry.durationHours * 60).round();
          int hrs = totalMinutes ~/ 60;
          int mins = totalMinutes % 60;
          String sleepDuration = "${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}";

          sleepRows.add([
            DateFormat('yyyy-MM-dd').format(date),
            DateFormat('HH:mm').format(entry.bedTime),
            DateFormat('HH:mm').format(entry.fellAsleepTime),
            DateFormat('HH:mm').format(entry.wakeTime),
            entry.outOfBedTime != null ? DateFormat('HH:mm').format(entry.outOfBedTime!) : "",
            sleepDuration,
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
      final substanceFile = File("${categoryLogsDir.path}/substance_log.csv");
      await substanceFile.writeAsString(substanceCsvData);


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
         final catFile = File("${userCategoriesDir.path}/$type.csv");
        await catFile.writeAsString(catCsvData);
      }

      // 7. README
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

      //// Create zip archive
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
      // print('Zip file created: ${zipFile.path}');

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
        // Remove 'eol' to allow auto-detection of \n or \r\n
        final List<List<dynamic>> rows = const CsvToListConverter().convert(input);

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
        } else if (headers.contains('Exercise Type')) { // 'Duration Mins' might not be in some exports
          importCount = await _importExerciseLog(rows);}
          else if (headers.contains('iconName') && headers.contains('colorHex')) {
            String fileName = file.uri.pathSegments.last.toLowerCase();
            String? categoryType;
           
            if (fileName.contains('day_type')) {
              categoryType = 'day_types';
            } else if (fileName.contains('sleep_location')) {
              categoryType = 'sleep_locations';
            } else if (fileName.contains('medication_type')) {
              categoryType = 'medication_types';
            } else if (fileName.contains('exercise_type')) {
              categoryType = 'exercise_types';
            } else if (fileName.contains('substance_type')) {
              categoryType = 'substance_types';
            }

            if (categoryType != null) {
                importCount = await _importUserCategories(rows, categoryType);
            } else {
                throw Exception("Could not determine category type from filename '${file.uri.pathSegments.last}'. Please use files like 'day_types.csv'.");
            }
        } else {
          throw Exception("Unknown CSV format. Please import sleep_log.csv, medication_log.csv, etc.");
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

  // Helper to safely parse numbers from CSV (which might be strings or ints)
  int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    return int.tryParse(val.toString().trim()) ?? 0;
  }
   Future<int> _importUserCategories(List<List<dynamic>> rows, String categoryType) async {
    int count = 0;
    List<Category> existing = await CategoryManager().getCategories(categoryType);
    
    // Skip header (i=1)
    for (int i = 1; i < rows.length; i++) {
      var row = rows[i];
      if (row.length < 4) continue; // id, name, icon, color required
      
      try {
        String id = row[0].toString().trim();
        String name = row[1].toString().trim();
        String iconName = row[2].toString().trim();
        String colorHex = row[3].toString().trim();
        int? defaultDosage;
        if (row.length > 4 && row[4].toString().trim().isNotEmpty) {
           defaultDosage = int.tryParse(row[4].toString().trim());
        }

        // Deduplicate by ID
        if (!existing.any((c) => c.id == id)) {
           existing.add(Category(
             id: id,
             name: name,
             iconName: iconName,
             colorHex: colorHex,
             defaultDosage: defaultDosage
           ));
           count++;
        }
      } catch (e) {
        debugPrint("Error importing category row $i: $e");
      }
    }
    
    if (count > 0) {
      await CategoryManager().saveCategories(categoryType, existing);
    }
    return count;
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
             // Handle "8:05" vs "08:05"
             int h = int.parse(p[0]);
             int m = int.parse(p[1]);
             
             // Construct on log date initially
             DateTime dt = DateTime(date.year, date.month, date.day, h, m);
             
             // Heuristic: If time is between 00:00 and 16:00 (4pm), assume it belongs to Next Day
             // This is because the Log Date represents the "Night Of".
             // E.g. Log Date: Nov 22. Bed Time: 01:00 (am). This means Nov 23 01:00.
             if (h < 16) {
               dt = dt.add(const Duration(days: 1));
             }
             return dt;
        }

        DateTime bed = parseT(row[1].toString());
        DateTime asleep = parseT(row[2].toString());
        DateTime wake = parseT(row[3].toString());
        DateTime? out = row[4].toString().trim().isNotEmpty ? parseT(row[4].toString()) : null;

        // Ensure logical order if parsing failed or heuristic failed
        // e.g. Asleep before Bed? Add day to Asleep.
        if (asleep.isBefore(bed)) asleep = asleep.add(const Duration(days: 1));
        if (wake.isBefore(asleep)) wake = wake.add(const Duration(days: 1));
        if (out != null && out.isBefore(wake)) out = out.add(const Duration(days: 1));

        SleepEntry newEntry = SleepEntry(
          bedTime: bed,
          fellAsleepTime: asleep,
          wakeTime: wake,
          outOfBedTime: out,
          // Handle dynamic row length safely
          sleepLocationId: row.length > 9 ? row[9].toString().trim() : 'bed', 
          // Use helper to parse ints safely from CSV cells
          awakeningsCount: row.length > 7 ? _parseInt(row[7]) : 0,
          awakeDurationMinutes: row.length > 8 ? _parseInt(row[8]) : 0,
        );

        // Check for duplicates
        bool exists = log.sleepLog.any((e) =>
          _isSameMinute(e.bedTime, newEntry.bedTime) &&
          _isSameMinute(e.wakeTime, newEntry.wakeTime)
        );

        if (!exists) {
          log.sleepLog.add(newEntry);
          await saveDailyLog(utcDate, log);
          count++;
        }
      } catch (e) {
        debugPrint("Error import sleep row $i: $e");
      }
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
        
        // Parse time column (Index 3)
        final timeStr = row[3].toString().trim();
        final parts = timeStr.split(':');
        DateTime time = DateTime(date.year, date.month, date.day, int.parse(parts[0]), int.parse(parts[1]));
        
        String medType = row[1].toString().trim();
        String dosage = row[2].toString().trim();

        DailyLog log = await getDailyLog(utcDate);
        
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
        
        final timeStr = row[3].toString().trim();
        final parts = timeStr.split(':');
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
      if (row.length < 4) continue;
      try {
        DateTime date = DateTime.parse(row[0].toString().trim());
        DateTime utcDate = DateTime.utc(date.year, date.month, date.day);
        
        String exType = row[1].toString().trim();
        
        final startP = row[2].toString().trim().split(':');
        final endP = row[3].toString().trim().split(':');
        DateTime start = DateTime(date.year, date.month, date.day, int.parse(startP[0]), int.parse(startP[1]));
        DateTime end = DateTime(date.year, date.month, date.day, int.parse(endP[0]), int.parse(endP[1]));
        if (end.isBefore(start)) end = end.add(const Duration(days: 1));

        DailyLog log = await getDailyLog(utcDate);

        bool exists = log.exerciseLog.any((e) => 
           e.exerciseTypeId.toLowerCase() == exType.toLowerCase() && 
           _isSameMinute(e.startTime, start) &&
           _isSameMinute(e.finishTime, end) &&
           e.finishTime.difference(e.startTime).inMinutes == end.difference(start).inMinutes
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