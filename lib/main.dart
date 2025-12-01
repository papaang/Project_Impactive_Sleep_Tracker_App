import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';

// -------------------------------------------------------------------
// --- 1. Enums and Data Models ---
// -------------------------------------------------------------------

enum DayType {
  work,
  relax,
  travel,
  social,
  other;

  String get displayName {
    switch (this) {
      case DayType.work: return 'Work';
      case DayType.relax: return 'Relax';
      case DayType.travel: return 'Travel';
      case DayType.social: return 'Social';
      case DayType.other: default: return 'Other';
    }
  }

  Color get color {
    switch (this) {
      case DayType.work: return Colors.blue[800]!;
      case DayType.relax: return Colors.green[800]!;
      case DayType.travel: return Colors.orange[800]!;
      case DayType.social: return Colors.purple[800]!;
      case DayType.other: default: return Colors.grey[700]!;
    }
  }

  IconData get icon {
    switch (this) {
      case DayType.work: return Icons.work_outline;
      case DayType.relax: return Icons.self_improvement_outlined;
      case DayType.travel: return Icons.explore_outlined;
      case DayType.social: return Icons.people_outline;
      case DayType.other: default: return Icons.wb_sunny_outlined;
    }
  }

  static DayType? fromString(String? typeString) {
    if (typeString == null) return null;
    for (DayType type in DayType.values) {
      if (type.name == typeString) return type;
    }
    return null;
  }
}

class SubstanceEntry {
  String name;
  String amount;
  DateTime time;

  SubstanceEntry({required this.name, required this.amount, required this.time});

  Map<String, dynamic> toJson() => {'name': name, 'amount': amount, 'time': time.toIso8601String()};
  factory SubstanceEntry.fromJson(Map<String, dynamic> json) => SubstanceEntry(
    name: json['name'] ?? 'Coffee', amount: json['amount'], time: DateTime.parse(json['time']));
}

class MedicationEntry {
  String type;
  String dosage;
  DateTime time;
  MedicationEntry({required this.type, required this.dosage, required this.time});
  Map<String, dynamic> toJson() => {'type': type, 'dosage': dosage, 'time': time.toIso8601String()};
  factory MedicationEntry.fromJson(Map<String, dynamic> json) => MedicationEntry(
        type: json['type'], dosage: json['dosage'] ?? 'N/A', time: DateTime.parse(json['time']));
}

class ExerciseEntry {
  String type;
  DateTime startTime;
  DateTime finishTime;
  ExerciseEntry({required this.type, required this.startTime, required this.finishTime});
  Map<String, dynamic> toJson() => {
        'type': type,
        'startTime': startTime.toIso8601String(),
        'finishTime': finishTime.toIso8601String()
      };
  factory ExerciseEntry.fromJson(Map<String, dynamic> json) {
    if (json['startTime'] == null || json['finishTime'] == null) {
      throw FormatException("Missing time data in exercise entry");
    }
    return ExerciseEntry(
        type: json['type'],
        startTime: DateTime.parse(json['startTime']),
        finishTime: DateTime.parse(json['finishTime']));
  }
}

class SleepEntry {
  DateTime bedTime;
  DateTime wakeTime;
  DateTime fellAsleepTime;
  DateTime? outOfBedTime;
  
  int awakeningsCount;
  int awakeDurationMinutes;

  SleepEntry({
    required this.bedTime,
    required this.wakeTime,
    required this.fellAsleepTime,
    this.outOfBedTime,
    this.awakeningsCount = 0,
    this.awakeDurationMinutes = 0, 
  });

  Map<String, dynamic> toJson() => {
        'bedTime': bedTime.toIso8601String(),
        'wakeTime': wakeTime.toIso8601String(),
        'fellAsleepTime': fellAsleepTime.toIso8601String(),
        'outOfBedTime': outOfBedTime?.toIso8601String(),
        'awakeningsCount': awakeningsCount,
        'awakeDurationMinutes': awakeDurationMinutes,
      };

  factory SleepEntry.fromJson(Map<String, dynamic> json) {
    return SleepEntry(
        bedTime: DateTime.parse(json['bedTime']),
        wakeTime: DateTime.parse(json['wakeTime']),
        fellAsleepTime: json['fellAsleepTime'] != null 
            ? DateTime.parse(json['fellAsleepTime']) 
            : DateTime.parse(json['bedTime']),
        outOfBedTime: json['outOfBedTime'] != null 
            ? DateTime.parse(json['outOfBedTime']) 
            : null,
        awakeningsCount: json['awakeningsCount'] ?? 0,
        awakeDurationMinutes: json['awakeDurationMinutes'] ?? 0,
      );
  }
      
  double get durationHours {
    return wakeTime.difference(fellAsleepTime).inMinutes / 60.0;
  }
  
  int get sleepLatencyMinutes => fellAsleepTime.difference(bedTime).inMinutes;
}

class DailyLog {
  String? notes;
  DayType? dayType;
  
  bool isSleeping;
  bool isAwakeInBed;
  DateTime? currentBedTime;
  DateTime? currentWakeTime;
  DateTime? currentFellAsleepTime;
  
