/// A simple, local-first sleep and event tracking application.
///
/// This single file contains all the logic for the app, including:
/// - Data Models (e.g., DailyLog, ExerciseEntry)
/// - The LogService (for saving/loading data to SharedPreferences)
/// - All UI Screens (HomeScreen, EventScreen, CalendarScreen, etc.)

// --- Imports ---
import 'dart:convert'; // Import for jsonEncode and jsonDecode
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

// -------------------------------------------------------------------
// --- 1. Enums and Data Models ---
// -------------------------------------------------------------------

/// Enum representing the user-defined type of day.
/// Includes helpers for display name, color, and icon.
enum DayType {
  work,
  relax,
  travel,
  social,
  other;

  /// Returns a user-friendly string for display.
  String get displayName {
    switch (this) {
      case DayType.work:
        return 'Work';
      case DayType.relax:
        return 'Relax';
      case DayType.travel:
        return 'Travel';
      case DayType.social:
        return 'Social';
      case DayType.other:
      default:
        return 'Other';
    }
  }

  /// Returns a unique color for each day type.
  Color get color {
    switch (this) {
      case DayType.work:
        return Colors.blue[800]!;
      case DayType.relax:
        return Colors.green[800]!;
      case DayType.travel:
        return Colors.orange[800]!;
      case DayType.social:
        return Colors.purple[800]!;
      case DayType.other:
      default:
        return Colors.grey[700]!;
    }
  }

  /// Returns a unique icon for each day type.
  IconData get icon {
    switch (this) {
      case DayType.work:
        return Icons.work_outline;
      case DayType.relax:
        return Icons.self_improvement_outlined;
      case DayType.travel:
        return Icons.explore_outlined;
      case DayType.social:
        return Icons.people_outline;
      case DayType.other:
      default:
        return Icons.wb_sunny_outlined;
    }
  }

  /// Safely creates a [DayType] from a saved string (e.g., "work").
  /// Returns null if the string is invalid.
  static DayType? fromString(String? typeString) {
    if (typeString == null) return null;
    for (DayType type in DayType.values) {
      if (type.name == typeString) {
        return type;
      }
    }
    return null;
  }
}

/// Represents a single entry for caffeine consumption.
class CaffeineEntry {
  String amount; // "One cup", "Two cups", etc.
  DateTime time;

  CaffeineEntry({required this.amount, required this.time});

  /// Converts this object into a JSON-compatible Map.
  Map<String, dynamic> toJson() => {
        'amount': amount,
        'time': time.toIso8601String(),
      };

  /// Creates a [CaffeineEntry] from a JSON Map.
  factory CaffeineEntry.fromJson(Map<String, dynamic> json) => CaffeineEntry(
        amount: json['amount'],
        time: DateTime.parse(json['time']),
      );
}

/// Represents a single entry for medication.
class MedicationEntry {
  String type; // "Medication"
  DateTime time;

  MedicationEntry({required this.type, required this.time});

  /// Converts this object into a JSON-compatible Map.
  Map<String, dynamic> toJson() => {
        'type': type,
        'time': time.toIso8601String(),
      };

  /// Creates a [MedicationEntry] from a JSON Map.
  factory MedicationEntry.fromJson(Map<String, dynamic> json) =>
      MedicationEntry(
        type: json['type'],
        time: DateTime.parse(json['time']),
      );
}

/// Represents a single entry for exercise.
class ExerciseEntry {
  String type; // "Light", "Medium", "Heavy"
  DateTime startTime;
  DateTime finishTime;

  ExerciseEntry({
    required this.type,
    required this.startTime,
    required this.finishTime,
  });

  /// Converts this object into a JSON-compatible Map.
  Map<String, dynamic> toJson() => {
        'type': type,
        'startTime': startTime.toIso8601String(),
        'finishTime': finishTime.toIso8601String(),
      };

  /// Creates an [ExerciseEntry] from a JSON Map.
  factory ExerciseEntry.fromJson(Map<String, dynamic> json) => ExerciseEntry(
        type: json['type'],
        startTime: DateTime.parse(json['startTime']),
        finishTime: DateTime.parse(json['finishTime']),
      );
}

/// The main data class for a single day.
/// This object holds ALL data for a given date and is what we save.
class DailyLog {
  DateTime? bedTime;
  DateTime? wakeTime;
  DateTime? fellAsleepTime;
  String? sleepSummary;
  String? notes;
  DayType? dayType;
  bool isSleeping; // Controls HomeScreen UI state
  List<CaffeineEntry> caffeineLog;
  List<MedicationEntry> medicationLog;
  List<ExerciseEntry> exerciseLog;

