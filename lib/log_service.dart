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

// Add persistent time for daily reminder

Future<void> setSleepReminderTime(TimeOfDay time) async {
  await _prefs.setInt('sleep_reminder_hour', time.hour);
  await _prefs.setInt('sleep_reminder_minute', time.minute);
}

Future<void> clearSleepReminderTime() async {
    await _prefs.remove('sleep_reminder_hour');
    await _prefs.remove('sleep_reminder_minute');
  }

TimeOfDay? get sleepReminderTime {
  final hour = _prefs.getInt('sleep_reminder_hour');
  final minute = _prefs.getInt('sleep_reminder_minute');
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

// --- USER NAME-----
  String get userName => _prefs.getString('user_name') ?? 'Patient';

  Future<void> setUserName(String name) async {
    await _prefs.setString('user_name', name);
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
      final medicationTypes = await CategoryManager().getCategories('medication_types');
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
      

      // 2. Sleep Log (Updated: Explicit Dates + Sleep Location ID)
      List<List<dynamic>> sleepRows = [];
      sleepRows.add([
        "Date", "Bed Date", "Bed Time", "Fell Asleep Date", "Fell Asleep Time", 
        "Wake Date", "Wake Time", "Out Of Bed Date", "Out Of Bed Time", 
        "Sleep Duration (Hrs)", "Sleep Latency Mins", "Awakenings Count", 
        "Awake Duration Mins", "Sleep Location"
      ]);

      for (var date in sortedKeys) {
        final log = allLogs[date]!;
        String dateStr = DateFormat('yyyy-MM-dd').format(date);

        for (var entry in log.sleepLog) {
          String d(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);
          String t(DateTime dt) => DateFormat('HH:mm').format(dt);

          List<dynamic> row = [];
          row.add(dateStr); // 0
          
          // Times
          row.add(d(entry.bedTime)); // 1
          row.add(t(entry.bedTime)); // 2
          row.add(d(entry.fellAsleepTime)); // 3
          row.add(t(entry.fellAsleepTime)); // 4
          row.add(d(entry.wakeTime)); // 5
          row.add(t(entry.wakeTime)); // 6
          
          if (entry.outOfBedTime != null) {
            row.add(d(entry.outOfBedTime!)); // 7
            row.add(t(entry.outOfBedTime!)); // 8
          } else {
            row.add("");
            row.add("");
          }

          // Metrics
          double duration = entry.wakeTime.difference(entry.fellAsleepTime).inMinutes / 60.0;
          duration -= (entry.awakeDurationMinutes / 60.0);
          int latency = entry.fellAsleepTime.difference(entry.bedTime).inMinutes;

          row.add(duration.toStringAsFixed(2)); // 9
          row.add(latency); // 10
          row.add(entry.awakeningsCount); // 11
          row.add(entry.awakeDurationMinutes); // 12
          
          // FIX: Export the ID (e.g., 'couch'), NOT the Name (e.g. 'Couch')
          row.add(entry.sleepLocationId); // 13

          sleepRows.add(row);
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
      medicationRows.add(["Date", "Medication Name", "Medication ID", "Dosage", "Time"]);
      for (var date in sortedKeys) {
        final log = allLogs[date]!;
        for (var entry in log.medicationLog) {
          final cat = medicationTypes.where((c) => c.id == entry.medicationTypeId).firstOrNull;
          final displayName = cat?.name ?? entry.medicationTypeId;
          medicationRows.add([
            DateFormat('yyyy-MM-dd').format(date),
            displayName,
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
      final name = userName.trim();
      final finname = name.isNotEmpty ? name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_') : 'Patient';

      final zipFileName = 'sleep_data_${finname}_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now())}.zip';
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
  // --- IMPORT DATA (CSV or ZIP) ---
  // ---------------------------------------------------------------------------

  Future<void> importData(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'zip'], // Allow ZIPs now!
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String extension = result.files.single.extension?.toLowerCase() ?? '';
        int importCount = 0;

        // 1. Handle ZIP Import
        if (extension == 'zip') {
          importCount = await _importFromZip(file);
        } 
        // 2. Handle Single CSV Import
        else if (extension == 'csv') {
          final input = await file.readAsString();
          final List<List<dynamic>> rows = const CsvToListConverter().convert(input);
          importCount = await _dispatchImport(rows, file.uri.pathSegments.last);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Import complete. Processed $importCount entries.')),
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

  // --- ZIP HANDLER ---
  Future<int> _importFromZip(File zipFile) async {
    int count = 0;
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // We must separate files to ensure Categories are imported BEFORE Logs
    final List<ArchiveFile> categoryFiles = [];
    final List<ArchiveFile> logFiles = [];

    for (final file in archive) {
      if (!file.isFile) continue;
      final filename = file.name.toLowerCase();
      if (!filename.endsWith('.csv')) continue;

      // Identify Category definitions
      if (filename.contains('day_types') || 
          filename.contains('sleep_locations') || 
          filename.contains('medication_types') || 
          filename.contains('exercise_types') || 
          filename.contains('substance_types')) {
        categoryFiles.add(file);
      } else {
        logFiles.add(file);
      }
    }

    // PHASE 1: Import Categories
    for (final file in categoryFiles) {
      count += await _processArchiveFile(file);
    }

    // PHASE 2: Import Logs
    for (final file in logFiles) {
      count += await _processArchiveFile(file);
    }

    return count;
  }

  Future<int> _processArchiveFile(ArchiveFile file) async {
    try {
      final content = utf8.decode(file.content as List<int>);
      final rows = const CsvToListConverter().convert(content);
      return await _dispatchImport(rows, file.name);
    } catch (e) {
      debugPrint("Error processing zip file ${file.name}: $e");
      return 0;
    }
  }

  // --- THE BOUNCER (Dispatcher) ---
  // Decides which import method to use based on headers
  Future<int> _dispatchImport(List<List<dynamic>> rows, String filename) async {
    if (rows.isEmpty) return 0;
    final headers = rows.first.map((e) => e.toString().trim()).toList();

    // 1. Main Daily Log (FIXED: Added this check)
    if (headers.contains('Day Type') && headers.contains('Notes')) {
      return await _importMainDailyLog(rows);
    }
    // 2. Sleep Log
    else if (headers.contains('Bed Time') && headers.contains('Fell Asleep Time')) {
      return await _importSleepLog(rows);
    } 
    // 3. Medication Log (FIXED: Checks 'Medication Name' OR 'Medication Type')
    else if ((headers.contains('Medication Name') || headers.contains('Medication Type')) && headers.contains('Dosage')) {
      return await _importMedicationLog(rows);
    } 
    // 4. Substance Log
    else if (headers.contains('Substance Type') && headers.contains('Amount')) {
      return await _importSubstanceLog(rows);
    } 
    // 5. Exercise Log
    else if (headers.contains('Exercise Type')) { 
      return await _importExerciseLog(rows);
    }
    // 6. User Categories (Fallback to filename check)
    else if (headers.contains('iconName') && headers.contains('colorHex')) {
      String name = filename.toLowerCase();
      if (name.contains('day_type')) return await _importUserCategories(rows, 'day_types');
      if (name.contains('sleep_location')) return await _importUserCategories(rows, 'sleep_locations');
      if (name.contains('medication_type')) return await _importUserCategories(rows, 'medication_types');
      if (name.contains('exercise_type')) return await _importUserCategories(rows, 'exercise_types');
      if (name.contains('substance_type')) return await _importUserCategories(rows, 'substance_types');
    }
    
    return 0;
  }

  // --- IMPORTERS ---

  // NEW: Main Daily Log Importer
  Future<int> _importMainDailyLog(List<List<dynamic>> rows) async {
    int count = 0;
    final dayTypes = await CategoryManager().getCategories('day_types');

    for (int i = 1; i < rows.length; i++) {
      var row = rows[i];
      if (row.length < 2) continue;

      try {
        DateTime date = DateTime.parse(row[0].toString().trim());
        DateTime utcDate = DateTime.utc(date.year, date.month, date.day);
        DailyLog log = await getDailyLog(utcDate);

        // Restore Day Type
        String dayTypeName = row[1].toString().trim();
        if (dayTypeName.isNotEmpty) {
          // Fix: Use .where().firstOrNull for Dart 3 compatibility
          final matchedCategory = dayTypes.where(
            (c) => c.name.toLowerCase() == dayTypeName.toLowerCase()
          ).firstOrNull;
          
          if (matchedCategory != null) {
            log.dayTypeId = matchedCategory.id;
          }
        }

        // Restore Notes (Index 8 in export structure)
        if (row.length > 8) {
          String notes = row[8].toString().trim();
          if (notes.isNotEmpty) log.notes = notes;
        }

        await saveDailyLog(utcDate, log);
        count++;
      } catch (e) {
        debugPrint("Error importing main log row $i: $e");
      }
    }
    return count;
  }

  // Helper: Same Minute Check for Deduplication
  bool _isSameMinute(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day &&
           a.hour == b.hour && a.minute == b.minute;
  }

  int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    return int.tryParse(val.toString().trim()) ?? 0;
  }

  Future<int> _importUserCategories(List<List<dynamic>> rows, String categoryType) async {
    int count = 0;
    List<Category> existing = await CategoryManager().getCategories(categoryType);
    
    for (int i = 1; i < rows.length; i++) {
      var row = rows[i];
      if (row.length < 4) continue; 
      
      try {
        String id = row[0].toString().trim();
        String name = row[1].toString().trim();
        String iconName = row[2].toString().trim();
        String colorHex = row[3].toString().trim();
        int? defaultDosage;
        if (row.length > 4 && row[4].toString().trim().isNotEmpty) {
           defaultDosage = int.tryParse(row[4].toString().trim());
        }

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
    if (rows.isEmpty) return 0;

    // Load Sleep Locations to fix the "Name vs ID" bug
    final sleepLocations = await CategoryManager().getCategories('sleep_locations');

    // Detect Format
    final headers = rows.first.map((e) => e.toString().trim()).toList();
    bool isNewFormat = headers.contains('Bed Date');

    for (int i = 1; i < rows.length; i++) {
      var row = rows[i];
      if (row.length < 5) continue;
      try {
        DateTime date = DateTime.parse(row[0].toString().trim());
        DateTime utcDate = DateTime.utc(date.year, date.month, date.day);
        DailyLog log = await getDailyLog(utcDate);

        SleepEntry newEntry;
        String rawLocation = 'bed'; // Default

        // --- SMART LOCATION LOOKUP ---
        // Helper to Convert Name -> ID
        String resolveLocationId(dynamic raw) {
          String val = raw.toString().trim();
          if (val.isEmpty) return 'bed';
          
          // 1. Try to find by ID (Exact match)
          var match = sleepLocations.where((c) => c.id == val).firstOrNull;
          if (match != null) return match.id;

          // 2. Try to find by Name (Case-insensitive match for legacy files)
          // e.g. CSV has "In Transit" -> matches category ID "transport"
          match = sleepLocations.where((c) => c.name.toLowerCase() == val.toLowerCase()).firstOrNull;
          if (match != null) return match.id;

          // 3. Fallback: Use the value as-is (maybe it's a custom ID)
          return val;
        }

        if (isNewFormat) {
          // NEW FORMAT (Index 13 is Location)
          DateTime parseDT(String d, String t) => DateTime.parse("${d.trim()} ${t.trim()}");

          DateTime bed = parseDT(row[1].toString(), row[2].toString());
          DateTime asleep = parseDT(row[3].toString(), row[4].toString());
          DateTime wake = parseDT(row[5].toString(), row[6].toString());
          
          DateTime? out;
          if (row.length > 8 && row[7].toString().trim().isNotEmpty && row[8].toString().trim().isNotEmpty) {
             out = parseDT(row[7].toString(), row[8].toString());
          }
          
          if (row.length > 13) rawLocation = row[13];

          newEntry = SleepEntry(
            bedTime: bed,
            fellAsleepTime: asleep,
            wakeTime: wake,
            outOfBedTime: out,
            sleepLocationId: resolveLocationId(rawLocation), // SMART LOOKUP
            awakeningsCount: row.length > 11 ? _parseInt(row[11]) : 0,
            awakeDurationMinutes: row.length > 12 ? _parseInt(row[12]) : 0,
          );

        } else {
          // LEGACY FORMAT (Index 9 is Location)
          DateTime makeDateTime(String t) {
             t = t.trim();
             if (t.isEmpty) return date; 
             final p = t.split(':');
             int h = int.parse(p[0]);
             int m = int.parse(p[1]);
             return DateTime(date.year, date.month, date.day, h, m);
          }

          DateTime bed = makeDateTime(row[1].toString());
          DateTime asleep = makeDateTime(row[2].toString());
          DateTime wake = makeDateTime(row[3].toString());
          DateTime? out = row[4].toString().trim().isNotEmpty ? makeDateTime(row[4].toString()) : null;

          // Robust crossover logic
          if (asleep.isBefore(bed)) {
            asleep = asleep.add(const Duration(days: 1));
          }
          
          while (wake.isBefore(asleep)) {
            wake = wake.add(const Duration(days: 1));
          }
          
          if (out != null) {
            while (out!.isBefore(wake)) {
              out = out.add(const Duration(days: 1));
            }
          }
          
          if (row.length > 9) rawLocation = row[9];

          newEntry = SleepEntry(
            bedTime: bed,
            fellAsleepTime: asleep,
            wakeTime: wake,
            outOfBedTime: out,
            sleepLocationId: resolveLocationId(rawLocation), // SMART LOOKUP
            awakeningsCount: row.length > 7 ? _parseInt(row[7]) : 0,
            awakeDurationMinutes: row.length > 8 ? _parseInt(row[8]) : 0,
          );
        }

        // Deduplication
        bool exists = log.sleepLog.any((e) =>
          e.bedTime.year == newEntry.bedTime.year &&
          e.bedTime.minute == newEntry.bedTime.minute &&
          e.wakeTime.minute == newEntry.wakeTime.minute
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
        String medType;
        String dosage;
        DateTime time;
        if (row.length == 5) {
           medType = row[2].toString().trim();
           dosage = row[3].toString().trim();
           final parts = row[4].toString().trim().split(':');
           time = DateTime(date.year, date.month, date.day, int.parse(parts[0]), int.parse(parts[1]));
        } else {
           medType = row[1].toString().trim();
           dosage = row[2].toString().trim();
           final parts = row[3].toString().trim().split(':');
           time = DateTime(date.year, date.month, date.day, int.parse(parts[0]), int.parse(parts[1]));
        }
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