  List<SleepEntry> sleepLog;
  List<SubstanceEntry> substanceLog;
  List<MedicationEntry> medicationLog;
  List<ExerciseEntry> exerciseLog;

  DailyLog({
    this.notes,
    this.dayType,
    this.isSleeping = false,
    this.isAwakeInBed = false,
    this.currentBedTime,
    this.currentWakeTime,
    this.currentFellAsleepTime,
    List<SleepEntry>? sleepLog,
    List<SubstanceEntry>? substanceLog,
    List<MedicationEntry>? medicationLog,
    List<ExerciseEntry>? exerciseLog,
  })  : this.sleepLog = sleepLog ?? [],
        this.substanceLog = substanceLog ?? [],
        this.medicationLog = medicationLog ?? [],
        this.exerciseLog = exerciseLog ?? [];

  Map<String, dynamic> toJson() {
    return {
      'notes': notes,
      'dayType': dayType?.name,
      'isSleeping': isSleeping,
      'isAwakeInBed': isAwakeInBed,
      'currentBedTime': currentBedTime?.toIso8601String(),
      'currentWakeTime': currentWakeTime?.toIso8601String(),
      'currentFellAsleepTime': currentFellAsleepTime?.toIso8601String(),
      'sleepLog': sleepLog.map((e) => e.toJson()).toList(),
      'substanceLog': substanceLog.map((e) => e.toJson()).toList(),
      'medicationLog': medicationLog.map((e) => e.toJson()).toList(),
      'exerciseLog': exerciseLog.map((e) => e.toJson()).toList(),
    };
  }

  factory DailyLog.fromJson(Map<String, dynamic> json) {
    List<SleepEntry> loadedSleepLog = [];
    if (json['sleepLog'] != null) {
      for (var item in json['sleepLog']) {
        try { loadedSleepLog.add(SleepEntry.fromJson(item)); } catch (e) {}
      }
    }
    if (loadedSleepLog.isEmpty && json['bedTime'] != null && json['wakeTime'] != null) {
       try {
         loadedSleepLog.add(SleepEntry(
           bedTime: DateTime.parse(json['bedTime']),
           wakeTime: DateTime.parse(json['wakeTime']),
           fellAsleepTime: json['fellAsleepTime'] != null ? DateTime.parse(json['fellAsleepTime']) : DateTime.parse(json['bedTime']),
         ));
       } catch (e) { }
    }

    List<SubstanceEntry> loadedSubstanceLog = [];
    var rawSubstance = json['substanceLog'] ?? json['caffeineLog'];
    if (rawSubstance != null) {
      for (var item in rawSubstance) {
        try { loadedSubstanceLog.add(SubstanceEntry.fromJson(item)); } catch (e) {}
      }
    }

    List<MedicationEntry> loadedMedicationLog = [];
    if (json['medicationLog'] != null) {
      for (var item in json['medicationLog']) {
        try { loadedMedicationLog.add(MedicationEntry.fromJson(item)); } catch (e) {}
      }
    }

    List<ExerciseEntry> loadedExerciseLog = [];
    if (json['exerciseLog'] != null) {
      for (var item in json['exerciseLog']) {
        try { loadedExerciseLog.add(ExerciseEntry.fromJson(item)); } catch (e) {}
      }
    }

    return DailyLog(
      notes: json['notes'],
      dayType: DayType.fromString(json['dayType']),
      isSleeping: json['isSleeping'] ?? false,
      isAwakeInBed: json['isAwakeInBed'] ?? false,
      currentBedTime: json['currentBedTime'] != null ? DateTime.parse(json['currentBedTime']) : null,
      currentWakeTime: json['currentWakeTime'] != null ? DateTime.parse(json['currentWakeTime']) : null,
      currentFellAsleepTime: json['currentFellAsleepTime'] != null ? DateTime.parse(json['currentFellAsleepTime']) : null,
      sleepLog: loadedSleepLog,
      substanceLog: loadedSubstanceLog,
      medicationLog: loadedMedicationLog,
      exerciseLog: loadedExerciseLog,
    );
  }
  
  double get totalSleepHours {
    double total = 0;
    for (var entry in sleepLog) {
      total += entry.durationHours;
    }
    return total;
  }
}

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
        print("Error parsing log for $date: $e");
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
        print("Error parsing log for key $key: $e");
      }
    }
    return allLogs;
  }

  Future<void> clearAllData() async {
    await _prefs.clear();
  }

  Future<void> exportToCsv(BuildContext context) async {
    try {
      final Map<DateTime, DailyLog> allLogs = await getAllLogs();
      
      List<List<dynamic>> rows = [];
      rows.add([
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
      
      for (var date in sortedKeys) {
        final log = allLogs[date]!;
        
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

          String base = "${DateFormat('HH:mm').format(e.bedTime)}-${DateFormat('HH:mm').format(e.wakeTime)}";
          return "$base (Lat: ${e.sleepLatencyMinutes}m, Awake: ${e.awakeDurationMinutes}m/${e.awakeningsCount}x)";
        }).join(" | ");

        String substanceStr = log.substanceLog.map((e) => 
          "${e.name}: ${e.amount} @ ${DateFormat('HH:mm').format(e.time)}").join(" | ");
        
        String medsStr = log.medicationLog.map((e) => 
          "${e.type} (${e.dosage}mg) @ ${DateFormat('HH:mm').format(e.time)}").join(" | ");
          
        String exerciseStr = log.exerciseLog.map((e) => 
          "${e.type} (${DateFormat('HH:mm').format(e.startTime)}-${DateFormat('HH:mm').format(e.finishTime)})").join(" | ");

        rows.add([
          DateFormat('yyyy-MM-dd').format(date),
          log.dayType?.displayName ?? "",
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

      String csvData = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/sleep_data_export.csv";
      final File file = File(path);
      await file.writeAsString(csvData);

      final xFile = XFile(path);
      await Share.shareXFiles([xFile], text: 'Here is my sleep data export.');

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting CSV: $e')),
        );
      }
    }
  }
}