  DailyLog({
    this.bedTime,
    this.wakeTime,
    this.fellAsleepTime,
    this.sleepSummary,
    this.notes,
    this.dayType,
    this.isSleeping = false,
    List<CaffeineEntry>? caffeineLog,
    List<MedicationEntry>? medicationLog,
    List<ExerciseEntry>? exerciseLog,
  })  : this.caffeineLog = caffeineLog ?? [], // Default to empty lists
        this.medicationLog = medicationLog ?? [],
        this.exerciseLog = exerciseLog ?? [];

  /// Converts this [DailyLog] into a JSON-compatible Map for saving.
  Map<String, dynamic> toJson() {
    return {
      'bedTime': bedTime?.toIso8601String(),
      'wakeTime': wakeTime?.toIso8601String(),
      'fellAsleepTime': fellAsleepTime?.toIso8601String(),
      'sleepSummary': sleepSummary,
      'notes': notes,
      'dayType': dayType?.name, // Save the enum's name (e.g., "work")
      'isSleeping': isSleeping,
      'caffeineLog': caffeineLog.map((e) => e.toJson()).toList(),
      'medicationLog': medicationLog.map((e) => e.toJson()).toList(),
      'exerciseLog': exerciseLog.map((e) => e.toJson()).toList(),
    };
  }

