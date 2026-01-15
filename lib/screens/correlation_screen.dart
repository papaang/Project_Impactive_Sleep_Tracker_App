//Correlation Graph - How it works:
//This graph  is designed to help you visualize how the timing of your daily activities (Caffeine, Alcohol, and Exercise) impacts your ability to fall asleep.
// It analyzes the user's logged habits (caffeine, alcohol, exercise) over the past N days
// and correlates them with sleep latency (time taken to fall asleep).
// It fetches habit events from both the current day and the previous day relative to each sleep
// session to capture late-night habits.
// X-Axis (Horizontal): Represents the Time of Day the habit occurred.
// Y-Axis (Vertical): Represents the Sleep Latency (how many minutes it took to fall asleep) for the sleep session 
// immediately following those habits.
//
//The 16-Hour Rule: the app only plots habits that occurred within 16 hours of your bedtime.
//The "Latest Event" Logic: For each sleep session, it identifies the most recent occurrence of each habit type before bedtime.

//How to Read the Graph:
//High Dots: Indicate nights where you struggled to fall asleep (High Latency).
//Low Dots: Indicate nights where you fell asleep quickly (Low Latency).
//Clusters: If you see a cluster of Brown dots (Caffeine) high up on the right side of the graph, it suggests that consuming 
// caffeine late in the evening is strongly correlated with taking longer to fall asleep.
//Vertical Alignment: If dots of a certain color are consistently higher than others, that specific habit might be your primary sleep disruptor.



import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models.dart';
import '../log_service.dart';

class CorrelationScreen extends StatefulWidget {
  const CorrelationScreen({super.key});

  @override
  State<CorrelationScreen> createState() => _CorrelationScreenState();
}

enum HabitType { caffeine, alcohol, exercise, medication }

class ScatterPoint {
  final double time; // 0-24 hour format (relative to bed time day)
  final double latency; // minutes
  final HabitType type;
  
  ScatterPoint(this.time, this.latency, this.type);
}

class _CorrelationScreenState extends State<CorrelationScreen> {
  final LogService _logService = LogService();
  List<ScatterPoint> _points = [];
  bool _isLoading = true;

  // Settings
  final int _daysToAnalyze = 60; 

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final allLogs = await _logService.getAllLogs();
    List<ScatterPoint> points = [];
    
    final sortedKeys = allLogs.keys.toList()..sort();
    final cutoff = DateTime.now().subtract(Duration(days: _daysToAnalyze));
    final recentKeys = sortedKeys.where((d) => d.isAfter(cutoff));

    for (var date in recentKeys) {
      final log = allLogs[date]!;
      if (log.sleepLog.isEmpty) continue;

      // Analyze the first sleep session of this log
      final sleepEntry = log.sleepLog.first; 
      
      double latency = sleepEntry.sleepLatencyMinutes.toDouble();
      if (latency < 0) latency = 0;
      if (latency > 180) latency = 180; 

      DateTime bedTime = sleepEntry.bedTime;

      // --- FETCH HABITS FROM CURRENT AND PREVIOUS DAY ---
      List<SubstanceEntry> combinedSubstances = [];
      List<ExerciseEntry> combinedExercise = [];
      List<MedicationEntry> combinedMedications = [];

      // 1. Current Day
      combinedSubstances.addAll(log.substanceLog);
      combinedExercise.addAll(log.exerciseLog);
      combinedMedications.addAll(log.medicationLog);

      // 2. Previous Day
      final prevDate = date.subtract(const Duration(days: 1));
      // Need to find the key that matches prevDate 
      final prevDateNormalized = DateTime.utc(prevDate.year, prevDate.month, prevDate.day);
      
      if (allLogs.containsKey(prevDateNormalized)) {
        final prevLog = allLogs[prevDateNormalized]!;
        combinedSubstances.addAll(prevLog.substanceLog);
        combinedExercise.addAll(prevLog.exerciseLog);
        combinedMedications.addAll(prevLog.medicationLog);
      } else {
         // Fallback loop if keys aren't strictly UTC normalized in map
         for(var k in allLogs.keys) {
            if(k.year == prevDate.year && k.month == prevDate.month && k.day == prevDate.day) {
               combinedSubstances.addAll(allLogs[k]!.substanceLog);
               combinedExercise.addAll(allLogs[k]!.exerciseLog);
                combinedMedications.addAll(allLogs[k]!.medicationLog);
               break;
            }
         }
      }

      // --- ANALYZE HABITS ---

      // Helper to find latest event before bedtime
      DateTime? findLatestTime(List<DateTime> times) {
        DateTime? latest;
        for (var t in times) {
          if (t.isBefore(bedTime)) {
            // Filter: Only look at habits within 16 hours of bed time
            if (bedTime.difference(t).inHours < 16) { 
               if (latest == null || t.isAfter(latest)) {
                 latest = t;
               }
            }
          }
        }
        return latest;
      }

      // 1. Caffeine (Check for new 'caffeine' ID and legacy IDs)
      List<DateTime> caffeineTimes = combinedSubstances
          .where((s) => s.substanceTypeId == 'caffeine' || ['coffee', 'tea', 'cola', 'energy_drink'].contains(s.substanceTypeId))
          .map((s) => s.time)
          .toList();
      
      DateTime? lastCaffeine = findLatestTime(caffeineTimes);
      if (lastCaffeine != null) {
        points.add(ScatterPoint(_timeToDouble(lastCaffeine), latency, HabitType.caffeine));
      }

      // 2. Alcohol (Check for 'alcohol' ID and legacy IDs)
      List<DateTime> alcoholTimes = combinedSubstances
          .where((s) => s.substanceTypeId == 'alcohol' || ['wine', 'beer'].contains(s.substanceTypeId))
          .map((s) => s.time)
          .toList();

      DateTime? lastAlcohol = findLatestTime(alcoholTimes);
      if (lastAlcohol != null) {
        points.add(ScatterPoint(_timeToDouble(lastAlcohol), latency, HabitType.alcohol));
      }

      // 3. Exercise
      List<DateTime> exerciseTimes = combinedExercise.map((e) => e.finishTime).toList();
      DateTime? lastExercise = findLatestTime(exerciseTimes);
      if (lastExercise != null) {
         points.add(ScatterPoint(_timeToDouble(lastExercise), latency, HabitType.exercise));
      }
    

      //4. Medication
      List<DateTime> medicationTimes = combinedMedications.map((m) => m.time).toList();
      DateTime? lastMedication = findLatestTime(medicationTimes);
      if (lastMedication != null) {
         points.add(ScatterPoint(_timeToDouble(lastMedication), latency, HabitType.medication));
      } 
    }