// -------------------------------------------------------------------
// --- 3. Main App and Theme ---
// -------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LogService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          elevation: 4.0,
        ),
        cardTheme: CardThemeData(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          margin: const EdgeInsets.symmetric(vertical: 8.0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            foregroundColor: Colors.indigo,
            side: const BorderSide(color: Colors.indigo, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.indigo,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// -------------------------------------------------------------------
// --- 4. Main Screens ---
// -------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DailyLog _todayLog = DailyLog();
  String _sleepMessage = "Welcome! Tap 'Going to sleep' to start.";
  bool _isLoading = true;
  final LogService _logService = LogService();

  @override
  void initState() {
    super.initState();
    _loadTodayLog();
  }

  Future<void> _loadTodayLog() async {
    try {
      setState(() => _isLoading = true);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final log = await _logService.getDailyLog(today);

      setState(() {
        _todayLog = log;
        if (log.isSleeping) {
          final start = log.currentBedTime ?? DateTime.now();
          _sleepMessage = "Good night! In bed since: ${DateFormat('h:mm a').format(start)}";
        } else if (log.isAwakeInBed) {
          final wake = log.currentWakeTime ?? DateTime.now();
          _sleepMessage = "Good morning! Woke up at ${DateFormat('h:mm a').format(wake)}.\nStill in bed.";
        } else {
          int sessions = log.sleepLog.length;
          double totalHours = log.totalSleepHours;
          if (sessions > 0) {
            _sleepMessage = "Logged $sessions sleep session(s).\nTotal: ${totalHours.toStringAsFixed(1)} hours.";
          } else {
            _sleepMessage = "Welcome! Tap 'Going to sleep' to start.";
          }
        }
      });
    } catch (e) {
      setState(() => _sleepMessage = "Error loading data. Please try again.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoingToSleep() async {
    final DateTime now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _todayLog.currentBedTime = now;
    _todayLog.isSleeping = true;
    _todayLog.isAwakeInBed = false;
    _todayLog.currentWakeTime = null;
    _todayLog.currentFellAsleepTime = null;

    setState(() {
      _sleepMessage = "Good night! In bed since: ${DateFormat('h:mm a').format(now)}";
    });
    await _logService.saveDailyLog(today, _todayLog);
  }

  Future<void> _handleWakingUp() async {
    final DateTime wakeTime = DateTime.now();
    final today = DateTime(wakeTime.year, wakeTime.month, wakeTime.day);
    final DateTime bedTime = _todayLog.currentBedTime ?? wakeTime;

    final TimeOfDay? fellAsleepTimeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(bedTime),
      helpText: 'When do you think you fell asleep?',
    );

    final DateTime fellAsleepTime;
    if (fellAsleepTimeOfDay != null) {
      fellAsleepTime = DateTime(
        bedTime.year,
        bedTime.month,
        fellAsleepTimeOfDay.hour < bedTime.hour ? bedTime.day + 1 : bedTime.day,
        fellAsleepTimeOfDay.hour,
        fellAsleepTimeOfDay.minute,
      );
    } else {
      fellAsleepTime = bedTime;
    }

    _todayLog.isSleeping = false;
    _todayLog.isAwakeInBed = true;
    _todayLog.currentWakeTime = wakeTime;
    _todayLog.currentFellAsleepTime = fellAsleepTime;

    setState(() {
      _sleepMessage = "Good morning! Woke up at ${DateFormat('h:mm a').format(wakeTime)}.\nStill in bed.";
    });

    await _logService.saveDailyLog(today, _todayLog);
  }

  Future<void> _handleOutOfBed() async {
    final DateTime outTime = DateTime.now();
    final today = DateTime(outTime.year, outTime.month, outTime.day);

    final DateTime bedTime = _todayLog.currentBedTime ?? outTime;
    final DateTime wakeTime = _todayLog.currentWakeTime ?? outTime;
    final DateTime fellAsleepTime = _todayLog.currentFellAsleepTime ?? bedTime;

    final newSleep = SleepEntry(
      bedTime: bedTime,
      wakeTime: wakeTime,
      fellAsleepTime: fellAsleepTime,
      outOfBedTime: outTime,
    );

    _todayLog.sleepLog.add(newSleep);
    
    _todayLog.isSleeping = false;
    _todayLog.isAwakeInBed = false;
    _todayLog.currentBedTime = null;
    _todayLog.currentWakeTime = null;
    _todayLog.currentFellAsleepTime = null;

    setState(() {
       int sessions = _todayLog.sleepLog.length;
       double totalHours = _todayLog.totalSleepHours;
       _sleepMessage = "Logged $sessions sleep session(s).\nTotal: ${totalHours.toStringAsFixed(1)} hours.";
    });

    await _logService.saveDailyLog(today, _todayLog);
  }

  @override
  Widget build(BuildContext context) {
    final bool isAsleep = _todayLog.isSleeping;
    final bool isAwakeInBed = _todayLog.isAwakeInBed;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.indigo),
              child: Text(
                'Sleep Tracker',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home_outlined),
              title: Text('Home'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.settings_outlined),
              title: Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Icon(
                              isAsleep 
                                ? Icons.bedtime_outlined 
                                : (isAwakeInBed ? Icons.accessibility_new : Icons.info_outline),
                              color: Colors.indigo,
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _sleepMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (!isAwakeInBed) ...[
                        ElevatedButton.icon(
                          icon: Icon(Icons.wb_sunny_outlined),
                          label: const Text('Just woke up'),
                          onPressed: isAsleep ? _handleWakingUp : null,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: Icon(Icons.bedtime_outlined),
                          label: const Text('Going to sleep'),
                          onPressed: (!isAsleep && !isAwakeInBed) ? _handleGoingToSleep : null,
                        ),
                    ] else ...[
                        ElevatedButton.icon(
                          icon: Icon(Icons.directions_walk),
                          label: const Text('Got out of bed'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                          onPressed: _handleOutOfBed,
                        ),
                    ],

                    const SizedBox(height: 32),
                    Divider(height: 2, color: Colors.grey[300]),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      icon: Icon(Icons.add_task_outlined),
                      label: const Text('Add Event'),
                      onPressed: () {
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EventScreen(date: today),
                          ),
                        ).then((_) => _loadTodayLog());
                      },
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: Icon(Icons.bar_chart),
                      label: const Text('View Statistics'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StatsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: Icon(Icons.calendar_month_outlined),
                      label: const Text('Edit entries'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CalendarScreen(),
                          ),
                        ).then((_) => _loadTodayLog());
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// --- NEW: Statistics Screen ---
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final LogService _logService = LogService();
  Map<DateTime, double> _weeklySleepData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }

  Future<void> _loadWeeklyData() async {
    try {
      setState(() => _isLoading = true);
      final now = DateTime.now();
      Map<DateTime, double> data = {};

      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final normalizedDate = DateTime(date.year, date.month, date.day);
        final log = await _logService.getDailyLog(normalizedDate);
        data[normalizedDate] = log.totalSleepHours;
      }

      setState(() {
        _weeklySleepData = data;
      });
    } catch (e) {
      // handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sleep Statistics')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Past 7 Days Sleep',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 16, // Assume max 16 hours for scale
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                           // tooltipBgColor: Colors.blueGrey, 
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < _weeklySleepData.length) {
                                  final date = _weeklySleepData.keys.elementAt(index);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      DateFormat('E').format(date), // Mon, Tue...
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                              reservedSize: 30,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 2, // Grid lines every 2 hours
                              getTitlesWidget: (double value, TitleMeta meta) {
                                return Text(
                                  '${value.toInt()}h',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                );
                              },
                              reservedSize: 28,
                            ),
                          ),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 2,
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: _weeklySleepData.values.toList().asMap().entries.map((entry) {
                          final index = entry.key;
                          final hours = entry.value;
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: hours,
                                color: Colors.indigo,
                                width: 16,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(4),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Hours slept per day',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
    );
  }
}

class EventScreen extends StatefulWidget {
  final DateTime date;
  const EventScreen({super.key, required this.date});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  final LogService _logService = LogService();
  late DailyLog _log;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  Future<void> _loadLog() async {
    try {
      setState(() => _isLoading = true);
      final log = await _logService.getDailyLog(widget.date);
      setState(() {
        _log = log;
      });
    } catch (e) {
       // handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'Not set';
    return DateFormat('h:mm a').format(dt);
  }

  Future<DateTime?> _selectDateTime(DateTime? initialDate, {String? helpText}) async {
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
      helpText: helpText // Pass custom help text
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _showDayTypeDialog() async {
    final DayType? selectedType = await showDialog<DayType>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Select Day Type'),
          children: DayType.values.map((type) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, type),
              child: Row(
                children: [
                  Icon(type.icon, color: type.color),
                  const SizedBox(width: 16),
                  Text(type.displayName),
                ],
              ),
            );
          }).toList(),
        );
      },
    );

    if (selectedType != null) {
      setState(() {
        _log.dayType = selectedType;
      });
      await _logService.saveDailyLog(widget.date, _log);
    }
  }

  Future<void> _editSleepEntry(int index, SleepEntry entry) async {
    DateTime? bedTime = entry.bedTime;
    DateTime? fellAsleepTime = entry.fellAsleepTime;
    DateTime? wakeTime = entry.wakeTime;
    DateTime? outTime = entry.outOfBedTime;
    int awakenings = entry.awakeningsCount;
    int awakeMins = entry.awakeDurationMinutes;

    await showDialog(
      context: context,
      builder: (context) {
        final countCtrl = TextEditingController(text: awakenings.toString());
        final durCtrl = TextEditingController(text: awakeMins.toString());

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Sleep Session'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(title: Text('Bed: ${_formatTime(bedTime)}'), onTap: () async {
                       var t = await _selectDateTime(bedTime, helpText: "Select Bed Time"); if(t!=null) setDialogState(()=> bedTime = t);
                    }),
                    ListTile(title: Text('Asleep: ${_formatTime(fellAsleepTime)}'), onTap: () async {
                       var t = await _selectDateTime(fellAsleepTime, helpText: "Select Asleep Time"); if(t!=null) setDialogState(()=> fellAsleepTime = t);
                    }),
                    ListTile(title: Text('Wake: ${_formatTime(wakeTime)}'), onTap: () async {
                       var t = await _selectDateTime(wakeTime, helpText: "Select Wake Time"); if(t!=null) setDialogState(()=> wakeTime = t);
                    }),
                    ListTile(title: Text('Out: ${_formatTime(outTime)}'), onTap: () async {
                       var t = await _selectDateTime(outTime, helpText: "Select Out of Bed Time"); if(t!=null) setDialogState(()=> outTime = t);
                    }),
                    TextField(
                      controller: countCtrl,
                      decoration: InputDecoration(labelText: 'Number of Awakenings'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: durCtrl,
                      decoration: InputDecoration(labelText: 'Total Awake Time (mins)'),
                      keyboardType: TextInputType.number,
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: ()=>Navigator.pop(context), child: Text('Cancel')),
                TextButton(onPressed: () {
                   awakenings = int.tryParse(countCtrl.text) ?? 0;
                   awakeMins = int.tryParse(durCtrl.text) ?? 0;
                   
                   setState(() {
                     _log.sleepLog[index] = SleepEntry(
                       bedTime: bedTime!,
                       wakeTime: wakeTime!,
                       fellAsleepTime: fellAsleepTime!,
                       outOfBedTime: outTime,
                       awakeningsCount: awakenings,
                       awakeDurationMinutes: awakeMins
                     );
                   });
                   _logService.saveDailyLog(widget.date, _log);
                   Navigator.pop(context);
                }, child: Text('Save')),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _addSleepEntry() async {
    DateTime now = DateTime.now();
    
    DateTime? bedTime = await _selectDateTime(now, helpText: "Select Bed Time");
    if (bedTime == null) return;

    DateTime? asleepTime = await _selectDateTime(bedTime, helpText: "Select Asleep Time");
    if (asleepTime == null) return;

    DateTime? wakeTime = await _selectDateTime(asleepTime.add(Duration(hours: 8)), helpText: "Select Wake Time");
    if (wakeTime == null) return;
    
    DateTime? outTime = await _selectDateTime(wakeTime, helpText: "Select Out of Bed Time");
    if (outTime == null) return;

    if (wakeTime.isBefore(bedTime)) {
       if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wake time cannot be before bed time.')));
       }
       return;
    }

    setState(() {
      _log.sleepLog.add(SleepEntry(
        bedTime: bedTime,
        wakeTime: wakeTime,
        fellAsleepTime: asleepTime,
        outOfBedTime: outTime
      ));
    });
    await _logService.saveDailyLog(widget.date, _log);
  }

  void _deleteSleepEntry(int index) {
    setState(() {
      _log.sleepLog.removeAt(index);
    });
    _logService.saveDailyLog(widget.date, _log);
  }

  @override
  Widget build(BuildContext context) {
    final String displayDate = DateFormat('dd/MM/yyyy').format(widget.date);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Event', style: TextStyle(fontSize: 20)),
            Text(
              displayDate,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text('Sleep Sessions', 
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)
                  ),
                ),
                const SizedBox(height: 8),
                
                if (_log.sleepLog.isEmpty)
                   Padding(
                     padding: const EdgeInsets.all(8.0),
                     child: Text('No sleep recorded for this day.', style: TextStyle(color: Colors.grey)),
                   ),
                
                ..._log.sleepLog.asMap().entries.map((entry) {
                    int idx = entry.key;
                    SleepEntry sleep = entry.value;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: Icon(Icons.king_bed_outlined, color: Colors.indigo[800]),
                        title: Text("${_formatTime(sleep.bedTime)} - ${_formatTime(sleep.wakeTime)}"),
                        subtitle: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text("Asleep: ${_formatTime(sleep.fellAsleepTime)}"),
                             Text("Out: ${_formatTime(sleep.outOfBedTime ?? sleep.wakeTime)}"),
                             if (sleep.awakeningsCount > 0)
                               Text("Awake: ${sleep.awakeDurationMinutes}m (${sleep.awakeningsCount}x)")
                           ]
                        ),
                        onTap: () => _editSleepEntry(idx, sleep), 
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteSleepEntry(idx),
                        ),
                      ),
                    );
                }).toList(),
                
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: Icon(Icons.add),
                  label: Text('Add Sleep Session'),
                  onPressed: _addSleepEntry,
                ),
                const SizedBox(height: 24),
                Divider(),
                const SizedBox(height: 24),

                _EventButton(
                  label: _log.dayType?.displayName ?? 'Type of Day',
                  icon: _log.dayType?.icon ?? Icons.wb_sunny_outlined,
                  color: _log.dayType?.color ?? Colors.indigo[800]!,
                  onPressed: _showDayTypeDialog,
                ),
                const SizedBox(height: 16),
                _EventButton(
                  label: 'Medication',
                  subtitle: _log.medicationLog.isNotEmpty ? "${_log.medicationLog.length} entries" : null,
                  icon: Icons.medication_outlined,
                  color: Colors.green[800]!,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MedicationScreen(date: widget.date),
                      ),
                    ).then((_) => _loadLog());
                  },
                ),
                const SizedBox(height: 16),
                _EventButton(
                  label: 'Caffeine & Alcohol',
                  subtitle: _log.substanceLog.isNotEmpty ? "${_log.substanceLog.length} entries" : null,
                  icon: Icons.coffee_outlined,
                  color: Colors.brown[600]!,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CaffeineAlcoholScreen(date: widget.date),
                      ),
                    ).then((_) => _loadLog());
                  },
                ),
                const SizedBox(height: 16),
                _EventButton(
                  label: 'Exercise',
                  subtitle: _log.exerciseLog.isNotEmpty ? "${_log.exerciseLog.length} entries" : null,
                  icon: Icons.fitness_center_outlined,
                  color: Colors.orange[800]!,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExerciseScreen(date: widget.date),
                      ),
                    ).then((_) => _loadLog());
                  },
                ),
                const SizedBox(height: 16),
                _EventButton(
                  label: 'Notes',
                  subtitle: _log.notes != null && _log.notes!.isNotEmpty ? "Added" : null,
                  icon: Icons.note_alt_outlined,
                  color: Colors.grey[700]!,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NotesScreen(date: widget.date),
                      ),
                    ).then((_) => _loadLog());
                  },
                ),
              ],
            ),
    );
  }
}