  /// Creates a [DailyLog] from a JSON Map (loaded from storage).
  factory DailyLog.fromJson(Map<String, dynamic> json) {
    return DailyLog(
      bedTime: json['bedTime'] != null ? DateTime.parse(json['bedTime']) : null,
      wakeTime:
          json['wakeTime'] != null ? DateTime.parse(json['wakeTime']) : null,
      fellAsleepTime: json['fellAsleepTime'] != null
          ? DateTime.parse(json['fellAsleepTime'])
          : null,
      sleepSummary: json['sleepSummary'],
      notes: json['notes'],
      dayType: DayType.fromString(json['dayType']), // Use safe helper
      isSleeping: json['isSleeping'] ?? false, // Default to false if null
      caffeineLog: (json['caffeineLog'] as List<dynamic>?)
              ?.map((e) => CaffeineEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      medicationLog: (json['medicationLog'] as List<dynamic>?)
              ?.map((e) => MedicationEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      exerciseLog: (json['exerciseLog'] as List<dynamic>?)
              ?.map((e) => ExerciseEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// -------------------------------------------------------------------
// --- 2. LogService (Data Persistence) ---
// -------------------------------------------------------------------

/// A singleton service to handle all read/write operations
/// to the device's local storage (SharedPreferences).
class LogService {
  // --- Singleton Pattern Setup ---
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();
  // -------------------------------

  late SharedPreferences _prefs;

  /// Initializes the service by getting the SharedPreferences instance.
  /// This MUST be called in `main()` before the app runs.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Creates a unique key for a given date (e.g., "log_2025-11-14").
  String _getKeyForDate(DateTime date) {
    return 'log_${DateFormat('yyyy-MM-dd').format(date)}';
  }

  /// Fetches the [DailyLog] for a specific date.
  /// If no log exists, returns a new, empty [DailyLog].
  Future<DailyLog> getDailyLog(DateTime date) async {
    final String key = _getKeyForDate(date);
    final String? logJson = _prefs.getString(key);

    if (logJson != null) {
      // Data found, decode it from JSON
      return DailyLog.fromJson(jsonDecode(logJson));
    } else {
      // No data found, return a fresh object
      return DailyLog();
    }
  }

  /// Saves a [DailyLog] object for a specific date.
  /// Encodes the object to a JSON string before saving.
  Future<void> saveDailyLog(DateTime date, DailyLog log) async {
    final String key = _getKeyForDate(date);
    final String logJson = jsonEncode(log.toJson()); // Encode to string
    await _prefs.setString(key, logJson);
  }

  /// Loads all logs from storage. Used by the [CalendarScreen].
  Future<Map<DateTime, DailyLog>> getAllLogs() async {
    final Map<DateTime, DailyLog> allLogs = {};
    // Find all keys in storage that start with our "log_" prefix
    final allKeys = _prefs.getKeys().where((key) => key.startsWith('log_'));

    for (final key in allKeys) {
      try {
        // Extract date from key (e.g., "log_2025-11-14" -> "2025-11-14")
        final dateString = key.substring(4);
        final date = DateTime.parse(dateString);
        // Normalize to UTC for map key consistency
        final utcDate = DateTime.utc(date.year, date.month, date.day);
        final log = await getDailyLog(utcDate);
        allLogs[utcDate] = log;
      } catch (e) {
        // Handle potential errors if a key is malformed
        print("Error parsing log for key $key: $e");
      }
    }
    return allLogs;
  }

  /// Clears all data from SharedPreferences.
  Future<void> clearAllData() async {
    await _prefs.clear();
  }
}

// -------------------------------------------------------------------
// --- 3. Main App and Theme ---
// -------------------------------------------------------------------

/// The main entry point for the application.
Future<void> main() async {
  // Ensure Flutter widgets are initialized before running async code
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the LogService so it's ready before the app starts
  await LogService().init();
  // Run the app
  runApp(const MyApp());
}

/// The root widget of the application.
/// Sets up the global theme and defines the home screen.
class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // MaterialApp is the root of all UI and navigation
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Hides the "Debug" banner
      // --- Global App Theme ---
      theme: ThemeData(
        primarySwatch: Colors.indigo, // A calm, professional primary color
        scaffoldBackgroundColor: Colors.grey[100], // A soft, clean background
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo, // Consistent AppBar color
          foregroundColor: Colors.white, // White title
          elevation: 4.0, // Subtle shadow
        ),
        cardTheme: CardThemeData(
          elevation: 1.5, // Lighter shadow for cards
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8.0), // Consistent margin
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.indigo, // Button color
            foregroundColor: Colors.white, // Button text color
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            foregroundColor: Colors.indigo,
            side: const BorderSide(color: Colors.indigo, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.indigo,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        // --- FIX: Corrected DialogThemeData to DialogTheme ---
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
      ),
      // --- End of Theme ---
      home: const HomeScreen(),
    );
  }
}

// -------------------------------------------------------------------
// --- 4. Main Screens ---
// -------------------------------------------------------------------

/// The main landing page of the app.
/// Displays sleep status and navigation to other screens.
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
    _loadTodayLog(); // Load data as soon as the screen is created
  }

  /// Loads the [DailyLog] for the current day and updates the UI.
  Future<void> _loadTodayLog() async {
    setState(() {
      _isLoading = true;
    });
    final now = DateTime.now();
    // Normalize to midnight to get the correct key
    final today = DateTime(now.year, now.month, now.day);
    final log = await _logService.getDailyLog(today);

    // Update the UI with the loaded data
    setState(() {
      _todayLog = log;
      if (log.isSleeping) {
        _sleepMessage =
            "Good night! In bed at: ${DateFormat('h:mm a').format(log.bedTime!)}";
      } else {
        _sleepMessage =
            log.sleepSummary ?? "Welcome! Tap 'Going to sleep' to start.";
      }
      _isLoading = false;
    });
  }

  /// Handles the 'Going to sleep' button tap.
  /// Saves the bed time and sets the `isSleeping` flag.
  Future<void> _handleGoingToSleep() async {
    final DateTime now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Clear old sleep data to start a new "session"
    _todayLog.wakeTime = null;
    _todayLog.fellAsleepTime = null;
    _todayLog.sleepSummary = null;
    // Set new state
    _todayLog.bedTime = now;
    _todayLog.isSleeping = true;

    // Update UI immediately
    setState(() {
      _sleepMessage =
          "Good night! In bed at: ${DateFormat('h:mm a').format(now)}";
    });
    // Save to storage
    await _logService.saveDailyLog(today, _todayLog);
  }

  /// Handles the 'Just woke up' button tap.
  /// Shows the "fell asleep" time picker and calculates the sleep summary.
  Future<void> _handleWakingUp() async {
    final DateTime wakeTime = DateTime.now();
    final today = DateTime(wakeTime.year, wakeTime.month, wakeTime.day);
    final DateTime bedTime = _todayLog.bedTime ?? wakeTime;

    // 1. Ask user when they think they fell asleep
    final TimeOfDay? fellAsleepTimeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(bedTime),
      helpText: 'When do you think you fell asleep?',
    );

    final DateTime fellAsleepTime;
    if (fellAsleepTimeOfDay != null) {
      // Handle "midnight crossing" (e.g., bed at 11 PM, asleep at 12:30 AM)
      fellAsleepTime = DateTime(
        bedTime.year,
        bedTime.month,
        fellAsleepTimeOfDay.hour < bedTime.hour ? bedTime.day + 1 : bedTime.day,
        fellAsleepTimeOfDay.hour,
        fellAsleepTimeOfDay.minute,
      );
    } else {
      fellAsleepTime = bedTime; // Default to bedTime if user cancels
    }

    // 2. Calculate durations
    final Duration timeInBed = wakeTime.difference(bedTime);
    final Duration timeAsleep = wakeTime.difference(fellAsleepTime);

    // 3. Create summary strings
    String timeInBedStr =
        "${timeInBed.inHours}h ${timeInBed.inMinutes.remainder(60)}m";
    String timeAsleepStr =
        "${timeAsleep.inHours}h ${timeAsleep.inMinutes.remainder(60)}m";
    final String summaryMessage =
        "You were in bed for $timeInBedStr.\nYou were asleep for $timeAsleepStr.";

    // 4. Update the log object
    _todayLog.wakeTime = wakeTime;
    _todayLog.fellAsleepTime = fellAsleepTime;
    _todayLog.sleepSummary = summaryMessage;
    _todayLog.isSleeping = false; // No longer sleeping

    // 5. Update UI and save
    setState(() {
      _sleepMessage = summaryMessage;
    });

    await _logService.saveDailyLog(today, _todayLog);
  }

