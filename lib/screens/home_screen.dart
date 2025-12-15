import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../log_service.dart';
import '../models.dart';
import 'event_screen.dart';
import 'stats_screen.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DailyLog _todayLog = DailyLog();
  Category? _dayType; // selected day type variable is currently unused
  String _sleepMessage = "Welcome! Tap 'Going to sleep' to start.";
  bool _isLoading = true;
  final LogService _logService = LogService();

  @override
  void initState() {
    super.initState();
    _loadTodayLog();
  }

  String _formatHoursToHHhMMm(double hours) {
  // format hours as {HH}h{MM}m
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
            _sleepMessage = "Logged $sessions sleep session(s).\nTotal: ${_formatHoursToHHhMMm(totalHours)}";
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
       _sleepMessage = "Logged $sessions sleep session(s).\nTotal: ${_formatHoursToHHhMMm(totalHours)}";
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
              leading: Icon(Icons.add_task_outlined),
              title: Text('Today\'s Events'),
              onTap: () {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventScreen(date: today),
                  ),
                );
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