class _SleepTimeChip extends StatelessWidget {
  const _SleepTimeChip({required this.label, required this.time});
  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EventButton extends StatelessWidget {
  const _EventButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.subtitle,
  });
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final LogService _logService = LogService();
  Map<DateTime, DailyLog> _logsByDate = {};
  DateTime _focusedDay = DateTime.now();
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime.utc(now.year, now.month, now.day);
    _loadAllLogs();
  }

  Future<void> _loadAllLogs() async {
    final logs = await _logService.getAllLogs();
    setState(() {
      _logsByDate = logs;
    });
  }

  List<Object> _getEventsForDay(DateTime day) {
    final utcDay = DateTime.utc(day.year, day.month, day.day);
    final log = _logsByDate[utcDay];
    if (log != null && log.dayType != null) {
      return [log.dayType!];
    }
    return [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final utcSelectedDay = DateTime.utc(selectedDay.year, selectedDay.month, selectedDay.day);
    if (!isSameDay(_selectedDay, utcSelectedDay)) {
      setState(() {
        _selectedDay = utcSelectedDay;
        _focusedDay = focusedDay;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventScreen(date: utcSelectedDay),
        ),
      ).then((_) => _loadAllLogs());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calendar'),
        centerTitle: true,
      ),
      body: Card(
        margin: const EdgeInsets.all(12.0),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(
                DateTime.now().year, DateTime.now().month, DateTime.now().day),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: _onDaySelected,
            eventLoader: _getEventsForDay,
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isNotEmpty) {
                  final dayType = events[0] as DayType;
                  return Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: dayType.color,
                      shape: BoxShape.circle,
                    ),
                  );
                }
                return null;
              },
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.deepOrange[300],
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.indigo[600],
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
        ),
      ),
    );
  }
}