  @override
  Widget build(BuildContext context) {
    // Use the `isSleeping` flag to control the UI state
    final bool isAsleep = _todayLog.isSleeping;
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
      // Standard app drawer
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.indigo,
              ),
              child: Text(
                'Sleep Tracker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home_outlined),
              title: Text('Home'),
              onTap: () {
                Navigator.pop(context); // Close drawer
              },
            ),
            ListTile(
              leading: Icon(Icons.settings_outlined),
              title: Text('Settings'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
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
                    // --- Sleep Summary Card ---
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Icon(
                              isAsleep
                                  ? Icons.bedtime_outlined
                                  : Icons.info_outline,
                              color: Colors.indigo,
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _sleepMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // --- Sleep Buttons ---
                    ElevatedButton.icon(
                      icon: Icon(Icons.wb_sunny_outlined),
                      label: const Text('Just woke up'),
                      // Button is disabled if user is not "in bed"
                      onPressed: isAsleep ? _handleWakingUp : null,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.bedtime_outlined),
                      label: const Text('Going to sleep'),
                      // Button is disabled if user is already "in bed"
                      onPressed: !isAsleep ? _handleGoingToSleep : null,
                    ),
                    const SizedBox(height: 32),
                    Divider(height: 2, color: Colors.grey[300]),
                    const SizedBox(height: 32),
                    // --- Navigation Buttons ---
                    ElevatedButton.icon(
                      icon: Icon(Icons.add_task_outlined),
                      label: const Text('Add Event'),
                      onPressed: () {
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        // Navigate to EventScreen for *today*.
                        // `then` reloads the home screen data when we return.
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
                      icon: Icon(Icons.calendar_month_outlined),
                      label: const Text('Edit entries'),
                      onPressed: () {
                        // Navigate to the Calendar.
                        // `then` reloads the home screen data when we return.
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

/// The central hub for viewing and editing all data for a *single day*.
class EventScreen extends StatefulWidget {
  /// The specific date this screen should display and edit.
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
    _loadLog(); // Load this screen's specific log
  }

  /// Loads the [DailyLog] for [widget.date] (the date passed in).
  Future<void> _loadLog() async {
    setState(() {
      _isLoading = true;
    });
    final log = await _logService.getDailyLog(widget.date);
    setState(() {
      _log = log;
      _isLoading = false;
    });
  }

  /// Helper to format a [DateTime] as 'h:mm a' or 'Not set'.
  String _formatTime(DateTime? dt) {
    if (dt == null) return 'Not set';
    return DateFormat('h:mm a').format(dt);
  }

  /// Recalculates the sleep summary string based on new times.
  String _recalculateSleepSummary(
      DateTime? bedTime, DateTime? wakeTime, DateTime? fellAsleepTime) {
    if (bedTime == null || wakeTime == null) {
      return "Sleep not fully logged.";
    }

    final DateTime asleepTime = fellAsleepTime ?? bedTime;
    final Duration timeInBed = wakeTime.difference(bedTime);
    final Duration timeAsleep = wakeTime.difference(asleepTime);

    if (timeInBed.isNegative || timeAsleep.isNegative) {
      return "Error: Wake time is before bed time.";
    }

    String timeInBedStr =
        "${timeInBed.inHours}h ${timeInBed.inMinutes.remainder(60)}m";
    String timeAsleepStr =
        "${timeAsleep.inHours}h ${timeAsleep.inMinutes.remainder(60)}m";
    return "Time in Bed: $timeInBedStr\nTime Asleep: $timeAsleepStr";
  }

  /// Shows a native DatePicker and TimePicker to select a full DateTime.
  Future<DateTime?> _selectDateTime(DateTime? initialDate) async {
    DateTime now = DateTime.now();
    initialDate = initialDate ?? now;

    // 1. Show Date Picker
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return null; // User cancelled

    // 2. Show Time Picker
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return null; // User cancelled

    // 3. Combine and return
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  /// Shows the dialog for selecting a [DayType].
  Future<void> _showDayTypeDialog() async {
    final DayType? selectedType = await showDialog<DayType>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Select Day Type'),
          children: DayType.values.map((type) {
            return SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, type);
              },
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

  /// Shows the dialog for manually editing sleep times.
  Future<void> _showSleepEditDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        // Create temporary variables to hold dialog state
        DateTime? tempBedTime = _log.bedTime;
        DateTime? tempFellAsleepTime = _log.fellAsleepTime;
        DateTime? tempWakeTime = _log.wakeTime;

        // Use a StatefulBuilder so the dialog can update itself
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: Text('Edit Sleep Times'),
              contentPadding: EdgeInsets.zero,
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(Icons.hotel_outlined),
                      title: Text('Bed Time'),
                      subtitle: Text(_formatTime(tempBedTime)),
                      onTap: () async {
                        final newTime = await _selectDateTime(tempBedTime);
                        if (newTime != null) {
                          dialogSetState(() {
                            tempBedTime = newTime;
                          });
                        }
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.nightlight_round),
                      title: Text('Fell Asleep Time'),
                      subtitle: Text(_formatTime(tempFellAsleepTime)),
                      onTap: () async {
                        final newTime =
                            await _selectDateTime(tempFellAsleepTime);
                        if (newTime != null) {
                          dialogSetState(() {
                            tempFellAsleepTime = newTime;
                          });
                        }
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.wb_sunny_outlined),
                      title: Text('Wake Time'),
                      subtitle: Text(_formatTime(tempWakeTime)),
                      onTap: () async {
                        final newTime = await _selectDateTime(tempWakeTime);
                        if (newTime != null) {
                          dialogSetState(() {
                            tempWakeTime = newTime;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text('Save'),
                  onPressed: () {
                    // On save, update the *real* log object
                    final newSummary = _recalculateSleepSummary(
                        tempBedTime, tempWakeTime, tempFellAsleepTime);

                    setState(() {
                      _log.bedTime = tempBedTime;
                      _log.fellAsleepTime = tempFellAsleepTime;
                      _log.wakeTime = tempWakeTime;
                      _log.sleepSummary = newSummary;
                      _log.isSleeping = false; // Manually editing implies not sleeping
                    });

                    _logService.saveDailyLog(widget.date, _log);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Builds the summary card for sleep data.
  Widget _buildSleepSummaryCard() {
    // Show a simple "add" card if no sleep is logged
    if (_log.bedTime == null && _log.wakeTime == null) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.king_bed_outlined, color: Colors.indigo[800]),
          title: Text('No Sleep Logged'),
          subtitle: Text('Tap to add a sleep entry.'),
          trailing: Icon(Icons.add_circle_outline),
          onTap: _showSleepEditDialog,
        ),
      );
    }

    // Show the full summary card
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.king_bed_outlined, color: Colors.indigo[800]),
              title: Text('Sleep Data'),
              subtitle: Text(
                _log.sleepSummary ?? 'Tap to edit',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: Icon(Icons.edit_outlined),
                onPressed: _showSleepEditDialog,
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SleepTimeChip(
                      label: 'Bed', time: _formatTime(_log.bedTime)),
                  _SleepTimeChip(
                      label: 'Asleep',
                      time: _formatTime(_log.fellAsleepTime)),
                  _SleepTimeChip(
                      label: 'Woke', time: _formatTime(_log.wakeTime)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
          // Use a ListView so it scrolls on small screens
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildSleepSummaryCard(),
                const SizedBox(height: 16),
                _EventButton(
                  label: _log.dayType?.displayName ?? 'Type of Day',
                  icon: _log.dayType?.icon ?? Icons.wb_sunny_outlined,
                  color: _log.dayType?.color ?? Colors.indigo[800]!,
                  onPressed: _showDayTypeDialog,
                ),
                const SizedBox(height: 16),
                _EventButton(
                  label: 'Medication & Caffeine',
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
                  label: 'Exercise',
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

/// A small helper widget to display sleep times in the [EventScreen] card.
class _SleepTimeChip extends StatelessWidget {
  const _SleepTimeChip({required this.label, required this.time});
  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
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

/// A reusable, styled button for the [EventScreen].
/// Designed as a Card with an InkWell for a clean, tappable feel.
class _EventButton extends StatelessWidget {
  const _EventButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });
  final String label;
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
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const Spacer(), // Pushes the arrow to the right
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Displays a calendar view for selecting and editing past log entries.
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
    // Normalize to midnight UTC for consistent map keys
    _selectedDay = DateTime.utc(now.year, now.month, now.day);
    _loadAllLogs();
  }

  /// Loads all logs from storage and updates the calendar.
  Future<void> _loadAllLogs() async {
    final logs = await _logService.getAllLogs();
    setState(() {
      _logsByDate = logs;
    });
  }

  /// Provides the list of "events" (DayType) for a given day.
  /// Used by [TableCalendar] to know what to pass to the marker builder.
  List<Object> _getEventsForDay(DateTime day) {
    final utcDay = DateTime.utc(day.year, day.month, day.day);
    final log = _logsByDate[utcDay];

    if (log != null && log.dayType != null) {
      return [log.dayType!]; // Return the DayType enum
    }
    return []; // No events
  }

  /// Called when a user taps a day on the calendar.
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final utcSelectedDay =
        DateTime.utc(selectedDay.year, selectedDay.month, selectedDay.day);

    if (!isSameDay(_selectedDay, utcSelectedDay)) {
      setState(() {
        _selectedDay = utcSelectedDay;
        _focusedDay = focusedDay;
      });

      // Navigate to the EventScreen for the date the user tapped
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventScreen(date: utcSelectedDay),
        ),
      ).then((_) => _loadAllLogs()); // Reload data when returning
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
            selectedDayPredicate: (day) {
              // Use isSameDay to compare UTC dates correctly
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: _onDaySelected,
            eventLoader: _getEventsForDay,

            // --- Calendar Dot Builder ---
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isNotEmpty) {
                  // The event is our DayType enum
                  final dayType = events[0] as DayType;
                  return Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: dayType.color, // Use the DayType's color!
                      shape: BoxShape.circle,
                    ),
                  );
                }
                return null; // No marker
              },
            ),
            // --- Calendar Styling ---
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.deepOrange[300], // Accent color for today
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.indigo[600], // Primary color for selected
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false, // Hide "2 weeks" button
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay; // Update focused day on page swipe
            },
          ),
        ),
      ),
    );
  }
}