    if (mounted) {
      setState(() {
        _points = points;
        _isLoading = false;
      });
    }
  }

  double _timeToDouble(DateTime t) {
    return t.hour + t.minute / 60.0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Habits vs. Sleep Latency")),
      body: SafeArea( // Wrapped in SafeArea
        child: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Impact of Habits on Falling Asleep",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  "Higher dots = Longer time to fall asleep.",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(13) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withAlpha(51)),
                    ),
                    child: _points.isEmpty 
                      ? const Center(child: Text("Not enough habit data logged yet."))
                      : CustomPaint(
                          painter: ScatterPlotPainter(_points, isDark),
                        ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendItem(color: Colors.brown, label: "Caffeine", icon: Icons.coffee),
                    const SizedBox(width: 12),
                    _LegendItem(color: Colors.purple, label: "Alcohol", icon: Icons.local_bar),
                    const SizedBox(width: 12),
                    _LegendItem(color: Colors.orange, label: "Exercise", icon: Icons.fitness_center),
                    const SizedBox(width: 12),
                    _LegendItem(color: Colors.blue, label: "Medication", icon: Icons.medication),
                  ],
                ),
                const SizedBox(height: 8),
                const Center(
                   child: Text(
                     "X-Axis: Time of Habit  •  Y-Axis: Minutes to Fall Asleep",
                     style: TextStyle(fontSize: 10, color: Colors.grey),
                   )
                ),
                const SizedBox(height: 50),
              ],
            ),
          )
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final IconData icon;
  const _LegendItem({required this.color, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class ScatterPlotPainter extends CustomPainter {
  final List<ScatterPoint> points;
  final bool isDark;

  ScatterPlotPainter(this.points, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paddingLeft = 30.0;
    final paddingBottom = 20.0;
    final graphW = size.width - paddingLeft;
    final graphH = size.height - paddingBottom;

    final paintGrid = Paint()
      ..color = Colors.grey.withAlpha(51)
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    // 1. Draw Axis & Labels
    // Y-Axis: Latency (0 to ~120 mins)
    for (int i = 0; i <= 4; i++) {
      double y = graphH - (i * (graphH / 4));
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width, y), paintGrid);
      
      textPainter.text = TextSpan(
        text: "${i * 30}m",
        style: TextStyle(color: Colors.grey, fontSize: 10),
      );
      textPainter.layout();
      canvas.drawText(textPainter, Offset(0, y - textPainter.height / 2));
    }

    // X-Axis: Time (06:00 to 24:00 typically)
    double minHour = 6;
    double maxHour = 24;
    
    for (int i = 6; i <= 24; i+=3) {
      double x = paddingLeft + ((i - minHour) / (maxHour - minHour)) * graphW;
      
      if (i <= 24) { 
        canvas.drawLine(Offset(x, 0), Offset(x, graphH), paintGrid);
        
        textPainter.text = TextSpan(
          text: "${i.toString().padLeft(2,'0')}:00",
          style: TextStyle(color: Colors.grey, fontSize: 10),
        );
        textPainter.layout();
        canvas.drawText(textPainter, Offset(x - textPainter.width/2, graphH + 5));
      }
    }

    // 2. Draw Points
    final paintCaffeine = Paint()..color = Colors.brown..style = PaintingStyle.fill;
    final paintAlcohol = Paint()..color = Colors.purple..style = PaintingStyle.fill;
    final paintExercise = Paint()..color = Colors.orange..style = PaintingStyle.fill;
    final paintMedication = Paint()..color = Colors.blue..style = PaintingStyle.fill;

    for (var p in points) {
      // Scale X (Time)
      double t = p.time;
      if (t < 6) t += 24; // Map late night hours (0-6am) to end of axis (24-30)

      // Normalize X to grid
      double x = paddingLeft + ((t - minHour) / (maxHour - minHour)) * graphW;
      
      // Scale Y (Latency)
      double l = p.latency > 120 ? 120 : p.latency;
      double y = graphH - (l / 120.0) * graphH;

      // Only draw if within bounds (ignore events way before 6am if any)
      if (x >= paddingLeft && x <= size.width + 10) { 
        Paint targetPaint;
        switch (p.type) {
          case HabitType.caffeine: targetPaint = paintCaffeine; break;
          case HabitType.alcohol: targetPaint = paintAlcohol; break;
          case HabitType.exercise: targetPaint = paintExercise; break;
          case HabitType.medication: targetPaint = paintMedication; break;
        }

        canvas.drawCircle(Offset(x, y), 5, targetPaint);
        canvas.drawCircle(Offset(x, y), 5, Paint()..color = isDark ? Colors.white70 : Colors.black26 ..style = PaintingStyle.stroke ..strokeWidth = 1);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

extension CanvasText on Canvas {
  void drawText(TextPainter tp, Offset offset) {
    tp.paint(this, offset);
  }
}