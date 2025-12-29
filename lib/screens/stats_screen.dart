import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../log_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final LogService _logService = LogService();
  
  // Data: Date -> Hours of ACTUAL sleep (split correctly across days)
  Map<DateTime, double> _weeklySleepData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _processSleepData();
  }

  String _formatHoursToHHhMM(double hours) {
    if (hours < 0) hours = 0;
    int h = hours.floor();
    int m = ((hours - h) * 60).round();
    return '${h.toString().padLeft(2, '0')}h${m.toString().padLeft(2, '0')}';
  }

  Future<void> _processSleepData() async {
    setState(() => _isLoading = true);
    
    // We want to show the last 7 days
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rangeStart = today.subtract(const Duration(days: 6));
    
    // We need to load logs starting from one day BEFORE the range,
    // because a sleep session starting yesterday might spill into today (the range start).
    final loadStart = rangeStart.subtract(const Duration(days: 1));
    
    // Helper map to aggregate hours per calendar date
    Map<DateTime, double> sleepBuckets = {};

    // Initialize buckets for the display range (0.0 hours default)
    for (int i = 0; i < 7; i++) {
      final d = rangeStart.add(Duration(days: i));
      sleepBuckets[d] = 0.0;
    }

    // Load logs for the extended range (8 days total)
    for (int i = 0; i < 8; i++) {
      final date = loadStart.add(Duration(days: i));
      final log = await _logService.getDailyLog(date);

      for (var entry in log.sleepLog) {
        DateTime start = entry.fellAsleepTime;
        DateTime end = entry.wakeTime;
        
        // Safety check
        if (end.isBefore(start)) continue;

        // Calculate total raw duration in minutes
        int totalMinutes = end.difference(start).inMinutes;
        if (totalMinutes == 0) continue;

        // Check if sleep spans across midnight (dates are different)
        DateTime startDate = DateTime(start.year, start.month, start.day);
        DateTime endDate = DateTime(end.year, end.month, end.day);

        if (startDate.isAtSameMomentAs(endDate)) {
          // SIMPLE CASE: Same day
          // Total sleep = Duration - AwakeTime
          double hours = (totalMinutes - entry.awakeDurationMinutes) / 60.0;
          if (hours < 0) hours = 0;
          
          if (sleepBuckets.containsKey(startDate)) {
            sleepBuckets[startDate] = (sleepBuckets[startDate] ?? 0) + hours;
          }
        } else {
          // COMPLEX CASE: Spans midnight (e.g. Sat 22:00 to Sun 11:30)
          
          // 1. Calculate duration on Day 1 (Start -> Midnight)
          // Midnight of the next day is endDate's 00:00 if strictly next day, 
          // but let's be precise: Midnight relative to start.
          DateTime midnight = DateTime(startDate.year, startDate.month, startDate.day).add(const Duration(days: 1));
          
          int minsDay1 = midnight.difference(start).inMinutes;
          // 2. Calculate duration on Day 2 (Midnight -> End)
          // Note: If spans multiple days (rare), this simple split puts rest in day 2.
          int minsDay2 = end.difference(midnight).inMinutes;
          
          // 3. Proportional Awake Time Subtraction
          // If I was awake 30 mins total, subtract proportionally from Day 1 and Day 2 based on length
          double ratioDay1 = minsDay1 / totalMinutes;
          double ratioDay2 = minsDay2 / totalMinutes;
          
          double awakeDay1 = entry.awakeDurationMinutes * ratioDay1;
          double awakeDay2 = entry.awakeDurationMinutes * ratioDay2;
          
          double hoursDay1 = (minsDay1 - awakeDay1) / 60.0;
          double hoursDay2 = (minsDay2 - awakeDay2) / 60.0;
          
          if (hoursDay1 < 0) hoursDay1 = 0;
          if (hoursDay2 < 0) hoursDay2 = 0;

          // Add to buckets
          if (sleepBuckets.containsKey(startDate)) {
            sleepBuckets[startDate] = (sleepBuckets[startDate] ?? 0) + hoursDay1;
          }
          // endDate typically matches next day, but using midnight date ensures continuity
          DateTime nextDayDate = DateTime(midnight.year, midnight.month, midnight.day);
          if (sleepBuckets.containsKey(nextDayDate)) {
            sleepBuckets[nextDayDate] = (sleepBuckets[nextDayDate] ?? 0) + hoursDay2;
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        // Sort keys to ensure display order
        _weeklySleepData = Map.fromEntries(
          sleepBuckets.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = Colors.indigoAccent;
    final bgBarColor = isDark ? Colors.white10 : Colors.grey[200];

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
                    'Sleep Duration (Past 7 Days)',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Split across midnight (e.g. 23:00-01:00 counts as 1h today, 1h tomorrow)",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 14, // Cap Y axis visually
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 2,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: isDark ? Colors.white10 : Colors.grey[300],
                            strokeWidth: 1,
                          ),
                        ),
                        // Moved barTouchData here (correct location)
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => Colors.blueGrey,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                _formatHoursToHHhMM(rod.toY),
                                const TextStyle(color: Colors.white),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                                      DateFormat('E').format(date),
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : Colors.grey[600],
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
                              interval: 2,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                return Text(
                                  '${value.toInt()}h',
                                  style: TextStyle(
                                    color: isDark ? Colors.white38 : Colors.grey,
                                    fontSize: 10,
                                  ),
                                );
                              },
                              reservedSize: 28,
                            ),
                          ),
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
                                color: barColor,
                                width: 16,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(4),
                                ),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: 14, // Background height
                                  color: bgBarColor,
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
                    'Hours of actual sleep per day',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
    );
  }
}