/// Screen for logging exercise entries for a specific date.
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
    setState(() {
      _isLoading = true;
    });
    final log = await _logService.getDailyLog(widget.date);
    setState(() {
      _log = log;
      _isLoading = false;
    });
  }

  /// Saves the current state of `_log` to storage.
  Future<void> _saveLog() async {
    await _logService.saveDailyLog(widget.date, _log);
  }

  /// Helper to show a [TimeOfDay] picker.
  Future<TimeOfDay?> _showTimePicker(TimeOfDay initialTime,
      {required String helpText}) async {
    return await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: helpText,
    );
  }

  /// The full flow for adding a new exercise entry.
  Future<void> _addExerciseEntry() async {
    // 1. Show Type dialog
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
    if (type == null) return; // User cancelled

    // 2. Show Start Time picker
    final TimeOfDay? startTime = await _showTimePicker(
      TimeOfDay.now(),
      helpText: 'Select Start Time',
    );
    if (startTime == null) return; // User cancelled

    // 3. Show Finish Time picker
    final TimeOfDay? finishTime = await _showTimePicker(
      startTime, // Start at the same time
      helpText: 'Select Finish Time',
    );
    if (finishTime == null) return; // User cancelled

    // 4. Combine Date + Time
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

    // 5. Validate times
    if (finishDateTime.isBefore(startDateTime)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Finish time cannot be before start time.')),
        );
      }
      return;
    }

    // 6. Create entry, update state, and save
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

  /// Deletes an exercise entry at a specific index.
  void _deleteExerciseEntry(int index) {
    setState(() {
      _log.exerciseLog.removeAt(index);
    });
    _saveLog();
  }

  /// Helper to calculate and format duration string.
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
                  // --- List Header ---
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
                  // --- List of Entries ---
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
                  // --- Add Button ---
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