class ExerciseScreen extends StatefulWidget {
  final DateTime date;
  const ExerciseScreen({super.key, required this.date});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  final LogService _logService = LogService();
  late DailyLog _log;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  Future<void> _loadLog() async {
    try {
      setState(() => _isLoading = true);
      final log = await _logService.getDailyLog(widget.date);
      setState(() {
        _log = log;
      });
    } catch (e) {
       // handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLog() async {
    await _logService.saveDailyLog(widget.date, _log);
  }

  Future<TimeOfDay?> _showTimePicker(TimeOfDay initialTime,
      {required String helpText}) async {
    return await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: helpText,
    );
  }

  Future<void> _addExerciseEntry() async {
    final String? type = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select Activity Type'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Light'),
            child: Text('Light'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Medium'),
            child: Text('Medium'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Heavy'),
            child: Text('Heavy'),
          ),
        ],
      ),
    );
    if (type == null) return;

    final TimeOfDay? startTime = await _showTimePicker(
      TimeOfDay.now(),
      helpText: 'Select Start Time',
    );
    if (startTime == null) return;

    final TimeOfDay? finishTime = await _showTimePicker(
      startTime,
      helpText: 'Select Finish Time',
    );
    if (finishTime == null) return;

    final DateTime startDateTime = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      startTime.hour,
      startTime.minute,
    );
    final DateTime finishDateTime = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      finishTime.hour,
      finishTime.minute,
    );

    if (finishDateTime.isBefore(startDateTime)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Finish time cannot be before start time.')),
        );
      }
      return;
    }

    final newEntry = ExerciseEntry(
      type: type,
      startTime: startDateTime,
      finishTime: finishDateTime,
    );

    setState(() {
      _log.exerciseLog.add(newEntry);
    });
    _saveLog();
  }

  void _deleteExerciseEntry(int index) {
    setState(() {
      _log.exerciseLog.removeAt(index);
    });
    _saveLog();
  }

  String _getDuration(DateTime start, DateTime finish) {
    final duration = finish.difference(start);
    if (duration.isNegative) return "Invalid";
    return "${duration.inMinutes} mins";
  }

  @override
  Widget build(BuildContext context) {
    final String displayDate = DateFormat('dd/MM/yyyy').format(widget.date);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Exercise Log', style: TextStyle(fontSize: 20)),
            Text(
              displayDate,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Exercise Entries',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: _log.exerciseLog.asMap().entries.map((entry) {
                      int idx = entry.key;
                      ExerciseEntry item = entry.value;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Icon(Icons.fitness_center,
                              color: Colors.orange[800]),
                          title: Text(item.type,
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              '${DateFormat('h:mm a').format(item.startTime)} - ${DateFormat('h:mm a').format(item.finishTime)} (${_getDuration(item.startTime, item.finishTime)})'),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteExerciseEntry(idx),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Exercise Entry'),
                    onPressed: _addExerciseEntry,
                  ),
                ],
              ),
            ),
    );
  }
}

