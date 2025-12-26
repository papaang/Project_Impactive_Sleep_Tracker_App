import 'dart:math'; // Required for the clock calculations
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Required for response type
import '../log_service.dart';
import '../notification_service.dart'; // Import the new service
import '../models.dart';
import 'event_screen.dart';
import 'stats_screen.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';
import 'category_management_screen.dart'; // Import for Manage Categories

// Specific Activity Screens
import 'medication_screen.dart';
import 'caffeine_alcohol_screen.dart';
import 'exercise_screen.dart';
import 'notes_screen.dart';
import 'sleep_graph_screen.dart'; 
import 'sleep_heatmap_screen.dart'; 
import 'mid_sleep_graph_screen.dart'; 
import 'sleep_efficiency_screen.dart';
import 'correlation_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  DailyLog _todayLog = DailyLog();
  String _sleepMessage = "Welcome! Tap 'Going to sleep' to start.";
  bool _isLoading = true;
  final LogService _logService = LogService();
  final NotificationService _notificationService = NotificationService(); 
  List<Category> _dayTypes = [];
  
  DateTime _loadedDate = DateTime.now(); 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationService.init(_handleNotificationResponse);
    _loadTodayLog();
  }

  void _handleNotificationResponse(NotificationResponse response) async {
    if (response.actionId == 'add_meds') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MedicationScreen(date: _loadedDate, autoOpenAdd: true)),
      );
      _loadTodayLog();
    } else if (response.actionId == 'add_caffeine') {
       await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CaffeineAlcoholScreen(date: _loadedDate, autoOpenAdd: true)),
      );
      _loadTodayLog();
    } else if (response.actionId == 'add_exercise') {
       await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ExerciseScreen(date: _loadedDate, autoOpenAdd: true)),
      );
      _loadTodayLog();
    } else if (response.actionId == 'sleep') {
      if (!_todayLog.isSleeping) await _handleGoingToSleep();
    } else if (response.actionId == 'wake_up') {
      if (_todayLog.isSleeping) await _handleWakingUp();
    }
  }

  void _updateNotification() {
    _notificationService.showPersistentControls(isSleeping: _todayLog.isSleeping);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDayChange();
      _loadTodayLog(); 
    }
  }

  Future<void> _checkDayChange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (!isSameDay(_loadedDate, today)) {
      if (!_todayLog.isSleeping && !_todayLog.isAwakeInBed) {
        print("Day changed, reloading for today.");
        _loadTodayLog();
      } else {
        print("Day changed, but keeping yesterday loaded to finish sleep.");
      }
    }
  }

  String _formatHoursToHHhMMm(double hours) {
    int h = hours.floor();
    int m = ((hours - h) * 60).round();
    return '${h.toString().padLeft(2, '0')}h${m.toString().padLeft(2, '0')}m';
  }

  Future<void> _loadTodayLog() async {
    try {
      setState(() => _isLoading = true);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final log = await _logService.getDailyLog(today);
      final dayTypes = await CategoryManager().getCategories('day_types');

      setState(() {
        _todayLog = log;
        _dayTypes = dayTypes;
        _loadedDate = today; 

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
            _sleepMessage = "Logged $sessions sleep session(s).\nTotal: ${_formatHoursToHHhMMm(totalHours)}";
          } else {
            _sleepMessage = "Welcome! Tap 'Going to sleep' to start.";
          }
        }
      });
      _updateNotification();
    } catch (e) {
      setState(() => _sleepMessage = "Error loading data. Please try again.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addOneCaffeine() async {
    int cups = 1; // Default to 1 cup
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (!isSameDay(_loadedDate, today)) {
      _loadedDate = today;
      _todayLog = await _logService.getDailyLog(today);
    }

    final newEntry = SubstanceEntry(
      substanceTypeId: 'coffee',
      amount: cups.toString(),
      time: now,
    );
    
    setState(() {
      _todayLog.substanceLog.add(newEntry);
    });
    
    await _logService.saveDailyLog(_loadedDate, _todayLog);

    // Show brief notification
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$cups cup of caffeine logged at ${DateFormat('h:mm a').format(now)}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleGoingToSleep() async {
    final DateTime now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (!isSameDay(_loadedDate, today)) {
       _loadedDate = today;
       _todayLog = await _logService.getDailyLog(today); 
    }

    _todayLog.currentBedTime = now;
    _todayLog.isSleeping = true;
    _todayLog.isAwakeInBed = false;
    _todayLog.currentWakeTime = null;
    _todayLog.currentFellAsleepTime = null;

    setState(() {
      _sleepMessage = "Good night! In bed since: ${DateFormat('h:mm a').format(now)}";
    });
    
    await _logService.saveDailyLog(_loadedDate, _todayLog);
    _updateNotification();
  }

  Future<void> _handleWakingUp() async {
    final DateTime wakeTime = DateTime.now();
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

    await _logService.saveDailyLog(_loadedDate, _todayLog);
    _updateNotification();
  }

  Future<void> _handleOutOfBed() async {
    final DateTime outTime = DateTime.now();
    
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
       _sleepMessage = "Logged $sessions sleep session(s).\nTotal: ${_formatHoursToHHhMMm(totalHours)}";
    });

    await _logService.saveDailyLog(_loadedDate, _todayLog);
    _updateNotification();
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (!isSameDay(_loadedDate, today)) {
       print("Sleep cycle finished for yesterday. Switching to today.");
       await Future.delayed(Duration(milliseconds: 500));
       _loadTodayLog(); 
    }
  }

  Future<void> _showDayTypeDialog() async {
    final Category? selectedType = await showDialog<Category>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Select Day Type'),
          children: [
            ..._dayTypes.map((type) {
              return SimpleDialogOption(
                onPressed: () => Navigator.pop(context, type),
                child: Row(
                  children: [
                    Icon(type.icon, color: type.color),
                    const SizedBox(width: 16),
                    Text(type.name),
                  ],
                ),
              );
            }),
            // Option to add new day types inline (Other...)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, Category(id: '__new__', name: 'Other', iconName: 'add', colorHex: '0xFF000000')),
              child: Row(
                children: const [
                  Icon(Icons.add, color: Colors.grey),
                  SizedBox(width: 16),
                  Text('Other...'),
                ],
              ),
            ),
            const Divider(),
            // Manage Categories Option
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(context); // Close the dialog
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
                );
                // Reload day types after returning from category management
                final dayTypes = await CategoryManager().getCategories('day_types');
                setState(() {
                  _dayTypes = dayTypes;
                });
              },
              child: Row(
                children: const [
                  Icon(Icons.settings, color: Colors.grey),
                  SizedBox(width: 16),
                  Text('Manage Categories'),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (selectedType != null) {
      if (selectedType.id == '__new__') {
        final TextEditingController textController = TextEditingController();
        final String? newName = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('New Day Type'),
            content: TextField(
              controller: textController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g. Study, Sick Day',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, textController.text),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
        );

        if (newName != null && newName.trim().isNotEmpty) {
          final String name = newName.trim();
          final String id = name.toLowerCase().replaceAll(RegExp(r'\s+'), '_') + '_${DateTime.now().millisecondsSinceEpoch}';
          
          final newCategory = Category(
            id: id,
            name: name,
            iconName: 'wb_sunny_outlined',
            colorHex: '0xFF607D8B', 
          );

          setState(() {
            _dayTypes.add(newCategory);
            _todayLog.dayTypeId = newCategory.id;
          });
          
          await CategoryManager().saveCategories('day_types', _dayTypes);
          await _logService.saveDailyLog(_loadedDate, _todayLog);
        }
      } else {
        setState(() {
          _todayLog.dayTypeId = selectedType.id;
        });
        await _logService.saveDailyLog(_loadedDate, _todayLog);
      }
    }
  }

  Future<void> _resetDayType() async {
    setState(() {
      _todayLog.dayTypeId = null;
    });
    await _logService.saveDailyLog(_loadedDate, _todayLog);

    // Show notification
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Day type reset'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAsleep = _todayLog.isSleeping;
    final bool isAwakeInBed = _todayLog.isAwakeInBed;
    // Always show clock if there is data, or if requested to always be visible
    final bool showClock = _todayLog.sleepLog.isNotEmpty || isAsleep || isAwakeInBed;
    
    // Check Dark Mode
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Resolve Day Type for display
    final Category? currentDayType = _dayTypes
        .where((c) => c.id == _todayLog.dayTypeId)
        .firstOrNull;

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
              leading: Icon(Icons.add_task_outlined),
              title: Text('Today\'s Events'),
              onTap: () {
                Navigator.pop(context);
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
            ListTile(
              leading: Icon(Icons.leaderboard_outlined),
              title: Text('Statistics'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.calendar_month_outlined),
              title: Text('Past Entries Calendar'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen()));
              },
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
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- STATUS CARD ---
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            if (!showClock) ...[
                              Icon(
                                isAsleep 
                                  ? Icons.bedtime_outlined 
                                  : (isAwakeInBed ? Icons.accessibility_new : Icons.info_outline),
                                color: Colors.indigo,
                                size: 36,
                              ),
                              const SizedBox(height: 16),
                            ],
                            Text(
                              _sleepMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16, 
                                color: isDark ? Colors.white70 : Colors.blueGrey[800], 
                                height: 1.4,
                                fontWeight: FontWeight.w500
                              ),
                            ),
                            // --- Sleep Clock Visualization ---
                            if (showClock) ...[
                              const SizedBox(height: 24),
                              SleepClock(
                                dailyLog: _todayLog, // Pass the whole log
                                isSleeping: isAsleep,
                                bedTime: _todayLog.currentBedTime,
                                isDark: isDark,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- SLEEP CONTROLS ---
                    if (!isAwakeInBed) 
                      Row(
                        children: [
                          Expanded(
                            child: _SquareButton(
                              icon: Icons.wb_sunny_outlined,
                              label: "Wake Up",
                              color: Colors.orange,
                              onPressed: isAsleep ? _handleWakingUp : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _SquareButton(
                              icon: Icons.bedtime_outlined,
                              label: "Sleep",
                              color: Colors.indigo,
                              onPressed: (!isAsleep) ? _handleGoingToSleep : null,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _SquareButton(
                              icon: Icons.directions_walk,
                              label: "Got Out of Bed",
                              color: Colors.green,
                              onPressed: _handleOutOfBed,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 24),
                    
                    // --- DAY TYPE SELECTOR ---
                    InkWell(
                      onTap: _showDayTypeDialog,
                      onLongPress: _resetDayType,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        decoration: BoxDecoration(
                          color: currentDayType?.color.withOpacity(0.1) ?? (isDark ? Colors.grey[800] : Colors.grey[200]),
                          border: Border.all(
                            color: currentDayType?.color ?? (isDark ? Colors.grey[700]! : Colors.grey[400]!),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              currentDayType?.icon ?? Icons.help_outline,
                              color: currentDayType?.color ?? Colors.grey[600],
                            ),
                            const SizedBox(width: 12),
                            Text(
                              currentDayType?.displayName ?? "Set Type of Day",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: currentDayType?.color ?? (isDark ? Colors.grey[400] : Colors.grey[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.black12),
                    const SizedBox(height: 32),
                    
                    // --- ACTIVITIES GRID ---
                    Text(
                      "Activities & Logs", 
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600], 
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      )
                    ),
                    const SizedBox(height: 16),
                    
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.0,
                      children: [
                        _SquareButton(
                          icon: Icons.medication_outlined,
                          label: "Medication",
                          color: Colors.green,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => MedicationScreen(date: _loadedDate)),
                            ).then((_) => _loadTodayLog());
                          },
                        ),
                        // --- UPDATED: Quick Add Caffeine Button ---
                        _SquareButton(
                          icon: Icons.coffee,
                          label: "+1 Caffeine",
                          color: Colors.brown,
                          onPressed: _addOneCaffeine, // Quick Add
                          onLongPress: () { // Full Screen on Long Press
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => CaffeineAlcoholScreen(date: _loadedDate)),
                            ).then((_) => _loadTodayLog());
                          },
                        ),
                        _SquareButton(
                          icon: Icons.fitness_center_outlined,
                          label: "Exercise",
                          color: Colors.orange,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ExerciseScreen(date: _loadedDate)),
                            ).then((_) => _loadTodayLog());
                          },
                        ),
                        _SquareButton(
                          icon: Icons.note_alt_outlined,
                          label: "Notes",
                          color: Colors.grey,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => NotesScreen(date: _loadedDate)),
                            ).then((_) => _loadTodayLog());
                          },
                        ),
                        // --- STATS & GRAPHS ---
                        _SquareButton(
                          icon: Icons.bar_chart,
                          label: "Statistics",
                          color: Colors.purple,
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()));
                          },
                        ),
                        _SquareButton(
                          icon: Icons.ssid_chart,
                          label: "Sleep Graph",
                          color: Colors.indigoAccent,
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SleepGraphScreen()));
                          },
                        ),
                        _SquareButton(
                          icon: Icons.grid_on,
                          label: "Heatmap",
                          color: Colors.deepPurpleAccent,
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SleepHeatmapScreen()));
                          },
                        ),
                        _SquareButton(
                          icon: Icons.show_chart, 
                          label: "Circadian Drift",
                          color: Colors.tealAccent.shade700,
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const MidSleepGraphScreen()));
                          },
                        ),
                        _SquareButton(
                          icon: Icons.scatter_plot, 
                          label: "Correlations",
                          color: Colors.orangeAccent.shade700,
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const CorrelationScreen()));
                          },
                        ),
                        _SquareButton(
                          icon: Icons.pie_chart_outline,
                          label: "Efficiency",
                          color: Colors.blueAccent,
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SleepEfficiencyScreen()));
                          },
                        ),
                      
                        _SquareButton(
                          icon: Icons.calendar_month_outlined,
                          label: "History",
                          color: Colors.teal,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CalendarScreen()),
                            ).then((_) => _loadTodayLog());
                          },
                        ),
                        _SquareButton(
                          icon: Icons.settings_outlined,
                          label: "Settings",
                          color: Colors.blueGrey,
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}