/// Screen for logging medication and caffeine entries.
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
    setState(() {
      _isLoading = true;
    });
    final log = await _logService.getDailyLog(widget.date);
    setState(() {
      _log = log;
      _isLoading = false;
    });
  }

  Future<void> _saveLog() async {
    await _logService.saveDailyLog(widget.date, _log);
  }

  /// Full flow for adding a new caffeine entry.
  Future<void> _addCaffeineEntry() async {
    // 1. Show Amount dialog
    final String? amount = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select Amount'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'One cup'),
            child: Text('One cup'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Two cups'),
            child: Text('Two cups'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Three cups'),
            child: Text('Three cups'),
          ),
        ],
      ),
    );
    if (amount == null) return; // User cancelled

    // 2. Show Time picker
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Select Caffeine Time',
    );
    if (time == null) return; // User cancelled

    // 3. Create entry, update state, and save
    final DateTime entryTime = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      time.hour,
      time.minute,
    );
    final newEntry = CaffeineEntry(amount: amount, time: entryTime);
    setState(() {
      _log.caffeineLog.add(newEntry);
    });
    _saveLog();
  }

  /// Full flow for adding a new medication entry.
  Future<void> _addMedicationEntry() async {
    // 1. Show Type dialog
    final String? type = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select Medication'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Medication'),
            child: Text('Medication'),
          ),
        ],
      ),
    );
    if (type == null) return; // User cancelled

    // 2. Show Time picker
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Select Medication Time',
    );
    if (time == null) return; // User cancelled

    // 3. Create entry, update state, and save
    final DateTime entryTime = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      time.hour,
      time.minute,
    );
    final newEntry = MedicationEntry(type: type, time: entryTime);
    setState(() {
      _log.medicationLog.add(newEntry);
    });
    _saveLog();
  }

  void _deleteCaffeineEntry(int index) {
    setState(() {
      _log.caffeineLog.removeAt(index);
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
            const Text('Medication & Caffeine', style: TextStyle(fontSize: 20)),
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
                  // --- Caffeine Section ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Caffeine Log',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: _log.caffeineLog.asMap().entries.map((entry) {
                      int idx = entry.key;
                      CaffeineEntry item = entry.value;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Icon(Icons.coffee_outlined,
                              color: Colors.brown[600]),
                          title: Text(item.amount,
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle:
                              Text(DateFormat('h:mm a').format(item.time)),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteCaffeineEntry(idx),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Caffeine Entry'),
                    onPressed: _addCaffeineEntry,
                  ),
                  const SizedBox(height: 32),

                  // --- Medication Section ---
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
                          title: Text(item.type,
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

/// Displays app settings and a button to clear all data.
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
              OutlinedButton.icon(
                icon: Icon(Icons.delete_forever_outlined),
                label: const Text('Clear All Saved Data'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[700],
                  side: BorderSide(color: Colors.red[700]!),
                ),
                onPressed: () async {
                  // Show a confirmation dialog before deleting
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

                  // If user confirmed, clear data
                  if (confirmed == true) {
                    await LogService().clearAllData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('All saved data has been cleared!')),
                      );
                      // Pop all screens until we're back at the home screen
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

/// A screen for taking and saving notes for a specific date.
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

  /// Loads the notes for [widget.date] into the text controller.
  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });
    final log = await _logService.getDailyLog(widget.date);
    setState(() {
      _controller.text = log.notes ?? "";
      _isLoading = false;
    });
  }

  /// Saves the current text in the controller to storage.
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
    _controller.dispose(); // Clean up the controller
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
              // Put the text field in a Card for consistent styling
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
                       border: InputBorder.none, // Clean look inside Card
                    ),
                    maxLines: 20, // Allow plenty of space for notes
                    autofocus: true, // Open keyboard immediately
                  ),
                ),
              ),
            ),
    );
  }
}