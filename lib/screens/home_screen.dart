import 'dart:math'; // Required for the clock calculations
import 'dart:ui' as ui; // Added to resolve TextDirection ambiguity
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../log_service.dart';
import '../models.dart';
import 'event_screen.dart';
import 'stats_screen.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';
// Specific Activity Screens
import 'medication_screen.dart';
import 'caffeine_alcohol_screen.dart';
import 'exercise_screen.dart';
import 'notes_screen.dart';
import 'category_management_screen.dart';

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
  List<Category> _dayTypes = [];
  
  DateTime _loadedDate = DateTime.now(); 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTodayLog();
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
    } catch (e) {
      setState(() => _sleepMessage = "Error loading data. Please try again.");
    } finally {
      setState(() => _isLoading = false);
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
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (!isSameDay(_loadedDate, today)) {
       print("Sleep cycle finished for yesterday. Switching to today.");
       await Future.delayed(Duration(milliseconds: 500));
       _loadTodayLog(); 
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
    _todayLog.substanceLog.add(newEntry);
    await _logService.saveDailyLog(_loadedDate, _todayLog);

    // Show brief notification
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$cups cup of caffeine logged at ${DateFormat('h:mm a').format(now)}'),
          duration: Duration(seconds: 2),
        ),
      );
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
                children: [
                  Icon(Icons.settings, color: Colors.grey),
                  const SizedBox(width: 16),
                  Text('Manage Categories'),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (selectedType != null) {
      setState(() {
        _todayLog.dayTypeId = selectedType.id;
      });
      await _logService.saveDailyLog(_loadedDate, _todayLog);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAsleep = _todayLog.isSleeping;
    final bool isAwakeInBed = _todayLog.isAwakeInBed;
    // Always show clock if there is data, or if requested to always be visible
    final bool showClock = _todayLog.sleepLog.isNotEmpty || isAsleep || isAwakeInBed;

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
                                color: Colors.blueGrey[800], 
                                height: 1.4,
                                fontWeight: FontWeight.w500
                              ),
                            ),
                            // --- Sleep Clock Visualization ---
                            if (showClock) ...[
                              const SizedBox(height: 24),
                              SleepClock(
                                sleepLog: _todayLog.sleepLog,
                                isSleeping: isAsleep,
                                bedTime: _todayLog.currentBedTime,
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
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        decoration: BoxDecoration(
                          color: currentDayType?.color.withAlpha(26) ?? Colors.grey[200],
                          border: Border.all(
                            color: currentDayType?.color ?? Colors.grey[400]!,
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
                                color: currentDayType?.color ?? Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    const Divider(height: 1, color: Colors.black12),
                    const SizedBox(height: 32),
                    
                    // --- ACTIVITIES GRID (Replaces "Add Event" button) ---
                    Text(
                      "Activities & Logs", 
                      style: TextStyle(
                        color: Colors.grey[600], 
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
                        _SquareButton(
                          icon: Icons.coffee_outlined,
                          label: "+1 Caffeine",
                          color: Colors.brown,
                          onPressed: _addOneCaffeine,
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
                        _SquareButton(
                          icon: Icons.bar_chart,
                          label: "Statistics",
                          color: Colors.purple,
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()));
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
  final Color color;

  const _SquareButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null;
    return Material(
      color: isEnabled ? Colors.white : Colors.grey[100],
      elevation: isEnabled ? 2 : 0,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isEnabled ? color.withAlpha(26) : Colors.transparent, 
              width: 1
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isEnabled ? color.withAlpha(26) : Colors.grey[200],
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
                  color: isEnabled ? Colors.black87 : Colors.grey[400],
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
  final List<SleepEntry> sleepLog;
  final bool isSleeping;
  final DateTime? bedTime;

  const SleepClock({
    super.key, 
    required this.sleepLog, 
    this.isSleeping = false,
    this.bedTime
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220, 
      height: 220,
      child: CustomPaint(
        painter: SleepClockPainter(sleepLog, isSleeping, bedTime),
      ),
    );
  }
}

class SleepClockPainter extends CustomPainter {
  final List<SleepEntry> sleepLog;
  final bool isSleeping;
  final DateTime? currentBedTime;

  SleepClockPainter(this.sleepLog, this.isSleeping, this.currentBedTime);

  // Helper to convert Hour (0-24) to Angle (radians)
  // With canvas rotated -90deg: 0h = 0 rad (Top), 6h = pi/2 (Right), 12h = pi (Bottom)
  double getAngle(double hour) {
    return hour * (pi / 12);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    
    // Styling constants
    final double tickLength = 6.0;
    final double numberRadius = radius - 20;

    // ROTATE CANVAS: Make 0 radians point to Top (North)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-pi / 2);
    canvas.translate(-center.dx, -center.dy);

    // 1. Draw Dial Background
    final bgPaint = Paint()
      ..color = Colors.grey[100]!
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);
    
    final borderPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);

    // 2. Draw Numbers & Ticks
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    final tickPaint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1;

    // We want numbers 0, 2, 4 ... 22
    for (int i = 0; i < 24; i++) {
      final angle = getAngle(i.toDouble());
      
      // Draw Tick
      final tickStart = Offset(
        center.dx + (radius - tickLength) * cos(angle),
        center.dy + (radius - tickLength) * sin(angle),
      );
      final tickEnd = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      
      // Thicker ticks for main hours (0, 6, 12, 18)
      if (i % 6 == 0) {
        tickPaint.strokeWidth = 2;
        tickPaint.color = Colors.indigo[200]!;
      } else {
        tickPaint.strokeWidth = 1;
        tickPaint.color = Colors.grey[300]!;
      }
      canvas.drawLine(tickStart, tickEnd, tickPaint);

      // Draw Number (Even only)
      if (i % 2 == 0) {
        final textStyle = TextStyle(
          color: (i % 6 == 0) ? Colors.indigo : Colors.grey[600],
          fontSize: (i % 6 == 0) ? 14 : 11,
          fontWeight: (i % 6 == 0) ? FontWeight.bold : FontWeight.normal,
        );
        
        textPainter.text = TextSpan(text: i.toString(), style: textStyle);
        textPainter.layout();
        
        // Calculate position in rotated system
        final textX = center.dx + numberRadius * cos(angle);
        final textY = center.dy + numberRadius * sin(angle);

        // Draw Text: Temporarily rotate back 90deg so text appears upright
        canvas.save();
        canvas.translate(textX, textY);
        canvas.rotate(pi / 2); 
        canvas.translate(-textPainter.width / 2, -textPainter.height / 2); 
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }

    // 3. Draw Completed Sleep Arcs
    final sleepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt // butt ends for cleaner continuous segments if adjacent
      ..strokeWidth = 12.0;

    for (var entry in sleepLog) {
      double startHour = entry.bedTime.hour + entry.bedTime.minute / 60.0;
      double durationHours = entry.durationHours; 

      if (durationHours <= 0) continue; // Skip zero or negative durations
      
      double startAngle = getAngle(startHour);
      double sweepAngle = durationHours * (pi / 12);

      // Use a gradient shader for the arc
      final Rect arcRect = Rect.fromCircle(center: center, radius: radius - 35);
      
      // Gradient shader aligns naturally with the rotated canvas (0 is top)
      sleepPaint.shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [Colors.indigo[300]!, Colors.indigo[500]!],
        transform: GradientRotation(startAngle),
      ).createShader(arcRect);

      canvas.drawArc(arcRect, startAngle, sweepAngle, false, sleepPaint);
    }

    // 4. Draw Active Sleep Arc (if currently sleeping)
    if (isSleeping && currentBedTime != null) {
      // START FROM 0 (Top) as requested to show duration
      // Instead of using bedTime hour, we start at angle 0.
      double startAngle = getAngle(0);
      
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

    // 5. Draw Current Time Indicator (REMOVED)

    canvas.restore(); // Restore the main rotation
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}