// --- NEW SQUARE BUTTON WIDGET ---
class _SquareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress; // Added onLongPress
  final Color color;

  const _SquareButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.onLongPress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color backgroundColor = isEnabled 
        ? (isDark ? const Color(0xFF1E1E1E) : Colors.white) 
        : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]!);
    
    final Color iconBgColor = isEnabled 
        ? color.withOpacity(isDark ? 0.2 : 0.1) 
        : (isDark ? Colors.grey[800]! : Colors.grey[200]!);

    final Color textColor = isEnabled
        ? (isDark ? Colors.white70 : Colors.black87)
        : Colors.grey[400]!;

    return Material(
      color: backgroundColor,
      elevation: isEnabled ? 2 : 0,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onPressed,
        onLongPress: onLongPress, // Hooked up
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isEnabled 
                  ? color.withOpacity(0.1) 
                  : Colors.transparent, 
              width: 1
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon, 
                  size: 32, 
                  color: isEnabled ? color : Colors.grey[400]
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 24-Hour Sleep Clock ---
class SleepClock extends StatelessWidget {
  final DailyLog dailyLog; // Changed from List<SleepEntry>
  final bool isSleeping;
  final DateTime? bedTime;
  final bool isDark;

  const SleepClock({
    super.key, 
    required this.dailyLog, 
    this.isSleeping = false,
    this.bedTime,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220, 
      height: 220,
      child: CustomPaint(
        painter: SleepClockPainter(dailyLog, isSleeping, bedTime, isDark),
      ),
    );
  }
}

class SleepClockPainter extends CustomPainter {
  final DailyLog dailyLog;
  final bool isSleeping;
  final DateTime? currentBedTime;
  final bool isDark;

  SleepClockPainter(this.dailyLog, this.isSleeping, this.currentBedTime, this.isDark);

  // Helper to convert Hour (0-24) to Angle (radians)
  // With canvas rotated -90deg: 0h = 0 rad (Top), 6h = pi/2 (Right), 12h = pi (Bottom)
  double getAngle(double hour) {
    return hour * (pi / 12);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final double tickLength = 6.0;
    final double numberRadius = radius - 20;

    // ROTATE CANVAS (-90 deg)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-pi / 2);
    canvas.translate(-center.dx, -center.dy);

    // 1. Draw Dial Background
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF121212) : Colors.grey[100]!
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);
    
    final borderPaint = Paint()
      ..color = isDark ? Colors.grey[800]! : Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);

    // 2. Draw Ticks & Numbers
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    final tickPaint = Paint()
      ..color = isDark ? Colors.grey[700]! : Colors.grey[400]!
      ..strokeWidth = 1;

    for (int i = 0; i < 24; i++) {
      final angle = getAngle(i.toDouble());
      
      final tickStart = Offset(
        center.dx + (radius - tickLength) * cos(angle),
        center.dy + (radius - tickLength) * sin(angle),
      );
      final tickEnd = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      
      if (i % 6 == 0) {
        tickPaint.strokeWidth = 2;
        tickPaint.color = Colors.indigo[200]!;
      } else {
        tickPaint.strokeWidth = 1;
        tickPaint.color = isDark ? Colors.grey[700]! : Colors.grey[300]!;
      }
      canvas.drawLine(tickStart, tickEnd, tickPaint);

      if (i % 2 == 0) {
        final textStyle = TextStyle(
          color: (i % 6 == 0) ? Colors.indigo : (isDark ? Colors.grey[500] : Colors.grey[600]),
          fontSize: (i % 6 == 0) ? 14 : 11,
          fontWeight: (i % 6 == 0) ? FontWeight.bold : FontWeight.normal,
        );
        
        textPainter.text = TextSpan(text: i.toString(), style: textStyle);
        textPainter.layout();
        
        final textX = center.dx + numberRadius * cos(angle);
        final textY = center.dy + numberRadius * sin(angle);

        canvas.save();
        canvas.translate(textX, textY);
        canvas.rotate(pi / 2); 
        canvas.translate(-textPainter.width / 2, -textPainter.height / 2); 
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }

    // 3. Draw Completed Sleep Arcs (SOLID COLOR for visibility)
    final sleepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt 
      ..strokeWidth = 12.0
      ..color = Colors.indigo.withOpacity(isDark ? 0.6 : 0.5); // Solid color

    for (var entry in dailyLog.sleepLog) {
      double startHour = entry.bedTime.hour + entry.bedTime.minute / 60.0;
      double durationHours = entry.durationHours; 

      if (durationHours <= 0) continue;
      
      double startAngle = getAngle(startHour);
      double sweepAngle = durationHours * (pi / 12);
      
      final Rect arcRect = Rect.fromCircle(center: center, radius: radius - 35);
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, sleepPaint);
    }

    // 4. Draw Active Sleep Arc
    if (isSleeping && currentBedTime != null) {
      double startAngle = getAngle(0); // Top
      final now = DateTime.now();
      double durationMins = now.difference(currentBedTime!).inMinutes.toDouble();

      if (durationMins > 0) {
        double sweepAngle = (durationMins / 60.0) * (pi / 12);
        
        final activePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 12.0
          ..color = Colors.indigoAccent;
        
        final Rect arcRect = Rect.fromCircle(center: center, radius: radius - 35);
        canvas.drawArc(arcRect, startAngle, sweepAngle, false, activePaint);
      }
    }

    // 5. Draw Markers for Other Events (Meds, Caffeine, Exercise)
    void drawMarker(DateTime time, Color color) {
       double h = time.hour + time.minute / 60.0;
       double angle = getAngle(h);
       final pos = Offset(
         center.dx + (radius - 35) * cos(angle), // Same radius as sleep track
         center.dy + (radius - 35) * sin(angle)
       );
       
       // Draw dot
       canvas.drawCircle(pos, 5.0, Paint()..color = color);
       // Optional: white border for contrast
       canvas.drawCircle(pos, 5.0, Paint()..color = isDark ? Colors.black54 : Colors.white54..style = PaintingStyle.stroke..strokeWidth=1.5);
    }

    // Medication (Green)
    for (var m in dailyLog.medicationLog) {
       drawMarker(m.time, Colors.green);
    }
    // Caffeine/Substance (Brown)
    for (var s in dailyLog.substanceLog) {
       drawMarker(s.time, Colors.brown);
    }
    // Exercise (Orange)
    for (var e in dailyLog.exerciseLog) {
       drawMarker(e.startTime, Colors.orange);
    }

    canvas.restore(); // Restore the main rotation
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}