class CaffeineAlcoholScreen extends StatefulWidget {
  final DateTime date;
  const CaffeineAlcoholScreen({super.key, required this.date});

  @override
  State<CaffeineAlcoholScreen> createState() => _CaffeineAlcoholScreenState();
}

class _CaffeineAlcoholScreenState extends State<CaffeineAlcoholScreen> {
  final LogService _logService = LogService();
  late DailyLog _log;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  Future<void> _loadLog() async {
    try {
      setState(() => _isLoading = true);
      final log = await _logService.getDailyLog(widget.date);
      setState(() {
        _log = log;
      });
    } catch (e) {
       // handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLog() async {
    await _logService.saveDailyLog(widget.date, _log);
  }

  Future<void> _addEntry() async {
    final String? type = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select Substance'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Coffee'),
            child: Row(children: [Icon(Icons.coffee, color: Colors.brown), SizedBox(width: 10), Text('Coffee')]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Tea'),
            child: Row(children: [Icon(Icons.emoji_food_beverage, color: Colors.green), SizedBox(width: 10), Text('Tea')]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Cola'),
            child: Row(children: [Icon(Icons.local_drink, color: Colors.black87), SizedBox(width: 10), Text('Cola')]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Alcohol'),
            child: Row(children: [Icon(Icons.wine_bar, color: Colors.purple), SizedBox(width: 10), Text('Alcohol')]),
          ),
        ],
      ),
    );
    if (type == null) return;

    List<String> amountOptions;
    if (type == 'Alcohol') {
      amountOptions = ['1 drink', '2 drinks', '3 drinks', '4 drinks', '5+ drinks'];
    } else {
      amountOptions = ['One cup', 'Two cups', 'Three cups', 'Four cups'];
    }

    final String? amount = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select Amount ($type)'),
        children: amountOptions.map((opt) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, opt),
          child: Text(opt),
        )).toList(),
      ),
    );
    if (amount == null) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Select Time of Consumption',
    );
    if (time == null) return;

    final DateTime entryTime = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      time.hour,
      time.minute,
    );

    final newEntry = SubstanceEntry(name: type, amount: amount, time: entryTime);
    setState(() {
      _log.substanceLog.add(newEntry);
    });
    _saveLog();
  }

  void _deleteEntry(int index) {
    setState(() {
      _log.substanceLog.removeAt(index);
    });
    _saveLog();
  }

  IconData _getIcon(String name) {
    if (name == 'Alcohol') return Icons.wine_bar;
    if (name == 'Tea') return Icons.emoji_food_beverage;
    if (name == 'Cola') return Icons.local_drink;
    return Icons.coffee;
  }

  Color _getColor(String name) {
    if (name == 'Alcohol') return Colors.purple;
    if (name == 'Tea') return Colors.green[700]!;
    if (name == 'Cola') return Colors.black87;
    return Colors.brown;
  }

  @override
  Widget build(BuildContext context) {
    final String displayDate = DateFormat('dd/MM/yyyy').format(widget.date);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Caffeine & Alcohol', style: TextStyle(fontSize: 20)),
            Text(
              displayDate,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Consumption Log',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: _log.substanceLog.asMap().entries.map((entry) {
                      int idx = entry.key;
                      SubstanceEntry item = entry.value;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Icon(_getIcon(item.name),
                              color: _getColor(item.name)),
                          title: Text("${item.name}: ${item.amount}",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle:
                              Text(DateFormat('h:mm a').format(item.time)),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteEntry(idx),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Consumption Entry'),
                    onPressed: _addEntry,
                  ),
                ],
              ),
            ),
    );
  }
}

class MedicationScreen extends StatefulWidget {
  final DateTime date;
  const MedicationScreen({super.key, required this.date});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  final LogService _logService = LogService();
  late DailyLog _log;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  Future<void> _loadLog() async {
    try {
      setState(() => _isLoading = true);
      final log = await _logService.getDailyLog(widget.date);
      setState(() {
        _log = log;
      });
    } catch (e) {
       // handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLog() async {
    await _logService.saveDailyLog(widget.date, _log);
  }

  Future<void> _addMedicationEntry() async {
    String? type = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select Medication'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Melatonin'),
            child: Text('Melatonin'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Daridorexant'),
            child: Text('Daridorexant'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Sertraline'),
            child: Text('Sertraline'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Lisdexamfetamine'),
            child: Text('Lisdexamfetamine'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Other'),
            child: Text('Other...'),
          ),
        ],
      ),
    );

    if (type == null) return;

    if (type == 'Other') {
      final controller = TextEditingController();
      type = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Enter Medication Name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: 'e.g. Ibuprofen'),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () => Navigator.pop(context, controller.text),
            ),
          ],
        ),
      );
    }

    if (type == null || type.isEmpty) return;

    String? dosage = await showDialog<String>(
        context: context,
        builder: (context) {
            final controller = TextEditingController();
            return AlertDialog(
                title: const Text('Enter Dosage (mg)'),
                content: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'e.g. 5 or 10'),
                ),
                actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('OK')),
                ],
            );
        }
    );

    if (dosage == null || dosage.isEmpty) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Select Medication Time',
    );
    if (time == null) return;

    final DateTime entryTime = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      time.hour,
      time.minute,
    );
    final newEntry = MedicationEntry(type: type, dosage: dosage, time: entryTime);
    setState(() {
      _log.medicationLog.add(newEntry);
    });
    _saveLog();
  }

  void _deleteMedicationEntry(int index) {
    setState(() {
      _log.medicationLog.removeAt(index);
    });
    _saveLog();
  }

  @override
  Widget build(BuildContext context) {
    final String displayDate = DateFormat('dd/MM/yyyy').format(widget.date);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Medication Log', style: TextStyle(fontSize: 20)),
            Text(
              displayDate,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Medication Log',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children:
                        _log.medicationLog.asMap().entries.map((entry) {
                      int idx = entry.key;
                      MedicationEntry item = entry.value;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Icon(Icons.medication_outlined,
                              color: Colors.green[800]),
                          title: Text("${item.type} (${item.dosage}mg)",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle:
                              Text(DateFormat('h:mm a').format(item.time)),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteMedicationEntry(idx),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Medication Entry'),
                    onPressed: _addMedicationEntry,
                  ),
                ],
              ),
            ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.settings_outlined, size: 64, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text(
                'App Settings',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'All your log data is saved locally on this device. Clearing data is permanent and cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 32),
              
              // --- CSV EXPORT BUTTON ---
              ElevatedButton.icon(
                icon: Icon(Icons.download),
                label: const Text('Export Data as CSV'),
                onPressed: () async {
                  await LogService().exportToCsv(context);
                },
              ),
              const SizedBox(height: 20),
              
              OutlinedButton.icon(
                icon: Icon(Icons.delete_forever_outlined),
                label: const Text('Clear All Saved Data'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[700],
                  side: BorderSide(color: Colors.red[700]!),
                ),
                onPressed: () async {
                  final bool? confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Are you sure?'),
                      content:
                          Text('This will delete all saved data permanently.'),
                      actions: [
                        TextButton(
                          child: Text('Cancel'),
                          onPressed: () => Navigator.pop(context, false),
                        ),
                        TextButton(
                          child: Text('Delete',
                              style: TextStyle(color: Colors.red)),
                          onPressed: () => Navigator.pop(context, true),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await LogService().clearAllData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('All saved data has been cleared!')),
                      );
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

class NotesScreen extends StatefulWidget {
  final DateTime date;
  const NotesScreen({super.key, required this.date});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _controller = TextEditingController();
  final LogService _logService = LogService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    try {
      setState(() => _isLoading = true);
      final log = await _logService.getDailyLog(widget.date);
      setState(() {
        _controller.text = log.notes ?? "";
      });
    } catch (e) {
       // handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNotes() async {
    final log = await _logService.getDailyLog(widget.date);
    log.notes = _controller.text;
    await _logService.saveDailyLog(widget.date, log);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notes saved!')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notes'),
        actions: [
          IconButton(
            icon: Icon(Icons.save_outlined),
            onPressed: _saveNotes,
            tooltip: 'Save Notes',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Write your notes here...",
                      hintStyle: const TextStyle(
                        color: Color(0xffDDDADA),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                    ),
                    maxLines: 20,
                    autofocus: true,
                  ),
                ),
              ),
            ),
    );
  }
}